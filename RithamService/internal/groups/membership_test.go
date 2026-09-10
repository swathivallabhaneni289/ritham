package groups

import (
	"context"
	"errors"
	"testing"

	"github.com/google/uuid"
)

// spyCompletionVisibility records every HideGroupCompletions call, letting membership_test.go
// assert on the seam directly (per this plan's own instruction: "the keep and remove tests assert
// against that seam") rather than against a real completions table, which does not exist until
// plan 04.1-10 lands.
type spyCompletionVisibility struct {
	calls []hideCall
}

type hideCall struct {
	groupID uuid.UUID
	userID  uuid.UUID
}

func (s *spyCompletionVisibility) HideGroupCompletions(ctx context.Context, tx dbtx, groupID, userID uuid.UUID) error {
	s.calls = append(s.calls, hideCall{groupID: groupID, userID: userID})
	return nil
}

func TestGroups_AnyMemberCanLeaveAndGroupSurvives(t *testing.T) {
	h := newTestHarness(t)
	organizer := createUser(t, h.store, "Organizer")
	member := createUser(t, h.store, "Member")

	g, err := h.svc.Create(context.Background(), organizer, "Saturday Crew", PolicyAnyMember)
	if err != nil {
		t.Fatalf("Create: unexpected error: %v", err)
	}
	inviteAndJoin(t, h, g.ID, organizer, member)

	if err := h.svc.Leave(context.Background(), member, g.ID, DispositionKeepPosts); err != nil {
		t.Fatalf("Leave: unexpected error: %v", err)
	}

	if _, err := h.svc.Get(context.Background(), member, g.ID); !errors.Is(err, ErrNotAMember) {
		t.Errorf("Get after leaving: got error %v, want ErrNotAMember", err)
	}
	if _, err := h.svc.Get(context.Background(), organizer, g.ID); err != nil {
		t.Errorf("Get(organizer) after member left: unexpected error: %v -- group must still exist", err)
	}
}

func TestGroups_OrganizerLeavingRemovesOnlyTheirMembershipAndPromotesNobody(t *testing.T) {
	h := newTestHarness(t)
	organizer := createUser(t, h.store, "Organizer")
	memberA := createUser(t, h.store, "MemberA")
	memberB := createUser(t, h.store, "MemberB")

	g, err := h.svc.Create(context.Background(), organizer, "Saturday Crew", PolicyAnyMember)
	if err != nil {
		t.Fatalf("Create: unexpected error: %v", err)
	}
	inviteAndJoin(t, h, g.ID, organizer, memberA)
	inviteAndJoin(t, h, g.ID, organizer, memberB)

	if err := h.svc.Leave(context.Background(), organizer, g.ID, DispositionKeepPosts); err != nil {
		t.Fatalf("Leave (organizer): unexpected error: %v", err)
	}

	// The group continues; every remaining member keeps access.
	detail, err := h.svc.Get(context.Background(), memberA, g.ID)
	if err != nil {
		t.Fatalf("Get(memberA) after organizer left: unexpected error: %v", err)
	}
	if _, err := h.svc.Get(context.Background(), memberB, g.ID); err != nil {
		t.Fatalf("Get(memberB) after organizer left: unexpected error: %v", err)
	}

	// The organizer_user_id column is untouched: nobody is elevated into the role, and the field
	// still names the person who left, exactly per docs/group-events.md §1's "nothing to
	// transfer" design.
	if detail.OrganizerUserID != organizer {
		t.Errorf("GroupDetail.OrganizerUserID after organizer left = %s, want unchanged %s (no succession)", detail.OrganizerUserID, organizer)
	}

	var count int
	err = h.store.Pool().QueryRow(context.Background(),
		"SELECT COUNT(*) FROM group_members WHERE group_id = $1", g.ID).Scan(&count)
	if err != nil {
		t.Fatalf("counting group_members rows: %v", err)
	}
	if count != 2 {
		t.Errorf("group_members count after organizer left = %d, want 2 (memberA and memberB)", count)
	}
}

func TestGroups_LeavingWithKeepDispositionDoesNotHideCompletions(t *testing.T) {
	h := newTestHarness(t)
	spy := &spyCompletionVisibility{}
	h.svc.SetCompletionVisibility(spy)

	organizer := createUser(t, h.store, "Organizer")
	member := createUser(t, h.store, "Member")

	g, err := h.svc.Create(context.Background(), organizer, "Saturday Crew", PolicyAnyMember)
	if err != nil {
		t.Fatalf("Create: unexpected error: %v", err)
	}
	inviteAndJoin(t, h, g.ID, organizer, member)

	if err := h.svc.Leave(context.Background(), member, g.ID, DispositionKeepPosts); err != nil {
		t.Fatalf("Leave: unexpected error: %v", err)
	}

	if len(spy.calls) != 0 {
		t.Errorf("HideGroupCompletions calls after a keep-disposition leave = %d, want 0", len(spy.calls))
	}
}

