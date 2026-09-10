package friends

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/swathivallabhaneni289/ritham/RithamService/internal/store"
)

// testHarness wires a Service against a real, live database (RITHAM_DATABASE_URL) and a
// controllable clock, following identity/identity_test.go's testHarness convention: skip loudly,
// with an actionable message, when no database is configured, rather than silently passing
// nothing.
type testHarness struct {
	svc   *Service
	store *store.Store
	clock time.Time
}

func (h *testHarness) now() time.Time { return h.clock }

func (h *testHarness) advance(d time.Duration) { h.clock = h.clock.Add(d) }

func newTestHarness(t *testing.T) *testHarness {
	t.Helper()
	databaseURL := store.DatabaseURLFromEnv()
	if databaseURL == "" {
		t.Skip("RITHAM_DATABASE_URL is unset -- start a database (see " +
			"docker-compose.dev.yml, or a native Postgres per 04.1-01-SUMMARY.md) and run this " +
			"test with `RITHAM_DATABASE_URL=postgres://$(whoami)@localhost:5432/ritham_dev" +
			"?sslmode=disable go test ./internal/friends/...`")
	}

	// Migrate is idempotent (migrate.ErrNoChange is treated as success) -- this ensures
	// 0003_friends' tables exist even against a dev database that has only ever run 0001/0002.
	if err := store.Migrate(databaseURL); err != nil {
		t.Fatalf("store.Migrate: unexpected error: %v", err)
	}

	ctx := context.Background()
	st, err := store.New(ctx, databaseURL)
	if err != nil {
		t.Fatalf("store.New: unexpected error: %v", err)
	}
	t.Cleanup(st.Close)

	h := &testHarness{store: st, clock: time.Date(2026, 9, 9, 12, 0, 0, 0, time.UTC)}
	h.svc = New(st, h.now, []byte("test-salt-fixed-across-this-test-binary"))
	return h
}

// createUser inserts a users row with a unique apple_subject and cleans it up (cascading to every
// friends-package row that references it) when the test ends.
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

func TestFriendGraph_SendingRequestCreatesNoFriendshipAndEmptyListsForBothUsers(t *testing.T) {
	h := newTestHarness(t)
	a := createUser(t, h.store, "Alice")
	b := createUser(t, h.store, "Bob")

	if _, err := h.svc.SendRequest(context.Background(), a, b, PathDirectShare); err != nil {
		t.Fatalf("SendRequest: unexpected error: %v", err)
	}

	aFriends, err := h.svc.List(context.Background(), a)
	if err != nil {
		t.Fatalf("List(a): unexpected error: %v", err)
	}
	if len(aFriends) != 0 {
		t.Errorf("List(a) after a pending request = %d friends, want 0", len(aFriends))
	}

	bFriends, err := h.svc.List(context.Background(), b)
	if err != nil {
		t.Fatalf("List(b): unexpected error: %v", err)
	}
	if len(bFriends) != 0 {
		t.Errorf("List(b) after a pending request = %d friends, want 0", len(bFriends))
	}
}

func TestFriendGraph_AcceptingCreatesExactlyOneFriendshipRowRegardlessOfDirection(t *testing.T) {
	for _, reversed := range []bool{false, true} {
		reversed := reversed
		t.Run(map[bool]string{false: "request sent A to B", true: "request sent B to A"}[reversed], func(t *testing.T) {
			h := newTestHarness(t)
			a := createUser(t, h.store, "Alice")
			b := createUser(t, h.store, "Bob")

			from, to := a, b
			if reversed {
				from, to = b, a
			}

			req, err := h.svc.SendRequest(context.Background(), from, to, PathDirectShare)
			if err != nil {
				t.Fatalf("SendRequest: unexpected error: %v", err)
			}

			if _, err := h.svc.Accept(context.Background(), to, req.ID); err != nil {
				t.Fatalf("Accept: unexpected error: %v", err)
			}

			aFriends, err := h.svc.List(context.Background(), a)
			if err != nil {
				t.Fatalf("List(a): unexpected error: %v", err)
			}
			if len(aFriends) != 1 || aFriends[0].UserID != b {
				t.Errorf("List(a) = %+v, want exactly one friend %s", aFriends, b)
			}

			bFriends, err := h.svc.List(context.Background(), b)
			if err != nil {
				t.Fatalf("List(b): unexpected error: %v", err)
			}
			if len(bFriends) != 1 || bFriends[0].UserID != a {
				t.Errorf("List(b) = %+v, want exactly one friend %s", bFriends, a)
			}

			var count int
			err = h.store.Pool().QueryRow(context.Background(),
				"SELECT COUNT(*) FROM friendships WHERE user_a_id IN ($1, $2) OR user_b_id IN ($1, $2)",
				a, b,
			).Scan(&count)
			if err != nil {
				t.Fatalf("counting friendships rows: %v", err)
			}
			if count != 1 {
				t.Errorf("got %d friendships rows for one pair, want exactly 1 regardless of request direction", count)
			}
		})
	}
}

