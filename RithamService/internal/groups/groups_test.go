package groups

import (
	"context"
	"errors"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/swathivallabhaneni289/ritham/RithamService/internal/store"
)

// stubFriendPredicate is a symmetric, in-memory FriendPredicate double -- groups_test.go controls
// exactly who is and isn't friends without going through the full friends package, mirroring how
// this plan's own artifacts describe FriendPredicate as an injected interface for this purpose.
type stubFriendPredicate struct {
	pairs map[[2]uuid.UUID]bool
}

func newStubFriendPredicate() *stubFriendPredicate {
	return &stubFriendPredicate{pairs: map[[2]uuid.UUID]bool{}}
}

func (s *stubFriendPredicate) makeFriends(a, b uuid.UUID) {
	s.pairs[pairKey(a, b)] = true
}

func (s *stubFriendPredicate) AreFriends(ctx context.Context, a, b uuid.UUID) (bool, error) {
	return s.pairs[pairKey(a, b)], nil
}

// pairKey normalizes an unordered pair for the stub's map, independent of argument order.
func pairKey(a, b uuid.UUID) [2]uuid.UUID {
	for i := range a {
		if a[i] != b[i] {
			if a[i] < b[i] {
				return [2]uuid.UUID{a, b}
			}
			return [2]uuid.UUID{b, a}
		}
	}
	return [2]uuid.UUID{a, b}
}

// testHarness wires a Service against a real, live database (RITHAM_DATABASE_URL), a stub
// friend predicate, and a controllable clock -- following internal/friends/friends_test.go's
// testHarness convention: skip loudly, with an actionable message, when no database is
// configured, rather than silently passing nothing.
type testHarness struct {
	svc     *Service
	store   *store.Store
	friends *stubFriendPredicate
	clock   time.Time
}

func (h *testHarness) now() time.Time { return h.clock }

func newTestHarness(t *testing.T) *testHarness {
	t.Helper()
	databaseURL := store.DatabaseURLFromEnv()
	if databaseURL == "" {
		t.Skip("RITHAM_DATABASE_URL is unset -- start a database (see " +
			"docker-compose.dev.yml, or a native Postgres per 04.1-01-SUMMARY.md) and run this " +
			"test with `RITHAM_DATABASE_URL=postgres://$(whoami)@localhost:5432/ritham_dev" +
			"?sslmode=disable go test ./internal/groups/...`")
	}

	// Migrate is idempotent (migrate.ErrNoChange is treated as success) -- this ensures
	// 0004_groups' tables exist even against a dev database that has only ever run earlier
	// migrations.
	if err := store.Migrate(databaseURL); err != nil {
		t.Fatalf("store.Migrate: unexpected error: %v", err)
	}

	ctx := context.Background()
	st, err := store.New(ctx, databaseURL)
	if err != nil {
		t.Fatalf("store.New: unexpected error: %v", err)
	}
	t.Cleanup(st.Close)

	h := &testHarness{
		store:   st,
		friends: newStubFriendPredicate(),
		clock:   time.Date(2026, 9, 10, 12, 0, 0, 0, time.UTC),
	}
	h.svc = New(st, h.friends, h.now)
	return h
}

// createUser inserts a users row with a unique apple_subject and cleans it up (cascading to every
// groups-package row that references it) when the test ends.
func createUser(t *testing.T, st *store.Store, displayName string) uuid.UUID {
	t.Helper()
	id := uuid.New()
	_, err := st.Pool().Exec(context.Background(),
		"INSERT INTO users (id, apple_subject, display_name) VALUES ($1, $2, $3)",
		id, "subject."+id.String(), displayName)
	if err != nil {
		t.Fatalf("creating test user: %v", err)
	}
	t.Cleanup(func() {
		_, _ = st.Pool().Exec(context.Background(), "DELETE FROM users WHERE id = $1", id)
	})
	return id
}

