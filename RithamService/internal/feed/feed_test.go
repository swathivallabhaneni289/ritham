package feed

import (
	"context"
	"errors"
	"fmt"
	"reflect"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/swathivallabhaneni289/ritham/RithamService/internal/events"
	"github.com/swathivallabhaneni289/ritham/RithamService/internal/groups"
	"github.com/swathivallabhaneni289/ritham/RithamService/internal/photo"
	"github.com/swathivallabhaneni289/ritham/RithamService/internal/store"
)

// stubPhotoChecker is a controllable events.PhotoOwnershipChecker double (duplicated from
// internal/events' own package-private test double) so this package's tests can log a completion
// carrying a photo without a running S3-compatible backend -- feed_test.go only needs
// events.LogCompletion to accept the reference, never the real photo pipeline.
type stubPhotoChecker struct {
	owned map[[2]uuid.UUID]bool
}

func newStubPhotoChecker() *stubPhotoChecker {
	return &stubPhotoChecker{owned: map[[2]uuid.UUID]bool{}}
}

func (s *stubPhotoChecker) grant(userID, assetID uuid.UUID) {
	s.owned[[2]uuid.UUID{userID, assetID}] = true
}

func (s *stubPhotoChecker) Asset(ctx context.Context, requesterUserID, assetID uuid.UUID) (photo.Asset, error) {
	if s.owned[[2]uuid.UUID{requesterUserID, assetID}] {
		return photo.Asset{ID: assetID, OwnerUserID: requesterUserID}, nil
	}
	return photo.Asset{}, photo.ErrAssetNotFound
}

// stubFriendPredicate is a symmetric, in-memory groups.FriendPredicate double, duplicated here
// (package-private in internal/groups) so this package's tests can wire a real *groups.Service,
// matching internal/events' own precedent (events_test.go's identically-named double).
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

// stubPhotoURLSource is a PhotoURLSource double that fabricates a deterministic, recognizable URL
// from key and ttl -- no S3-compatible backend needed to exercise every feed/cheer behavior below.
type stubPhotoURLSource struct{}

func (stubPhotoURLSource) SharedURL(ctx context.Context, key string, ttl time.Duration) (string, error) {
	return fmt.Sprintf("https://stub.example/%s?ttl=%s", key, ttl), nil
}

// testHarness wires a real *groups.Service and *events.Service (both backed by the same live
// database) plus this package's own Service, sharing one controllable clock across all three --
// matching internal/events' own testHarness precedent, extended one layer up.
type testHarness struct {
	svc      *Service
	eventsvc *events.Service
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
			"?sslmode=disable go test ./internal/feed/...`")
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
		clock:   time.Date(2026, 9, 12, 12, 0, 0, 0, time.UTC),
	}
	h.groupsvc = groups.New(st, h.friends, h.now)
	h.eventsvc = events.New(st, h.groupsvc, h.now)
	h.svc = New(st, stubPhotoURLSource{}, h.now)
	return h
}

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

func createGroup(t *testing.T, h *testHarness, organizer uuid.UUID) uuid.UUID {
	t.Helper()
	g, err := h.groupsvc.Create(context.Background(), organizer, "Test Group", groups.PolicyAnyMember)
	if err != nil {
		t.Fatalf("groups.Create: unexpected error: %v", err)
	}
	return g.ID
}

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

func createEvent(t *testing.T, h *testHarness, groupID, organizer uuid.UUID) uuid.UUID {
	t.Helper()
	e, err := h.eventsvc.Create(context.Background(), organizer, groupID, validEvent())
	if err != nil {
		t.Fatalf("events.Create: unexpected error: %v", err)
	}
	return e.ID
}

func createPhotoAsset(t *testing.T, st *store.Store, ownerUserID uuid.UUID) uuid.UUID {
	t.Helper()
	id := uuid.New()
	_, err := st.Pool().Exec(context.Background(),
		"INSERT INTO photo_assets (id, owner_user_id, shared_object_key, content_type) VALUES ($1, $2, $3, $4)",
		id, ownerUserID, id.String(), "image/jpeg")
	if err != nil {
		t.Fatalf("creating test photo asset: %v", err)
	}
	t.Cleanup(func() {
		_, _ = st.Pool().Exec(context.Background(), "DELETE FROM photo_assets WHERE id = $1", id)
	})
	return id
}

