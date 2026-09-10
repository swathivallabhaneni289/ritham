package events

import (
	"context"
	"errors"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/swathivallabhaneni289/ritham/RithamService/internal/groups"
	"github.com/swathivallabhaneni289/ritham/RithamService/internal/store"
)

// stubFriendPredicate is a symmetric, in-memory groups.FriendPredicate double, duplicated here
// (rather than imported from internal/groups' own test file, which is package-private) so this
// package's tests can wire a real *groups.Service as the membership gate -- the plan's own
// instruction is that the gate is "plan 04.1-08's exported predicate, passed in through an
// interface, never a restated membership query", so these tests exercise the real thing rather
// than a stand-in that could silently diverge from it.
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

// testHarness wires a real *groups.Service (backed by the same live database, per the
// connected-test skip convention internal/groups/groups_test.go established) as this package's
// Service's MembershipGate, plus a controllable clock shared by both.
type testHarness struct {
	svc      *Service
	groupsvc *groups.Service
	friends  *stubFriendPredicate
	store    *store.Store
	clock    time.Time
}

func (h *testHarness) now() time.Time { return h.clock }

func newTestHarness(t *testing.T) *testHarness {
	t.Helper()
	databaseURL := store.DatabaseURLFromEnv()
	if databaseURL == "" {
		t.Skip("RITHAM_DATABASE_URL is unset -- start a database (see " +
			"docker-compose.dev.yml, or a native Postgres per 04.1-01-SUMMARY.md) and run this " +
			"test with `RITHAM_DATABASE_URL=postgres://$(whoami)@localhost:5432/ritham_dev" +
			"?sslmode=disable go test ./internal/events/...`")
	}

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
	h.groupsvc = groups.New(st, h.friends, h.now)
	h.svc = New(st, h.groupsvc, h.now)
	return h
}

// createUser inserts a users row and cleans it up (cascading to every events-package row that
// references it) when the test ends.
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

// createGroup creates a group with organizer as its sole member.
func createGroup(t *testing.T, h *testHarness, organizer uuid.UUID) uuid.UUID {
	t.Helper()
	g, err := h.groupsvc.Create(context.Background(), organizer, "Test Group", groups.PolicyAnyMember)
	if err != nil {
		t.Fatalf("groups.Create: unexpected error: %v", err)
	}
	return g.ID
}

// addMember friends organizer and member, invites, and joins on member's behalf.
func addMember(t *testing.T, h *testHarness, groupID, organizer, member uuid.UUID) {
	t.Helper()
	h.friends.makeFriends(organizer, member)
	if _, err := h.groupsvc.Invite(context.Background(), organizer, groupID, member); err != nil {
		t.Fatalf("Invite: unexpected error: %v", err)
	}
	if err := h.groupsvc.Join(context.Background(), member, groupID); err != nil {
		t.Fatalf("Join: unexpected error: %v", err)
	}
}

// createEvent creates a valid event in groupID, organized by organizer.
func createEvent(t *testing.T, h *testHarness, groupID, organizer uuid.UUID) uuid.UUID {
	t.Helper()
	e, err := h.svc.Create(context.Background(), organizer, groupID, validEvent())
	if err != nil {
		t.Fatalf("Create: unexpected error: %v", err)
	}
	return e.ID
}

func validEvent() NewGoalEvent {
	day := time.Date(2026, 9, 12, 0, 0, 0, 0, time.UTC)
	return NewGoalEvent{
		Name:         "Saturday 5K Walk",
		ActivityType: "walk",
		TargetKind:   TargetKindNone,
		TargetValue:  nil,
		StartsOn:     day,
		EndsOn:       day,
	}
}

func TestGoalEvent_CreatingRequiresGroupMembership(t *testing.T) {
	h := newTestHarness(t)
	stranger := createUser(t, h.store, "Stranger")
	organizer := createUser(t, h.store, "Organizer")
	groupID := createGroup(t, h, organizer)

	if _, err := h.svc.Create(context.Background(), stranger, groupID, validEvent()); !errors.Is(err, groups.ErrNotAMember) {
		t.Fatalf("Create(non-member): got error %v, want groups.ErrNotAMember", err)
	}

	list, err := h.svc.List(context.Background(), organizer, groupID)
	if err != nil {
		t.Fatalf("List: unexpected error: %v", err)
	}
	if len(list) != 0 {
		t.Errorf("events after a rejected non-member Create = %d, want 0 (nothing created)", len(list))
	}
}

func TestGoalEvent_AcceptsKnownActivityTypeRejectsUnknown(t *testing.T) {
	h := newTestHarness(t)
	organizer := createUser(t, h.store, "Organizer")
	groupID := createGroup(t, h, organizer)

	in := validEvent()
	in.ActivityType = "run"
	if _, err := h.svc.Create(context.Background(), organizer, groupID, in); err != nil {
		t.Fatalf("Create(known activity type): unexpected error: %v", err)
	}

	in2 := validEvent()
	in2.ActivityType = "skydive"
	if _, err := h.svc.Create(context.Background(), organizer, groupID, in2); !errors.Is(err, ErrUnknownActivityType) {
		t.Fatalf("Create(unknown activity type): got error %v, want ErrUnknownActivityType", err)
	}
}

