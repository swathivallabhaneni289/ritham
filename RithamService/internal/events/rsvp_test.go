package events

import (
	"context"
	"errors"
	"reflect"
	"testing"

	"github.com/google/uuid"

	"github.com/swathivallabhaneni289/ritham/RithamService/internal/groups"
)

func TestRSVP_RespondingTwiceLeavesCountOfOne(t *testing.T) {
	h := newTestHarness(t)
	organizer := createUser(t, h.store, "Organizer")
	groupID := createGroup(t, h, organizer)
	eventID := createEvent(t, h, groupID, organizer)

	if _, err := h.svc.RSVP(context.Background(), organizer, eventID); err != nil {
		t.Fatalf("RSVP (first): unexpected error: %v", err)
	}
	state, err := h.svc.RSVP(context.Background(), organizer, eventID)
	if err != nil {
		t.Fatalf("RSVP (second, idempotent): unexpected error: %v", err)
	}
	if state.Count != 1 {
		t.Errorf("Count after responding twice = %d, want 1", state.Count)
	}
	if !state.ViewerIsIn {
		t.Errorf("ViewerIsIn after RSVP = false, want true")
	}
}

func TestRSVP_WithdrawingDecrementsAndCanBeRedone(t *testing.T) {
	h := newTestHarness(t)
	organizer := createUser(t, h.store, "Organizer")
	groupID := createGroup(t, h, organizer)
	eventID := createEvent(t, h, groupID, organizer)

	if _, err := h.svc.RSVP(context.Background(), organizer, eventID); err != nil {
		t.Fatalf("RSVP: unexpected error: %v", err)
	}
	state, err := h.svc.WithdrawRSVP(context.Background(), organizer, eventID)
	if err != nil {
		t.Fatalf("WithdrawRSVP: unexpected error: %v", err)
	}
	if state.Count != 0 || state.ViewerIsIn {
		t.Errorf("state after withdraw = %+v, want Count=0, ViewerIsIn=false", state)
	}

	state2, err := h.svc.RSVP(context.Background(), organizer, eventID)
	if err != nil {
		t.Fatalf("RSVP (redo after withdraw): unexpected error: %v", err)
	}
	if state2.Count != 1 || !state2.ViewerIsIn {
		t.Errorf("state after redo = %+v, want Count=1, ViewerIsIn=true", state2)
	}
}

// TestRSVP_StateHasNoRosterField exhaustively examines RSVPState's field set -- a count and a
// viewer boolean, and nothing else, per docs/group-events.md §2's separation between the
// pre-event headcount and the post-event completion feed.
func TestRSVP_StateHasNoRosterField(t *testing.T) {
	typ := reflect.TypeOf(RSVPState{})
	if typ.NumField() != 2 {
		t.Fatalf("RSVPState has %d fields, want exactly 2 (a count and a viewer boolean, no roster)", typ.NumField())
	}
	for i := 0; i < typ.NumField(); i++ {
		name := typ.Field(i).Name
		if name != "Count" && name != "ViewerIsIn" {
			t.Errorf("unexpected RSVPState field %q -- RSVPState must carry only a count and a viewer boolean, never a per-person list", name)
		}
	}
}

func TestRSVP_MultipleRespondersCountCorrectly(t *testing.T) {
	h := newTestHarness(t)
	organizer := createUser(t, h.store, "Organizer")
	memberA := createUser(t, h.store, "MemberA")
	memberB := createUser(t, h.store, "MemberB")
	groupID := createGroup(t, h, organizer)
	addMember(t, h, groupID, organizer, memberA)
	addMember(t, h, groupID, organizer, memberB)
	eventID := createEvent(t, h, groupID, organizer)

	for _, u := range []uuid.UUID{organizer, memberA, memberB} {
		if _, err := h.svc.RSVP(context.Background(), u, eventID); err != nil {
			t.Fatalf("RSVP(%s): unexpected error: %v", u, err)
		}
	}

	state, err := h.svc.RSVPState(context.Background(), memberA, eventID)
	if err != nil {
		t.Fatalf("RSVPState: unexpected error: %v", err)
	}
	if state.Count != 3 {
		t.Errorf("Count = %d, want 3", state.Count)
	}
	if !state.ViewerIsIn {
		t.Errorf("ViewerIsIn(memberA) = false, want true")
	}
}

// TestRSVP_ServedWithoutReferenceToCompletionData proves RSVPState's own query never joins or
// aggregates against event_completions, regardless of what that table holds -- it inserts a
// completion row directly (Task 2's LogCompletion is out of this file's scope) rather than
// through the service, so this test has no dependency on completions.go.
func TestRSVP_ServedWithoutReferenceToCompletionData(t *testing.T) {
	h := newTestHarness(t)
	organizer := createUser(t, h.store, "Organizer")
	groupID := createGroup(t, h, organizer)
	eventID := createEvent(t, h, groupID, organizer)

	if _, err := h.svc.RSVP(context.Background(), organizer, eventID); err != nil {
		t.Fatalf("RSVP: unexpected error: %v", err)
	}

	before, err := h.svc.RSVPState(context.Background(), organizer, eventID)
	if err != nil {
		t.Fatalf("RSVPState (before any completion row exists): unexpected error: %v", err)
	}

	_, err = h.store.Pool().Exec(context.Background(),
		`INSERT INTO event_completions (id, event_id, user_id, completed_at, posted_at, group_visible)
		 VALUES ($1, $2, $3, $4, $5, true)`,
		uuid.New(), eventID, organizer, h.clock, h.clock)
	if err != nil {
		t.Fatalf("inserting a completion row directly: %v", err)
	}

	after, err := h.svc.RSVPState(context.Background(), organizer, eventID)
	if err != nil {
		t.Fatalf("RSVPState (after a completion row exists): unexpected error: %v", err)
	}
	if before != after {
		t.Errorf("RSVPState changed after a completion row was inserted: before=%+v after=%+v -- RSVP state must never reference completion data", before, after)
	}
}

func TestRSVP_NonMemberCannotRSVP(t *testing.T) {
	h := newTestHarness(t)
	organizer := createUser(t, h.store, "Organizer")
	stranger := createUser(t, h.store, "Stranger")
	groupID := createGroup(t, h, organizer)
	eventID := createEvent(t, h, groupID, organizer)

	if _, err := h.svc.RSVP(context.Background(), stranger, eventID); !errors.Is(err, groups.ErrNotAMember) {
		t.Fatalf("RSVP(non-member): got error %v, want groups.ErrNotAMember", err)
	}
}