func validCompletionTime() time.Time {
	return time.Date(2026, 9, 12, 8, 0, 0, 0, time.UTC)
}

func validEvent() events.NewGoalEvent {
	day := time.Date(2026, 9, 12, 0, 0, 0, 0, time.UTC)
	return events.NewGoalEvent{
		Name:         "Saturday 5K Walk",
		ActivityType: "walk",
		TargetKind:   events.TargetKindNone,
		TargetValue:  nil,
		StartsOn:     day,
		EndsOn:       day,
	}
}

// logCompletion posts a completion as userID at h.clock, then advances h.clock by one second so
// the next call in the same test gets a strictly later PostedAt.
func logCompletion(t *testing.T, h *testHarness, userID, eventID uuid.UUID, in events.NewCompletion) events.Completion {
	t.Helper()
	if in.CompletedAt.IsZero() {
		in.CompletedAt = validCompletionTime()
	}
	c, err := h.eventsvc.LogCompletion(context.Background(), userID, eventID, in)
	if err != nil {
		t.Fatalf("LogCompletion(%s): unexpected error: %v", userID, err)
	}
	h.clock = h.clock.Add(time.Second)
	return c
}

// --- Task 1: Membership-scoped chronological feed with no aggregate in its response ---

// TestGroupFeed_MemberGetsItemsNonMemberGetsSentinel is the important non-member test: a
// non-member's GroupFeed call returns ErrNotAMember and no items, even though the group holds
// real completions.
func TestGroupFeed_MemberGetsItemsNonMemberGetsSentinel(t *testing.T) {
	h := newTestHarness(t)
	organizer := createUser(t, h.store, "Organizer")
	stranger := createUser(t, h.store, "Stranger")
	groupID := createGroup(t, h, organizer)
	eventID := createEvent(t, h, groupID, organizer)
	logCompletion(t, h, organizer, eventID, events.NewCompletion{})

	page, err := h.svc.GroupFeed(context.Background(), organizer, groupID, "", 0)
	if err != nil {
		t.Fatalf("GroupFeed(member): unexpected error: %v", err)
	}
	if len(page.Items) != 1 {
		t.Fatalf("GroupFeed(member): len(Items) = %d, want 1", len(page.Items))
	}

	if _, err := h.svc.GroupFeed(context.Background(), stranger, groupID, "", 0); !errors.Is(err, ErrNotAMember) {
		t.Fatalf("GroupFeed(non-member): got error %v, want ErrNotAMember", err)
	}
}

// TestGroupFeedRows_NonMemberQueryItselfReturnsZeroRows calls the raw, unexported query directly
// (same package) and asserts it returns zero rows for a non-member against a group with real
// completions -- proving the membership condition lives inside this query's own JOIN, not in a
// preceding, skippable check that a later refactor could remove without any test noticing.
func TestGroupFeedRows_NonMemberQueryItselfReturnsZeroRows(t *testing.T) {
	h := newTestHarness(t)
	organizer := createUser(t, h.store, "Organizer")
	stranger := createUser(t, h.store, "Stranger")
	groupID := createGroup(t, h, organizer)
	eventID := createEvent(t, h, groupID, organizer)
	logCompletion(t, h, organizer, eventID, events.NewCompletion{})

	rows, err := h.svc.groupFeedRows(context.Background(), stranger, groupID, "", defaultPageLimit)
	if err != nil {
		t.Fatalf("groupFeedRows(non-member): unexpected error: %v", err)
	}
	if len(rows) != 0 {
		t.Fatalf("groupFeedRows(non-member): len(rows) = %d, want 0 -- the membership JOIN did not scope this query", len(rows))
	}
}

