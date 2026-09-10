package feed

import (
	"context"
	"errors"
	"reflect"
	"testing"

	"github.com/swathivallabhaneni289/ritham/RithamService/internal/events"
)

// TestSendCheer_ExactlyTwoValuesAcceptedThirdRejected asserts both known cheer values succeed and
// a third, unrecognized value is rejected with ErrUnknownCheer.
func TestSendCheer_ExactlyTwoValuesAcceptedThirdRejected(t *testing.T) {
	h := newTestHarness(t)
	organizer := createUser(t, h.store, "Organizer")
	groupID := createGroup(t, h, organizer)
	eventID := createEvent(t, h, groupID, organizer)
	c := logCompletion(t, h, organizer, eventID, events.NewCompletion{})

	for _, cheer := range []string{"niceWork", "keepGoing"} {
		if err := h.svc.SendCheer(context.Background(), organizer, c.ID, cheer); err != nil {
			t.Errorf("SendCheer(%q): unexpected error: %v", cheer, err)
		}
	}

	if err := h.svc.SendCheer(context.Background(), organizer, c.ID, "fistBump"); !errors.Is(err, ErrUnknownCheer) {
		t.Errorf("SendCheer(unknown cheer): got error %v, want ErrUnknownCheer", err)
	}
}

// TestSendCheer_TwiceIsIdempotentLeavesOneRow sends the same cheer twice and asserts exactly one
// row exists in completion_cheers for that (completion, user, cheer) triple.
func TestSendCheer_TwiceIsIdempotentLeavesOneRow(t *testing.T) {
	h := newTestHarness(t)
	organizer := createUser(t, h.store, "Organizer")
	groupID := createGroup(t, h, organizer)
	eventID := createEvent(t, h, groupID, organizer)
	c := logCompletion(t, h, organizer, eventID, events.NewCompletion{})

	if err := h.svc.SendCheer(context.Background(), organizer, c.ID, "niceWork"); err != nil {
		t.Fatalf("SendCheer(1st): unexpected error: %v", err)
	}
	if err := h.svc.SendCheer(context.Background(), organizer, c.ID, "niceWork"); err != nil {
		t.Fatalf("SendCheer(2nd): unexpected error: %v", err)
	}

	var count int
	err := h.store.Pool().QueryRow(context.Background(),
		"SELECT COUNT(*) FROM completion_cheers WHERE completion_id = $1 AND user_id = $2 AND cheer = $3",
		c.ID, organizer, "niceWork",
	).Scan(&count)
	if err != nil {
		t.Fatalf("counting completion_cheers rows: %v", err)
	}
	if count != 1 {
		t.Errorf("completion_cheers rows for this (completion, user, cheer) = %d, want 1", count)
	}
}

// TestWithdrawCheer_RemovesItNeverSentIsNoOp asserts withdrawing a sent cheer removes it, and
// withdrawing a cheer that was never sent succeeds with no error (a no-op, not a failure).
func TestWithdrawCheer_RemovesItNeverSentIsNoOp(t *testing.T) {
	h := newTestHarness(t)
	organizer := createUser(t, h.store, "Organizer")
	groupID := createGroup(t, h, organizer)
	eventID := createEvent(t, h, groupID, organizer)
	c := logCompletion(t, h, organizer, eventID, events.NewCompletion{})

	if err := h.svc.SendCheer(context.Background(), organizer, c.ID, "niceWork"); err != nil {
		t.Fatalf("SendCheer: unexpected error: %v", err)
	}
	if err := h.svc.WithdrawCheer(context.Background(), organizer, c.ID, "niceWork"); err != nil {
		t.Fatalf("WithdrawCheer(sent): unexpected error: %v", err)
	}

	var exists bool
	err := h.store.Pool().QueryRow(context.Background(),
		"SELECT EXISTS(SELECT 1 FROM completion_cheers WHERE completion_id = $1 AND user_id = $2 AND cheer = $3)",
		c.ID, organizer, "niceWork",
	).Scan(&exists)
	if err != nil {
		t.Fatalf("checking completion_cheers: %v", err)
	}
	if exists {
		t.Error("completion_cheers row still exists after WithdrawCheer")
	}

	// Withdrawing a cheer never sent (keepGoing was never sent by organizer on this completion).
	if err := h.svc.WithdrawCheer(context.Background(), organizer, c.ID, "keepGoing"); err != nil {
		t.Errorf("WithdrawCheer(never sent): unexpected error: %v, want nil (no-op)", err)
	}
}