// inviteAndJoin is a test-only convenience that friends organizer and invitee, sends the
// invitation, and joins on the invitee's behalf, failing the test immediately on any error.
func inviteAndJoin(t *testing.T, h *testHarness, groupID, organizerID, inviteeID uuid.UUID) {
	t.Helper()
	h.friends.makeFriends(organizerID, inviteeID)
	if _, err := h.svc.Invite(context.Background(), organizerID, groupID, inviteeID); err != nil {
		t.Fatalf("Invite: unexpected error: %v", err)
	}
	if err := h.svc.Join(context.Background(), inviteeID, groupID); err != nil {
		t.Fatalf("Join: unexpected error: %v", err)
	}
}

func TestGroups_CreatingMakesCreatorSoleMemberAndOrganizer(t *testing.T) {
	h := newTestHarness(t)
	organizer := createUser(t, h.store, "Organizer")

	g, err := h.svc.Create(context.Background(), organizer, "Saturday Crew", PolicyAnyMember)
	if err != nil {
		t.Fatalf("Create: unexpected error: %v", err)
	}
	if g.OrganizerUserID != organizer {
		t.Errorf("g.OrganizerUserID = %s, want %s", g.OrganizerUserID, organizer)
	}

	groups, err := h.svc.ListForUser(context.Background(), organizer)
	if err != nil {
		t.Fatalf("ListForUser: unexpected error: %v", err)
	}
	if len(groups) != 1 || groups[0].ID != g.ID {
		t.Fatalf("ListForUser(organizer) = %+v, want exactly the one created group", groups)
	}

	var count int
	err = h.store.Pool().QueryRow(context.Background(),
		"SELECT COUNT(*) FROM group_members WHERE group_id = $1", g.ID).Scan(&count)
	if err != nil {
		t.Fatalf("counting group_members rows: %v", err)
	}
	if count != 1 {
		t.Errorf("group_members count after Create = %d, want exactly 1 (the organizer)", count)
	}
}

func TestGroups_InvitingNonFriendFailsAndCreatesNoInvitationRow(t *testing.T) {
	h := newTestHarness(t)
	organizer := createUser(t, h.store, "Organizer")
	stranger := createUser(t, h.store, "Stranger")

	g, err := h.svc.Create(context.Background(), organizer, "Saturday Crew", PolicyAnyMember)
	if err != nil {
		t.Fatalf("Create: unexpected error: %v", err)
	}

	_, err = h.svc.Invite(context.Background(), organizer, g.ID, stranger)
	if !errors.Is(err, ErrNotFriends) {
		t.Fatalf("Invite(non-friend): got error %v, want ErrNotFriends", err)
	}

	var count int
	err = h.store.Pool().QueryRow(context.Background(),
		"SELECT COUNT(*) FROM group_invitations WHERE group_id = $1 AND invitee_user_id = $2",
		g.ID, stranger).Scan(&count)
	if err != nil {
		t.Fatalf("counting group_invitations rows: %v", err)
	}
	if count != 0 {
		t.Errorf("group_invitations count after a rejected non-friend invite = %d, want 0", count)
	}
}

func TestGroups_InvitingFriendCreatesPendingInvitationWithoutMembership(t *testing.T) {
	h := newTestHarness(t)
	organizer := createUser(t, h.store, "Organizer")
	friend := createUser(t, h.store, "Friend")
	h.friends.makeFriends(organizer, friend)

	g, err := h.svc.Create(context.Background(), organizer, "Saturday Crew", PolicyAnyMember)
	if err != nil {
		t.Fatalf("Create: unexpected error: %v", err)
	}

	if _, err := h.svc.Invite(context.Background(), organizer, g.ID, friend); err != nil {
		t.Fatalf("Invite: unexpected error: %v", err)
	}

	var state string
	err = h.store.Pool().QueryRow(context.Background(),
		"SELECT state FROM group_invitations WHERE group_id = $1 AND invitee_user_id = $2",
		g.ID, friend).Scan(&state)
	if err != nil {
		t.Fatalf("querying group_invitations row: %v", err)
	}
	if state != "pending" {
		t.Errorf("group_invitations.state = %q, want %q", state, "pending")
	}

	_, getErr := h.svc.Get(context.Background(), friend, g.ID)
	if !errors.Is(getErr, ErrNotAMember) {
		t.Errorf("Get by an invited-not-yet-joined user: got error %v, want ErrNotAMember", getErr)
	}
}