func TestGoalEvent_TargetIsGenuinelyOptionalAndRoundTrips(t *testing.T) {
	h := newTestHarness(t)
	organizer := createUser(t, h.store, "Organizer")
	groupID := createGroup(t, h, organizer)

	created, err := h.svc.Create(context.Background(), organizer, groupID, validEvent())
	if err != nil {
		t.Fatalf("Create(no target): unexpected error: %v", err)
	}
	if created.TargetKind != TargetKindNone || created.TargetValue != nil {
		t.Errorf("created event target = (%s, %v), want (none, nil)", created.TargetKind, created.TargetValue)
	}

	fetched, err := h.svc.Get(context.Background(), organizer, created.ID)
	if err != nil {
		t.Fatalf("Get: unexpected error: %v", err)
	}
	if fetched.TargetKind != TargetKindNone || fetched.TargetValue != nil {
		t.Errorf("fetched event target = (%s, %v), want (none, nil) -- must round-trip", fetched.TargetKind, fetched.TargetValue)
	}
}

func TestGoalEvent_TargetWithValueRoundTrips(t *testing.T) {
	h := newTestHarness(t)
	organizer := createUser(t, h.store, "Organizer")
	groupID := createGroup(t, h, organizer)

	distance := 5000.0
	in := validEvent()
	in.TargetKind = TargetKindDistance
	in.TargetValue = &distance

	created, err := h.svc.Create(context.Background(), organizer, groupID, in)
	if err != nil {
		t.Fatalf("Create(distance target): unexpected error: %v", err)
	}
	if created.TargetKind != TargetKindDistance || created.TargetValue == nil || *created.TargetValue != distance {
		t.Errorf("created event target = (%s, %v), want (distance, %v)", created.TargetKind, created.TargetValue, distance)
	}

	fetched, err := h.svc.Get(context.Background(), organizer, created.ID)
	if err != nil {
		t.Fatalf("Get: unexpected error: %v", err)
	}
	if fetched.TargetKind != TargetKindDistance || fetched.TargetValue == nil || *fetched.TargetValue != distance {
		t.Errorf("fetched event target = (%s, %v), want (distance, %v)", fetched.TargetKind, fetched.TargetValue, distance)
	}
}

func TestGoalEvent_WindowMayBeSingleDayOrSpan(t *testing.T) {
	h := newTestHarness(t)
	organizer := createUser(t, h.store, "Organizer")
	groupID := createGroup(t, h, organizer)

	single := validEvent()
	single.StartsOn = time.Date(2026, 9, 12, 0, 0, 0, 0, time.UTC)
	single.EndsOn = time.Date(2026, 9, 12, 0, 0, 0, 0, time.UTC)
	if _, err := h.svc.Create(context.Background(), organizer, groupID, single); err != nil {
		t.Fatalf("Create(single-day window, ends == starts): unexpected error: %v", err)
	}

	span := validEvent()
	span.StartsOn = time.Date(2026, 9, 12, 0, 0, 0, 0, time.UTC)
	span.EndsOn = time.Date(2026, 9, 14, 0, 0, 0, 0, time.UTC)
	if _, err := h.svc.Create(context.Background(), organizer, groupID, span); err != nil {
		t.Fatalf("Create(span window): unexpected error: %v", err)
	}
}

func TestGoalEvent_ListingReturnsNothingToNonMember(t *testing.T) {
	h := newTestHarness(t)
	organizer := createUser(t, h.store, "Organizer")
	stranger := createUser(t, h.store, "Stranger")
	groupID := createGroup(t, h, organizer)

	if _, err := h.svc.Create(context.Background(), organizer, groupID, validEvent()); err != nil {
		t.Fatalf("Create: unexpected error: %v", err)
	}

	if _, err := h.svc.List(context.Background(), stranger, groupID); !errors.Is(err, groups.ErrNotAMember) {
		t.Fatalf("List(non-member): got error %v, want groups.ErrNotAMember", err)
	}
}

func TestGoalEvent_NameOverLengthBoundIsRejected(t *testing.T) {
	h := newTestHarness(t)
	organizer := createUser(t, h.store, "Organizer")
	groupID := createGroup(t, h, organizer)

	in := validEvent()
	in.Name = strings.Repeat("a", 81)
	if _, err := h.svc.Create(context.Background(), organizer, groupID, in); !errors.Is(err, ErrNameTooLong) {
		t.Fatalf("Create(over-length name): got error %v, want ErrNameTooLong", err)
	}
}
