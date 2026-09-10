package events

import (
	"context"

	"github.com/google/uuid"
)

// RSVPState is the pre-event headcount and the viewer's own membership in it -- a count and a
// boolean, nothing else. docs/group-events.md §2 keeps the RSVP screen and the post-event
// completion feed deliberately separate: the app must never juxtapose who said they were in
// against who came out, which is what a per-person roster returned here would eventually invite
// (a later screen re-rendering it beside completions). RSVPState therefore has no roster field at
// all, and no method in this file ever references event_completions.
type RSVPState struct {
	Count      int
	ViewerIsIn bool
}

// RSVP records userID's individual "I'm in" for eventID, idempotently: responding twice leaves a
// count of one. userID must already be a member of eventID's group.
func (s *Service) RSVP(ctx context.Context, userID, eventID uuid.UUID) (RSVPState, error) {
	if _, err := s.requireEventMembership(ctx, userID, eventID); err != nil {
		return RSVPState{}, err
	}

	const query = `
		INSERT INTO event_rsvps (event_id, user_id, responded_at)
		VALUES ($1, $2, $3)
		ON CONFLICT (event_id, user_id) DO NOTHING
	`
	if _, err := s.store.Pool().Exec(ctx, query, eventID, userID, s.now()); err != nil {
		return RSVPState{}, err
	}

	return s.rsvpState(ctx, eventID, userID)
}

// WithdrawRSVP removes userID's RSVP from eventID, if one exists. Withdrawing when no RSVP exists
// is a no-op, not an error -- withdrawing can be redone (re-RSVP'd) freely afterward.
func (s *Service) WithdrawRSVP(ctx context.Context, userID, eventID uuid.UUID) (RSVPState, error) {
	if _, err := s.requireEventMembership(ctx, userID, eventID); err != nil {
		return RSVPState{}, err
	}

	const query = `DELETE FROM event_rsvps WHERE event_id = $1 AND user_id = $2`
	if _, err := s.store.Pool().Exec(ctx, query, eventID, userID); err != nil {
		return RSVPState{}, err
	}

	return s.rsvpState(ctx, eventID, userID)
}

// RSVPState returns eventID's current headcount and userID's own membership in it, without
// touching or referencing event_completions in any way -- it is served entirely off event_rsvps.
func (s *Service) RSVPState(ctx context.Context, userID, eventID uuid.UUID) (RSVPState, error) {
	if _, err := s.requireEventMembership(ctx, userID, eventID); err != nil {
		return RSVPState{}, err
	}
	return s.rsvpState(ctx, eventID, userID)
}

// rsvpState computes the count and viewer-boolean in one query, after the caller has already
// confirmed userID's membership.
func (s *Service) rsvpState(ctx context.Context, eventID, userID uuid.UUID) (RSVPState, error) {
	const query = `
		SELECT
			(SELECT COUNT(*) FROM event_rsvps WHERE event_id = $1),
			EXISTS(SELECT 1 FROM event_rsvps WHERE event_id = $1 AND user_id = $2)
	`
	var state RSVPState
	err := s.store.Pool().QueryRow(ctx, query, eventID, userID).Scan(&state.Count, &state.ViewerIsIn)
	if err != nil {
		return RSVPState{}, err
	}
	return state, nil
}
