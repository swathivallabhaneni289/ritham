package friends

import (
	"context"
	"errors"
	"testing"
)

func TestMatchContacts_CallerOptedOutReturnsOptedOutSentinelAndNoLookup(t *testing.T) {
	h := newTestHarness(t)
	caller := createUser(t, h.store, "Caller")
	candidate := createUser(t, h.store, "Candidate")

	digest := []byte("phone:+15550000000")
	if err := h.svc.SetContactMatchOptIn(context.Background(), candidate, true, [][]byte{digest}); err != nil {
		t.Fatalf("SetContactMatchOptIn(candidate): unexpected error: %v", err)
	}

	// caller has never opted in at all -- no contact_match_optins row exists for them yet.
	_, err := h.svc.MatchContacts(context.Background(), caller, [][]byte{digest})
	if !errors.Is(err, ErrContactMatchOptedOut) {
		t.Fatalf("MatchContacts with an opted-out caller: got error %v, want ErrContactMatchOptedOut", err)
	}
}

func TestMatchContacts_OneSidedOptInYieldsNoMatchInEitherDirection(t *testing.T) {
	digest := []byte("phone:+15551234567")

	t.Run("caller opted in, candidate opted out", func(t *testing.T) {
		h := newTestHarness(t)
		caller := createUser(t, h.store, "Caller")
		candidate := createUser(t, h.store, "Candidate")

		if err := h.svc.SetContactMatchOptIn(context.Background(), caller, true, nil); err != nil {
			t.Fatalf("SetContactMatchOptIn(caller): unexpected error: %v", err)
		}
		// candidate never opts in -- their own identifier digest is never stored.
		_ = candidate

		matches, err := h.svc.MatchContacts(context.Background(), caller, [][]byte{digest})
		if err != nil {
			t.Fatalf("MatchContacts: unexpected error: %v", err)
		}
		if len(matches) != 0 {
			t.Errorf("MatchContacts with an opted-out candidate = %+v, want no matches", matches)
		}
	})

	t.Run("candidate opted in, caller opted out", func(t *testing.T) {
		h := newTestHarness(t)
		caller := createUser(t, h.store, "Caller")
		candidate := createUser(t, h.store, "Candidate")

		if err := h.svc.SetContactMatchOptIn(context.Background(), candidate, true, [][]byte{digest}); err != nil {
			t.Fatalf("SetContactMatchOptIn(candidate): unexpected error: %v", err)
		}

		_, err := h.svc.MatchContacts(context.Background(), caller, [][]byte{digest})
		if !errors.Is(err, ErrContactMatchOptedOut) {
			t.Fatalf("MatchContacts with an opted-out caller: got error %v, want ErrContactMatchOptedOut", err)
		}
	})
}

func TestMatchContacts_BothSidesOptedInAndDigestOverlapReturnsMatch(t *testing.T) {
	h := newTestHarness(t)
	caller := createUser(t, h.store, "Caller")
	candidate := createUser(t, h.store, "Candidate")
	stranger := createUser(t, h.store, "Stranger")

	sharedDigest := []byte("phone:+15559998888")
	strangerDigest := []byte("phone:+15550001111")

	if err := h.svc.SetContactMatchOptIn(context.Background(), caller, true, nil); err != nil {
		t.Fatalf("SetContactMatchOptIn(caller): unexpected error: %v", err)
	}
	if err := h.svc.SetContactMatchOptIn(context.Background(), candidate, true, [][]byte{sharedDigest}); err != nil {
		t.Fatalf("SetContactMatchOptIn(candidate): unexpected error: %v", err)
	}
	if err := h.svc.SetContactMatchOptIn(context.Background(), stranger, true, [][]byte{strangerDigest}); err != nil {
		t.Fatalf("SetContactMatchOptIn(stranger): unexpected error: %v", err)
	}

	matches, err := h.svc.MatchContacts(context.Background(), caller, [][]byte{sharedDigest})
	if err != nil {
		t.Fatalf("MatchContacts: unexpected error: %v", err)
	}
	if len(matches) != 1 || matches[0].UserID != candidate {
		t.Errorf("MatchContacts = %+v, want exactly one match: candidate %s", matches, candidate)
	}
}

func TestSetContactMatchOptIn_OverCapDigestsRejected(t *testing.T) {
	h := newTestHarness(t)
	caller := createUser(t, h.store, "Caller")

	tooMany := make([][]byte, maxContactDigestsPerRequest+1)
	for i := range tooMany {
		tooMany[i] = []byte{byte(i), byte(i >> 8)}
	}

	err := h.svc.SetContactMatchOptIn(context.Background(), caller, true, tooMany)
	if !errors.Is(err, ErrTooManyContactDigests) {
		t.Fatalf("SetContactMatchOptIn with %d digests: got error %v, want ErrTooManyContactDigests", len(tooMany), err)
	}
}

func TestMatchContacts_OverCapDigestsRejected(t *testing.T) {
	h := newTestHarness(t)
	caller := createUser(t, h.store, "Caller")
	if err := h.svc.SetContactMatchOptIn(context.Background(), caller, true, nil); err != nil {
		t.Fatalf("SetContactMatchOptIn: unexpected error: %v", err)
	}

	tooMany := make([][]byte, maxContactDigestsPerRequest+1)
	for i := range tooMany {
		tooMany[i] = []byte{byte(i), byte(i >> 8)}
	}

	_, err := h.svc.MatchContacts(context.Background(), caller, tooMany)
	if !errors.Is(err, ErrTooManyContactDigests) {
		t.Fatalf("MatchContacts with %d digests: got error %v, want ErrTooManyContactDigests", len(tooMany), err)
	}
}

func TestSetContactMatchOptIn_OptingOutDeletesStoredDigests(t *testing.T) {
	h := newTestHarness(t)
	caller := createUser(t, h.store, "Caller")
	digest := []byte("phone:+15552223333")

	if err := h.svc.SetContactMatchOptIn(context.Background(), caller, true, [][]byte{digest}); err != nil {
		t.Fatalf("SetContactMatchOptIn (opt in): unexpected error: %v", err)
	}

	var countBefore int
	err := h.store.Pool().QueryRow(context.Background(),
		"SELECT COUNT(*) FROM contact_match_digests WHERE user_id = $1", caller,
	).Scan(&countBefore)
	if err != nil {
		t.Fatalf("counting contact_match_digests (before): %v", err)
	}
	if countBefore != 1 {
		t.Fatalf("got %d stored digests after opting in with one, want 1", countBefore)
	}

	if err := h.svc.SetContactMatchOptIn(context.Background(), caller, false, nil); err != nil {
		t.Fatalf("SetContactMatchOptIn (opt out): unexpected error: %v", err)
	}

	var countAfter int
	err = h.store.Pool().QueryRow(context.Background(),
		"SELECT COUNT(*) FROM contact_match_digests WHERE user_id = $1", caller,
	).Scan(&countAfter)
	if err != nil {
		t.Fatalf("counting contact_match_digests (after): %v", err)
	}
	if countAfter != 0 {
		t.Errorf("got %d stored digests after opting out, want 0 (opting out deletes digests, not just the flag)", countAfter)
	}
}