func TestGroups_LeavingWithRemoveDispositionHidesCompletions(t *testing.T) {
	h := newTestHarness(t)
	spy := &spyCompletionVisibility{}
	h.svc.SetCompletionVisibility(spy)

	organizer := createUser(t, h.store, "Organizer")
	member := createUser(t, h.store, "Member")

	g, err := h.svc.Create(context.Background(), organizer, "Saturday Crew", PolicyAnyMember)
	if err != nil {
		t.Fatalf("Create: unexpected error: %v", err)
	}
	inviteAndJoin(t, h, g.ID, organizer, member)

	if err := h.svc.Leave(context.Background(), member, g.ID, DispositionRemovePosts); err != nil {
		t.Fatalf("Leave: unexpected error: %v", err)
	}

	if len(spy.calls) != 1 {
		t.Fatalf("HideGroupCompletions calls after a remove-disposition leave = %d, want exactly 1", len(spy.calls))
	}
	if spy.calls[0].groupID != g.ID || spy.calls[0].userID != member {
		t.Errorf("HideGroupCompletions called with (%s, %s), want (%s, %s)", spy.calls[0].groupID, spy.calls[0].userID, g.ID, member)
	}
}

func TestGroups_DispositionsAreDistinguishableAfterLeaving(t *testing.T) {
	// Two separate groups/spies so each leave's disposition is independently observable.
	h1 := newTestHarness(t)
	spy1 := &spyCompletionVisibility{}
	h1.svc.SetCompletionVisibility(spy1)
	organizer1 := createUser(t, h1.store, "Organizer")
	member1 := createUser(t, h1.store, "Member")
	g1, err := h1.svc.Create(context.Background(), organizer1, "Keep Group", PolicyAnyMember)
	if err != nil {
		t.Fatalf("Create(keep group): unexpected error: %v", err)
	}
	inviteAndJoin(t, h1, g1.ID, organizer1, member1)
	if err := h1.svc.Leave(context.Background(), member1, g1.ID, DispositionKeepPosts); err != nil {
		t.Fatalf("Leave(keep): unexpected error: %v", err)
	}

	h2 := newTestHarness(t)
	spy2 := &spyCompletionVisibility{}
	h2.svc.SetCompletionVisibility(spy2)
	organizer2 := createUser(t, h2.store, "Organizer")
	member2 := createUser(t, h2.store, "Member")
	g2, err := h2.svc.Create(context.Background(), organizer2, "Remove Group", PolicyAnyMember)
	if err != nil {
		t.Fatalf("Create(remove group): unexpected error: %v", err)
	}
	inviteAndJoin(t, h2, g2.ID, organizer2, member2)
	if err := h2.svc.Leave(context.Background(), member2, g2.ID, DispositionRemovePosts); err != nil {
		t.Fatalf("Leave(remove): unexpected error: %v", err)
	}

	if len(spy1.calls) == len(spy2.calls) {
		t.Fatalf("keep-disposition calls (%d) and remove-disposition calls (%d) must be distinguishable", len(spy1.calls), len(spy2.calls))
	}
	if len(spy1.calls) != 0 || len(spy2.calls) != 1 {
		t.Errorf("got keep=%d/remove=%d HideGroupCompletions calls, want keep=0/remove=1", len(spy1.calls), len(spy2.calls))
	}
}

func TestGroups_LastMemberLeavingIsPermitted(t *testing.T) {
	h := newTestHarness(t)
	organizer := createUser(t, h.store, "Organizer")

	g, err := h.svc.Create(context.Background(), organizer, "Solo-Bound Crew", PolicyAnyMember)
	if err != nil {
		t.Fatalf("Create: unexpected error: %v", err)
	}

	if err := h.svc.Leave(context.Background(), organizer, g.ID, DispositionKeepPosts); err != nil {
		t.Fatalf("Leave (last member): unexpected error: %v -- last-member leave must be permitted, no transfer demanded", err)
	}

	var count int
	err = h.store.Pool().QueryRow(context.Background(),
		"SELECT COUNT(*) FROM group_members WHERE group_id = $1", g.ID).Scan(&count)
	if err != nil {
		t.Fatalf("counting group_members rows: %v", err)
	}
	if count != 0 {
		t.Errorf("group_members count after the last member left = %d, want 0", count)
	}

	var groupExists bool
	err = h.store.Pool().QueryRow(context.Background(),
		"SELECT EXISTS(SELECT 1 FROM groups WHERE id = $1)", g.ID).Scan(&groupExists)
	if err != nil {
		t.Fatalf("checking groups row: %v", err)
	}
	if !groupExists {
		t.Errorf("groups row after the last member left = missing, want the group row to still exist")
	}
}