func TestGroups_JoiningWithoutPendingInvitationFails(t *testing.T) {
	h := newTestHarness(t)
	organizer := createUser(t, h.store, "Organizer")
	stranger := createUser(t, h.store, "Stranger")

	g, err := h.svc.Create(context.Background(), organizer, "Saturday Crew", PolicyAnyMember)
	if err != nil {
		t.Fatalf("Create: unexpected error: %v", err)
	}

	// stranger knows the real group id but was never invited.
	err = h.svc.Join(context.Background(), stranger, g.ID)
	if !errors.Is(err, ErrNoInvitation) {
		t.Fatalf("Join(no invitation): got error %v, want ErrNoInvitation", err)
	}
}

func TestGroups_JoiningAlreadyJoinedGroupFailsWithoutDuplicatingMembership(t *testing.T) {
	h := newTestHarness(t)
	organizer := createUser(t, h.store, "Organizer")
	friend := createUser(t, h.store, "Friend")

	g, err := h.svc.Create(context.Background(), organizer, "Saturday Crew", PolicyAnyMember)
	if err != nil {
		t.Fatalf("Create: unexpected error: %v", err)
	}
	inviteAndJoin(t, h, g.ID, organizer, friend)

	err = h.svc.Join(context.Background(), friend, g.ID)
	if !errors.Is(err, ErrAlreadyMember) {
		t.Fatalf("Join(already a member): got error %v, want ErrAlreadyMember", err)
	}

	var count int
	err = h.store.Pool().QueryRow(context.Background(),
		"SELECT COUNT(*) FROM group_members WHERE group_id = $1 AND user_id = $2",
		g.ID, friend).Scan(&count)
	if err != nil {
		t.Fatalf("counting group_members rows: %v", err)
	}
	if count != 1 {
		t.Errorf("group_members rows for the same (group, user) pair = %d, want exactly 1", count)
	}
}

func TestGroups_TwelfthMemberJoinsThirteenthIsRejected(t *testing.T) {
	h := newTestHarness(t)
	organizer := createUser(t, h.store, "Organizer")

	g, err := h.svc.Create(context.Background(), organizer, "Big Crew", PolicyAnyMember)
	if err != nil {
		t.Fatalf("Create: unexpected error: %v", err)
	}

	// The organizer already occupies one of the twelve seats, so eleven more joins reach the cap.
	for i := 0; i < maxMembers-1; i++ {
		member := createUser(t, h.store, "Member")
		inviteAndJoin(t, h, g.ID, organizer, member)
	}

	var count int
	err = h.store.Pool().QueryRow(context.Background(),
		"SELECT COUNT(*) FROM group_members WHERE group_id = $1", g.ID).Scan(&count)
	if err != nil {
		t.Fatalf("counting group_members rows: %v", err)
	}
	if count != maxMembers {
		t.Fatalf("group_members count after filling the group = %d, want %d", count, maxMembers)
	}

	thirteenth := createUser(t, h.store, "Thirteenth")
	h.friends.makeFriends(organizer, thirteenth)
	if _, err := h.svc.Invite(context.Background(), organizer, g.ID, thirteenth); err != nil {
		t.Fatalf("Invite (thirteenth): unexpected error: %v", err)
	}
	err = h.svc.Join(context.Background(), thirteenth, g.ID)
	if !errors.Is(err, ErrGroupFull) {
		t.Fatalf("Join (thirteenth): got error %v, want ErrGroupFull", err)
	}

	err = h.store.Pool().QueryRow(context.Background(),
		"SELECT COUNT(*) FROM group_members WHERE group_id = $1", g.ID).Scan(&count)
	if err != nil {
		t.Fatalf("counting group_members rows after the rejected join: %v", err)
	}
	if count != maxMembers {
		t.Errorf("group_members count after a rejected thirteenth join = %d, want exactly %d", count, maxMembers)
	}
}