// TestGroupFeed_OrdersByPostTimeNotCompletedAt posts three completions whose own CompletedAt
// values run opposite to their post order, and asserts the returned order follows post order
// (newest-posted first) -- this would fail if the query ever ordered by completed_at instead.
func TestGroupFeed_OrdersByPostTimeNotCompletedAt(t *testing.T) {
	h := newTestHarness(t)
	organizer := createUser(t, h.store, "Organizer")
	memberA := createUser(t, h.store, "MemberA")
	memberB := createUser(t, h.store, "MemberB")
	groupID := createGroup(t, h, organizer)
	addMember(t, h, groupID, organizer, memberA)
	addMember(t, h, groupID, organizer, memberB)
	eventID := createEvent(t, h, groupID, organizer)

	// Posted first (oldest post), latest completedAt.
	logCompletion(t, h, organizer, eventID, events.NewCompletion{CompletedAt: time.Date(2026, 9, 12, 18, 0, 0, 0, time.UTC)})
	// Posted second, middle completedAt.
	logCompletion(t, h, memberA, eventID, events.NewCompletion{CompletedAt: time.Date(2026, 9, 12, 12, 0, 0, 0, time.UTC)})
	// Posted third (newest post), earliest completedAt -- if the query ever sorted by
	// completedAt, this one (earliest) would appear last; it must appear first (newest-posted).
	logCompletion(t, h, memberB, eventID, events.NewCompletion{CompletedAt: time.Date(2026, 9, 12, 6, 0, 0, 0, time.UTC)})

	page, err := h.svc.GroupFeed(context.Background(), organizer, groupID, "", 0)
	if err != nil {
		t.Fatalf("GroupFeed: unexpected error: %v", err)
	}
	if len(page.Items) != 3 {
		t.Fatalf("len(Items) = %d, want 3", len(page.Items))
	}
	wantOrder := []uuid.UUID{memberB, memberA, organizer} // newest-posted first
	for i, want := range wantOrder {
		if page.Items[i].Actor.UserID != want {
			t.Errorf("Items[%d].Actor.UserID = %s, want %s (post-time order, not completedAt order)", i, page.Items[i].Actor.UserID, want)
		}
	}
}

// TestGroupFeed_CursorPaginationIsDisjointAndTerminates posts five completions, pages through
// with a limit of 2, and asserts every page is disjoint, the total item count across pages is 5,
// and the final page's NextCursor is empty.
func TestGroupFeed_CursorPaginationIsDisjointAndTerminates(t *testing.T) {
	h := newTestHarness(t)
	organizer := createUser(t, h.store, "Organizer")
	groupID := createGroup(t, h, organizer)
	eventID := createEvent(t, h, groupID, organizer)

	// event_completions has a UNIQUE (event_id, user_id) constraint (one completion per person
	// per event), so five completions on the same event need five distinct members.
	const total = 5
	for i := 0; i < total; i++ {
		member := createUser(t, h.store, fmt.Sprintf("Member%d", i))
		addMember(t, h, groupID, organizer, member)
		logCompletion(t, h, member, eventID, events.NewCompletion{
			CompletedAt: validCompletionTime().Add(time.Duration(i) * time.Hour),
		})
	}

	seen := map[uuid.UUID]bool{}
	cursor := ""
	pages := 0
	for {
		page, err := h.svc.GroupFeed(context.Background(), organizer, groupID, cursor, 2)
		if err != nil {
			t.Fatalf("GroupFeed(cursor=%q): unexpected error: %v", cursor, err)
		}
		pages++
		if pages > total {
			t.Fatalf("pagination did not terminate within %d pages", total)
		}
		for _, item := range page.Items {
			if seen[item.CompletionID] {
				t.Fatalf("completion %s returned on more than one page -- pages are not disjoint", item.CompletionID)
			}
			seen[item.CompletionID] = true
		}
		if page.NextCursor == "" {
			break
		}
		cursor = page.NextCursor
	}

	if len(seen) != total {
		t.Fatalf("total distinct items across all pages = %d, want %d", len(seen), total)
	}
}