// TestSendCheer_OnlyGroupMemberCanCheer asserts a non-member of the completion's group cannot
// cheer it.
func TestSendCheer_OnlyGroupMemberCanCheer(t *testing.T) {
	h := newTestHarness(t)
	organizer := createUser(t, h.store, "Organizer")
	stranger := createUser(t, h.store, "Stranger")
	groupID := createGroup(t, h, organizer)
	eventID := createEvent(t, h, groupID, organizer)
	c := logCompletion(t, h, organizer, eventID, events.NewCompletion{})

	if err := h.svc.SendCheer(context.Background(), stranger, c.ID, "niceWork"); !errors.Is(err, ErrNotAMember) {
		t.Errorf("SendCheer(non-member): got error %v, want ErrNotAMember", err)
	}
}

// TestViewerCheers_OneUsersCheerChangesNothingObservableForAnother is the test that matters most
// for this file: user A cheering a completion must change nothing another user, B, can observe
// beyond B's own two booleans. Each of A and B sees only their own cheer state on the same
// completion.
func TestViewerCheers_OneUsersCheerChangesNothingObservableForAnother(t *testing.T) {
	h := newTestHarness(t)
	organizer := createUser(t, h.store, "Organizer")
	userA := createUser(t, h.store, "UserA")
	userB := createUser(t, h.store, "UserB")
	groupID := createGroup(t, h, organizer)
	addMember(t, h, groupID, organizer, userA)
	addMember(t, h, groupID, organizer, userB)
	eventID := createEvent(t, h, groupID, organizer)
	c := logCompletion(t, h, organizer, eventID, events.NewCompletion{})

	if err := h.svc.SendCheer(context.Background(), userA, c.ID, "niceWork"); err != nil {
		t.Fatalf("SendCheer(userA): unexpected error: %v", err)
	}

	pageAsA, err := h.svc.GroupFeed(context.Background(), userA, groupID, "", 0)
	if err != nil {
		t.Fatalf("GroupFeed(userA): unexpected error: %v", err)
	}
	pageAsB, err := h.svc.GroupFeed(context.Background(), userB, groupID, "", 0)
	if err != nil {
		t.Fatalf("GroupFeed(userB): unexpected error: %v", err)
	}

	if got := pageAsA.Items[0].Cheers; got != (ViewerCheers{NiceWorkSentByViewer: true}) {
		t.Errorf("userA's own view of Cheers = %+v, want NiceWorkSentByViewer=true only", got)
	}
	if got := pageAsB.Items[0].Cheers; got != (ViewerCheers{}) {
		t.Errorf("userB's view of Cheers = %+v, want both false -- userA's cheer must not leak into userB's own state", got)
	}
}

// TestFeedExportedMethods_ReturnNoNumericCheerValue reflects over SendCheer and WithdrawCheer's
// own signatures and asserts each returns exactly (error) -- no exported function in this package
// returns a cheer count, a cheer list, or a per-person breakdown. Combined with
// nodenominator_test.go's whole-package source scan (Task 3), this is the structural half of that
// same guarantee scoped to this file's own two exported functions.
func TestFeedExportedMethods_ReturnNoNumericCheerValue(t *testing.T) {
	svcType := reflect.TypeOf(&Service{})
	for _, name := range []string{"SendCheer", "WithdrawCheer"} {
		method, ok := svcType.MethodByName(name)
		if !ok {
			t.Fatalf("*Service has no method %q", name)
		}
		// NumOut counts only the return values (the receiver is not part of Type.Out via
		// MethodByName on a *T, since Func.Type here is the method's own func signature
		// including the receiver as In(0)).
		numOut := method.Func.Type().NumOut()
		if numOut != 1 {
			t.Fatalf("%s has %d return values, want exactly 1 (error)", name, numOut)
		}
		errType := reflect.TypeOf((*error)(nil)).Elem()
		if got := method.Func.Type().Out(0); got != errType {
			t.Errorf("%s's return type = %s, want error", name, got)
		}
	}
}