func TestGroups_ListForUserReturnsOnlyGroupsTheCallerIsAMemberOf(t *testing.T) {
	h := newTestHarness(t)
	organizer := createUser(t, h.store, "Organizer")
	invitedOnly := createUser(t, h.store, "InvitedOnly")

	joined, err := h.svc.Create(context.Background(), organizer, "Joined Group", PolicyAnyMember)
	if err != nil {
		t.Fatalf("Create(joined): unexpected error: %v", err)
	}
	invitedOnlyGroup, err := h.svc.Create(context.Background(), organizer, "Invited-Only Group", PolicyAnyMember)
	if err != nil {
		t.Fatalf("Create(invitedOnlyGroup): unexpected error: %v", err)
	}
	leftGroup, err := h.svc.Create(context.Background(), organizer, "Left Group", PolicyAnyMember)
	if err != nil {
		t.Fatalf("Create(leftGroup): unexpected error: %v", err)
	}

	inviteAndJoin(t, h, joined.ID, organizer, invitedOnly)

	h.friends.makeFriends(organizer, invitedOnly)
	if _, err := h.svc.Invite(context.Background(), organizer, invitedOnlyGroup.ID, invitedOnly); err != nil {
		t.Fatalf("Invite(invitedOnlyGroup): unexpected error: %v", err)
	}

	inviteAndJoin(t, h, leftGroup.ID, organizer, invitedOnly)
	// invitedOnly leaves leftGroup directly via SQL (membership.go's Leave is exercised in its
	// own test file); this test only needs the resulting non-membership state.
	_, err = h.store.Pool().Exec(context.Background(),
		"DELETE FROM group_members WHERE group_id = $1 AND user_id = $2", leftGroup.ID, invitedOnly)
	if err != nil {
		t.Fatalf("removing invitedOnly from leftGroup: %v", err)
	}

	groups, err := h.svc.ListForUser(context.Background(), invitedOnly)
	if err != nil {
		t.Fatalf("ListForUser: unexpected error: %v", err)
	}
	if len(groups) != 1 || groups[0].ID != joined.ID {
		t.Fatalf("ListForUser(invitedOnly) = %+v, want exactly [%s] (joined only)", groups, joined.ID)
	}
}

func TestGroups_FetchingNonMemberGroupFailsIdenticallyWhetherOrNotItExists(t *testing.T) {
	h := newTestHarness(t)
	organizer := createUser(t, h.store, "Organizer")
	stranger := createUser(t, h.store, "Stranger")

	realGroup, err := h.svc.Create(context.Background(), organizer, "Saturday Crew", PolicyAnyMember)
	if err != nil {
		t.Fatalf("Create: unexpected error: %v", err)
	}

	_, realErr := h.svc.Get(context.Background(), stranger, realGroup.ID)
	if !errors.Is(realErr, ErrNotAMember) {
		t.Fatalf("Get(real group, non-member): got error %v, want ErrNotAMember", realErr)
	}

	_, fakeErr := h.svc.Get(context.Background(), stranger, uuid.New())
	if !errors.Is(fakeErr, ErrNotAMember) {
		t.Fatalf("Get(nonexistent group): got error %v, want ErrNotAMember", fakeErr)
	}

	if realErr.Error() != fakeErr.Error() {
		t.Errorf("a real group's non-member error (%v) and a nonexistent group's error (%v) must be byte-identical", realErr, fakeErr)
	}
}

func TestGroups_NameOverLengthBoundIsRejected(t *testing.T) {
	h := newTestHarness(t)
	organizer := createUser(t, h.store, "Organizer")

	tooLong := strings.Repeat("a", maxGroupNameLen+1)
	_, err := h.svc.Create(context.Background(), organizer, tooLong, PolicyAnyMember)
	if !errors.Is(err, ErrNameTooLong) {
		t.Fatalf("Create(over-length name): got error %v, want ErrNameTooLong", err)
	}

	var count int
	err = h.store.Pool().QueryRow(context.Background(),
		"SELECT COUNT(*) FROM groups WHERE organizer_user_id = $1", organizer).Scan(&count)
	if err != nil {
		t.Fatalf("counting groups rows: %v", err)
	}
	if count != 0 {
		t.Errorf("groups rows after a rejected over-length Create = %d, want 0", count)
	}
}