func TestFriendGraph_DeclineResolvesRequestAndCreatesNothing(t *testing.T) {
	h := newTestHarness(t)
	a := createUser(t, h.store, "Alice")
	b := createUser(t, h.store, "Bob")

	req, err := h.svc.SendRequest(context.Background(), a, b, PathDirectShare)
	if err != nil {
		t.Fatalf("SendRequest: unexpected error: %v", err)
	}

	if err := h.svc.Decline(context.Background(), b, req.ID); err != nil {
		t.Fatalf("Decline: unexpected error: %v", err)
	}

	areFriends, err := h.svc.AreFriends(context.Background(), a, b)
	if err != nil {
		t.Fatalf("AreFriends: unexpected error: %v", err)
	}
	if areFriends {
		t.Errorf("AreFriends after decline = true, want false")
	}

	var state string
	err = h.store.Pool().QueryRow(context.Background(),
		"SELECT state FROM friend_requests WHERE id = $1", req.ID).Scan(&state)
	if err != nil {
		t.Fatalf("querying friend_requests row: %v", err)
	}
	if state != "declined" {
		t.Errorf("friend_requests.state = %q, want %q", state, "declined")
	}
}

func TestFriendGraph_CannotSendRequestToSelf(t *testing.T) {
	h := newTestHarness(t)
	a := createUser(t, h.store, "Alice")

	_, err := h.svc.SendRequest(context.Background(), a, a, PathDirectShare)
	if !errors.Is(err, ErrSelfRequest) {
		t.Fatalf("SendRequest(a, a): got error %v, want ErrSelfRequest", err)
	}
}

func TestFriendGraph_SecondPendingRequestBetweenSamePairIsRejected(t *testing.T) {
	h := newTestHarness(t)
	a := createUser(t, h.store, "Alice")
	b := createUser(t, h.store, "Bob")

	if _, err := h.svc.SendRequest(context.Background(), a, b, PathDirectShare); err != nil {
		t.Fatalf("SendRequest (first): unexpected error: %v", err)
	}

	_, err := h.svc.SendRequest(context.Background(), a, b, PathDirectShare)
	if !errors.Is(err, ErrRequestExists) {
		t.Fatalf("SendRequest (second, same ordered pair): got error %v, want ErrRequestExists", err)
	}

	var count int
	err = h.store.Pool().QueryRow(context.Background(),
		"SELECT COUNT(*) FROM friend_requests WHERE from_user_id = $1 AND to_user_id = $2", a, b,
	).Scan(&count)
	if err != nil {
		t.Fatalf("counting friend_requests rows: %v", err)
	}
	if count != 1 {
		t.Errorf("got %d friend_requests rows after a rejected duplicate, want exactly 1", count)
	}
}

func TestFriendGraph_SendingRequestToExistingFriendIsRejected(t *testing.T) {
	h := newTestHarness(t)
	a := createUser(t, h.store, "Alice")
	b := createUser(t, h.store, "Bob")

	req, err := h.svc.SendRequest(context.Background(), a, b, PathDirectShare)
	if err != nil {
		t.Fatalf("SendRequest: unexpected error: %v", err)
	}
	if _, err := h.svc.Accept(context.Background(), b, req.ID); err != nil {
		t.Fatalf("Accept: unexpected error: %v", err)
	}

	_, err = h.svc.SendRequest(context.Background(), a, b, PathDirectShare)
	if !errors.Is(err, ErrAlreadyFriends) {
		t.Fatalf("SendRequest between existing friends: got error %v, want ErrAlreadyFriends", err)
	}
}

func TestFriendGraph_AcceptingOrDecliningRequestAddressedToSomeoneElseFailsWithNotFoundSentinel(t *testing.T) {
	h := newTestHarness(t)
	a := createUser(t, h.store, "Alice")
	b := createUser(t, h.store, "Bob")
	stranger := createUser(t, h.store, "Stranger")

	req, err := h.svc.SendRequest(context.Background(), a, b, PathDirectShare)
	if err != nil {
		t.Fatalf("SendRequest: unexpected error: %v", err)
	}

	_, acceptErr := h.svc.Accept(context.Background(), stranger, req.ID)
	if !errors.Is(acceptErr, ErrNoSuchRequest) {
		t.Errorf("Accept by a stranger: got error %v, want ErrNoSuchRequest", acceptErr)
	}

	declineErr := h.svc.Decline(context.Background(), stranger, req.ID)
	if !errors.Is(declineErr, ErrNoSuchRequest) {
		t.Errorf("Decline by a stranger: got error %v, want ErrNoSuchRequest", declineErr)
	}

	nonexistentID := uuid.New()
	_, nonexistentAcceptErr := h.svc.Accept(context.Background(), b, nonexistentID)
	if !errors.Is(nonexistentAcceptErr, ErrNoSuchRequest) {
		t.Errorf("Accept of a nonexistent request: got error %v, want ErrNoSuchRequest", nonexistentAcceptErr)
	}
	if !errors.Is(acceptErr, nonexistentAcceptErr) && acceptErr.Error() != nonexistentAcceptErr.Error() {
		t.Errorf("acting on someone else's request and a nonexistent request must fail identically: %v vs %v", acceptErr, nonexistentAcceptErr)
	}
}