// TestGroupFeed_GroupVisibleFalseHidesItem asserts a completion whose group_visible flag is
// cleared (the leave-with-remove-posts disposition's own mechanism) never appears in the feed.
func TestGroupFeed_GroupVisibleFalseHidesItem(t *testing.T) {
	h := newTestHarness(t)
	organizer := createUser(t, h.store, "Organizer")
	groupID := createGroup(t, h, organizer)
	eventID := createEvent(t, h, groupID, organizer)
	c := logCompletion(t, h, organizer, eventID, events.NewCompletion{})

	_, err := h.store.Pool().Exec(context.Background(),
		"UPDATE event_completions SET group_visible = false WHERE id = $1", c.ID)
	if err != nil {
		t.Fatalf("hiding completion: unexpected error: %v", err)
	}

	page, err := h.svc.GroupFeed(context.Background(), organizer, groupID, "", 0)
	if err != nil {
		t.Fatalf("GroupFeed: unexpected error: %v", err)
	}
	if len(page.Items) != 0 {
		t.Fatalf("len(Items) = %d, want 0 -- a group_visible=false completion must not appear", len(page.Items))
	}
}

// TestGroupFeed_LeaverCompletionStillAppearsUnlessRemoved posts a completion, has its author
// leave with DispositionKeepPosts, and asserts it still appears -- the viewer-only membership JOIN
// must never also require the completion's own author to still be a member.
func TestGroupFeed_LeaverCompletionStillAppearsUnlessRemoved(t *testing.T) {
	h := newTestHarness(t)
	organizer := createUser(t, h.store, "Organizer")
	leaver := createUser(t, h.store, "Leaver")
	groupID := createGroup(t, h, organizer)
	addMember(t, h, groupID, organizer, leaver)
	eventID := createEvent(t, h, groupID, organizer)
	logCompletion(t, h, leaver, eventID, events.NewCompletion{})

	if err := h.groupsvc.Leave(context.Background(), leaver, groupID, groups.DispositionKeepPosts); err != nil {
		t.Fatalf("Leave: unexpected error: %v", err)
	}

	page, err := h.svc.GroupFeed(context.Background(), organizer, groupID, "", 0)
	if err != nil {
		t.Fatalf("GroupFeed: unexpected error: %v", err)
	}
	if len(page.Items) != 1 {
		t.Fatalf("len(Items) = %d, want 1 -- a keep-posts leaver's completion must still appear", len(page.Items))
	}
}

// TestPage_HasNoTotalOrCountField exhaustively examines Page's own field set by reflection and
// fails if any field beyond Items/NextCursor is ever added -- the structural guarantee that a
// total, a remaining count, a member count, or a completion fraction has nowhere to be written.
func TestPage_HasNoTotalOrCountField(t *testing.T) {
	typ := reflect.TypeOf(Page{})
	want := map[string]bool{"Items": true, "NextCursor": true}
	if typ.NumField() != len(want) {
		t.Fatalf("Page has %d fields, want exactly %d (%v)", typ.NumField(), len(want), want)
	}
	for i := 0; i < typ.NumField(); i++ {
		name := typ.Field(i).Name
		if !want[name] {
			t.Errorf("Page has unexpected field %q -- only Items and NextCursor are permitted", name)
		}
	}
}