func TestGroups_AnyMemberPolicyLetsAnyMemberRemoveAnyOther(t *testing.T) {
	h := newTestHarness(t)
	organizer := createUser(t, h.store, "Organizer")
	memberA := createUser(t, h.store, "MemberA")
	memberB := createUser(t, h.store, "MemberB")

	g, err := h.svc.Create(context.Background(), organizer, "Saturday Crew", PolicyAnyMember)
	if err != nil {
		t.Fatalf("Create: unexpected error: %v", err)
	}
	inviteAndJoin(t, h, g.ID, organizer, memberA)
	inviteAndJoin(t, h, g.ID, organizer, memberB)

	if err := h.svc.RemoveMember(context.Background(), memberA, g.ID, memberB); err != nil {
		t.Fatalf("RemoveMember(memberA removes memberB, any-member policy): unexpected error: %v", err)
	}

	if _, err := h.svc.Get(context.Background(), memberB, g.ID); !errors.Is(err, ErrNotAMember) {
		t.Errorf("Get(memberB) after removal: got error %v, want ErrNotAMember", err)
	}
}

func TestGroups_OrganizerOnlyPolicyRejectsNonOrganizerRemoval(t *testing.T) {
	h := newTestHarness(t)
	organizer := createUser(t, h.store, "Organizer")
	memberA := createUser(t, h.store, "MemberA")
	memberB := createUser(t, h.store, "MemberB")

	g, err := h.svc.Create(context.Background(), organizer, "Saturday Crew", PolicyOrganizerOnly)
	if err != nil {
		t.Fatalf("Create: unexpected error: %v", err)
	}
	inviteAndJoin(t, h, g.ID, organizer, memberA)
	inviteAndJoin(t, h, g.ID, organizer, memberB)

	err = h.svc.RemoveMember(context.Background(), memberA, g.ID, memberB)
	if !errors.Is(err, ErrRemovalNotPermitted) {
		t.Fatalf("RemoveMember(non-organizer, organizer-only policy): got error %v, want ErrRemovalNotPermitted", err)
	}

	if err := h.svc.RemoveMember(context.Background(), organizer, g.ID, memberB); err != nil {
		t.Fatalf("RemoveMember(organizer, organizer-only policy): unexpected error: %v", err)
	}
}

func TestGroups_CannotRemoveSelfThroughRemovalRoute(t *testing.T) {
	h := newTestHarness(t)
	organizer := createUser(t, h.store, "Organizer")
	member := createUser(t, h.store, "Member")

	g, err := h.svc.Create(context.Background(), organizer, "Saturday Crew", PolicyAnyMember)
	if err != nil {
		t.Fatalf("Create: unexpected error: %v", err)
	}
	inviteAndJoin(t, h, g.ID, organizer, member)

	err = h.svc.RemoveMember(context.Background(), member, g.ID, member)
	if !errors.Is(err, ErrRemoveSelf) {
		t.Fatalf("RemoveMember(self): got error %v, want ErrRemoveSelf", err)
	}
}

func TestGroups_OnlyAMemberCanChangeRemovalPolicy(t *testing.T) {
	h := newTestHarness(t)
	organizer := createUser(t, h.store, "Organizer")
	stranger := createUser(t, h.store, "Stranger")

	g, err := h.svc.Create(context.Background(), organizer, "Saturday Crew", PolicyAnyMember)
	if err != nil {
		t.Fatalf("Create: unexpected error: %v", err)
	}

	err = h.svc.SetRemovalPolicy(context.Background(), stranger, g.ID, PolicyOrganizerOnly)
	if !errors.Is(err, ErrNotAMember) {
		t.Fatalf("SetRemovalPolicy(non-member): got error %v, want ErrNotAMember", err)
	}

	if err := h.svc.SetRemovalPolicy(context.Background(), organizer, g.ID, PolicyOrganizerOnly); err != nil {
		t.Fatalf("SetRemovalPolicy(member): unexpected error: %v", err)
	}
}

func TestGroups_RequireMemberGate(t *testing.T) {
	h := newTestHarness(t)
	organizer := createUser(t, h.store, "Organizer")
	stranger := createUser(t, h.store, "Stranger")

	g, err := h.svc.Create(context.Background(), organizer, "Saturday Crew", PolicyAnyMember)
	if err != nil {
		t.Fatalf("Create: unexpected error: %v", err)
	}

	if err := h.svc.RequireMember(context.Background(), organizer, g.ID); err != nil {
		t.Errorf("RequireMember(member): unexpected error: %v", err)
	}

	if err := h.svc.RequireMember(context.Background(), stranger, g.ID); !errors.Is(err, ErrNotAMember) {
		t.Errorf("RequireMember(non-member of a real group): got error %v, want ErrNotAMember", err)
	}

	if err := h.svc.RequireMember(context.Background(), stranger, uuid.New()); !errors.Is(err, ErrNotAMember) {
		t.Errorf("RequireMember(nonexistent group): got error %v, want ErrNotAMember", err)
	}
}