func TestFriendGraph_UnfriendingRemovesPairAndNeitherListsTheOther(t *testing.T) {
	h := newTestHarness(t)
	a := createUser(t, h.store, "Alice")
	b := createUser(t, h.store, "Bob")

	req, err := h.svc.SendRequest(context.Background(), a, b, PathDirectShare)
	if err != nil {
		t.Fatalf("SendRequest: unexpected error: %v", err)
	}
	if _, err := h.svc.Accept(context.Background(), b, req.ID); err != nil {
		t.Fatalf("Accept: unexpected error: %v", err)
	}

	if err := h.svc.Unfriend(context.Background(), a, b); err != nil {
		t.Fatalf("Unfriend: unexpected error: %v", err)
	}

	aFriends, err := h.svc.List(context.Background(), a)
	if err != nil {
		t.Fatalf("List(a): unexpected error: %v", err)
	}
	if len(aFriends) != 0 {
		t.Errorf("List(a) after Unfriend = %d friends, want 0", len(aFriends))
	}

	bFriends, err := h.svc.List(context.Background(), b)
	if err != nil {
		t.Fatalf("List(b): unexpected error: %v", err)
	}
	if len(bFriends) != 0 {
		t.Errorf("List(b) after Unfriend = %d friends, want 0", len(bFriends))
	}
}

func TestFriendGraph_UnfriendingNonFriendFails(t *testing.T) {
	h := newTestHarness(t)
	a := createUser(t, h.store, "Alice")
	b := createUser(t, h.store, "Bob")

	err := h.svc.Unfriend(context.Background(), a, b)
	if !errors.Is(err, ErrNotFriends) {
		t.Fatalf("Unfriend of a non-friend: got error %v, want ErrNotFriends", err)
	}
}

func TestFriendGraph_AreFriendsIsSymmetric(t *testing.T) {
	h := newTestHarness(t)
	a := createUser(t, h.store, "Alice")
	b := createUser(t, h.store, "Bob")

	req, err := h.svc.SendRequest(context.Background(), a, b, PathDirectShare)
	if err != nil {
		t.Fatalf("SendRequest: unexpected error: %v", err)
	}
	if _, err := h.svc.Accept(context.Background(), b, req.ID); err != nil {
		t.Fatalf("Accept: unexpected error: %v", err)
	}

	forward, err := h.svc.AreFriends(context.Background(), a, b)
	if err != nil {
		t.Fatalf("AreFriends(a, b): unexpected error: %v", err)
	}
	backward, err := h.svc.AreFriends(context.Background(), b, a)
	if err != nil {
		t.Fatalf("AreFriends(b, a): unexpected error: %v", err)
	}
	if !forward || forward != backward {
		t.Errorf("AreFriends(a, b) = %v, AreFriends(b, a) = %v, want both true", forward, backward)
	}
}

func TestFriendGraph_ReverseDirectionRequestAlsoAcceptedResolvesWithoutError(t *testing.T) {
	// Both A->B and B->A may be pending simultaneously (distinct ordered pairs, per
	// friend_requests_pending_pair_idx). If both get accepted, the second Accept call must not
	// fail just because the friendship row the first Accept created already exists.
	h := newTestHarness(t)
	a := createUser(t, h.store, "Alice")
	b := createUser(t, h.store, "Bob")

	reqAB, err := h.svc.SendRequest(context.Background(), a, b, PathDirectShare)
	if err != nil {
		t.Fatalf("SendRequest(a, b): unexpected error: %v", err)
	}
	reqBA, err := h.svc.SendRequest(context.Background(), b, a, PathDirectShare)
	if err != nil {
		t.Fatalf("SendRequest(b, a): unexpected error: %v", err)
	}

	if _, err := h.svc.Accept(context.Background(), b, reqAB.ID); err != nil {
		t.Fatalf("Accept(reqAB): unexpected error: %v", err)
	}
	if _, err := h.svc.Accept(context.Background(), a, reqBA.ID); err != nil {
		t.Fatalf("Accept(reqBA): unexpected error: %v", err)
	}

	var count int
	err = h.store.Pool().QueryRow(context.Background(),
		"SELECT COUNT(*) FROM friendships WHERE user_a_id IN ($1, $2) OR user_b_id IN ($1, $2)",
		a, b,
	).Scan(&count)
	if err != nil {
		t.Fatalf("counting friendships rows: %v", err)
	}
	if count != 1 {
		t.Errorf("got %d friendships rows after both directions were accepted, want exactly 1", count)
	}
}