// TestGroupFeed_PhotoItemResolvesToTimeLimitedURL asserts a completion carrying a photo resolves
// PhotoURL via PhotoURLSource.SharedURL (the stub double's own recognizable shape), never a raw
// object key or a permanent link.
func TestGroupFeed_PhotoItemResolvesToTimeLimitedURL(t *testing.T) {
	h := newTestHarness(t)
	organizer := createUser(t, h.store, "Organizer")
	groupID := createGroup(t, h, organizer)
	eventID := createEvent(t, h, groupID, organizer)
	photoID := createPhotoAsset(t, h.store, organizer)
	checker := newStubPhotoChecker()
	checker.grant(organizer, photoID)
	h.eventsvc.SetPhotoOwnershipChecker(checker)
	logCompletion(t, h, organizer, eventID, events.NewCompletion{PhotoAssetID: &photoID})

	page, err := h.svc.GroupFeed(context.Background(), organizer, groupID, "", 0)
	if err != nil {
		t.Fatalf("GroupFeed: unexpected error: %v", err)
	}
	if len(page.Items) != 1 {
		t.Fatalf("len(Items) = %d, want 1", len(page.Items))
	}
	if page.Items[0].PhotoURL == nil {
		t.Fatal("Items[0].PhotoURL = nil, want a resolved URL")
	}
	wantPrefix := "https://stub.example/" + photoID.String()
	if got := *page.Items[0].PhotoURL; len(got) < len(wantPrefix) || got[:len(wantPrefix)] != wantPrefix {
		t.Errorf("PhotoURL = %q, want prefix %q (SharedURL was not called with the shared_object_key)", got, wantPrefix)
	}
}

// TestGroupFeed_PageSizeAboveCapIsClampedNotRejected requests a page size far above maxPageLimit
// and asserts the call succeeds, never erroring, effectively capped.
func TestGroupFeed_PageSizeAboveCapIsClampedNotRejected(t *testing.T) {
	h := newTestHarness(t)
	organizer := createUser(t, h.store, "Organizer")
	groupID := createGroup(t, h, organizer)
	eventID := createEvent(t, h, groupID, organizer)
	logCompletion(t, h, organizer, eventID, events.NewCompletion{})

	if _, err := h.svc.GroupFeed(context.Background(), organizer, groupID, "", 999); err != nil {
		t.Fatalf("GroupFeed(limit=999): unexpected error: %v, want the cap applied instead", err)
	}
}

func TestClampPageLimit(t *testing.T) {
	cases := []struct {
		requested int
		want      int
	}{
		{0, defaultPageLimit},
		{-5, defaultPageLimit},
		{10, 10},
		{maxPageLimit, maxPageLimit},
		{maxPageLimit + 1, maxPageLimit},
		{999, maxPageLimit},
	}
	for _, c := range cases {
		if got := clampPageLimit(c.requested); got != c.want {
			t.Errorf("clampPageLimit(%d) = %d, want %d", c.requested, got, c.want)
		}
	}
}

// TestEventFeed_MemberGetsItemsNonMemberGetsSentinel mirrors GroupFeed's own test at the
// event-scoped entry point.
func TestEventFeed_MemberGetsItemsNonMemberGetsSentinel(t *testing.T) {
	h := newTestHarness(t)
	organizer := createUser(t, h.store, "Organizer")
	stranger := createUser(t, h.store, "Stranger")
	groupID := createGroup(t, h, organizer)
	eventID := createEvent(t, h, groupID, organizer)
	logCompletion(t, h, organizer, eventID, events.NewCompletion{})

	page, err := h.svc.EventFeed(context.Background(), organizer, eventID, "", 0)
	if err != nil {
		t.Fatalf("EventFeed(member): unexpected error: %v", err)
	}
	if len(page.Items) != 1 {
		t.Fatalf("EventFeed(member): len(Items) = %d, want 1", len(page.Items))
	}

	if _, err := h.svc.EventFeed(context.Background(), stranger, eventID, "", 0); !errors.Is(err, ErrNotAMember) {
		t.Fatalf("EventFeed(non-member): got error %v, want ErrNotAMember", err)
	}
}

// TestEventFeed_UnknownEventReturnsSameSentinel asserts an eventID naming no real event returns
// the identical ErrNotAMember a non-member gets, never a distinct "not found" -- an event id alone
// must never confirm the event's existence.
func TestEventFeed_UnknownEventReturnsSameSentinel(t *testing.T) {
	h := newTestHarness(t)
	someone := createUser(t, h.store, "Someone")

	if _, err := h.svc.EventFeed(context.Background(), someone, uuid.New(), "", 0); !errors.Is(err, ErrNotAMember) {
		t.Fatalf("EventFeed(unknown event): got error %v, want ErrNotAMember", err)
	}
}
