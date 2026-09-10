// Package events is Goal-Events, RSVP, and completion logging -- a shared commitment with no
// clock, no synchronized start, and no mechanism anywhere that could rank one person against
// another (GROUPEVENTS-02, GROUPEVENTS-01).
//
// docs/group-events.md §2 is explicit that a Goal-Event is a shared, non-timed commitment, not a
// race and not a challenge in Strava's competitive sense: the organizer sets an activity type, an
// optional target, and a window; each member then individually completes the same agreed
// activity on their own schedule. There is no synchronized start and no clock.
//
// Every method in this package that reads or writes event-, RSVP-, or completion-scoped data
// calls the injected MembershipGate first -- plan 04.1-08's own RequireMember predicate, passed
// in through an interface, never a restated membership query (T-04.1-57).
//
// This file holds Goal-Event creation and the membership-scoped reads. rsvp.go holds the
// pre-event headcount. completions.go holds binary completion logging with an optional own time.
package events

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/swathivallabhaneni289/ritham/RithamService/internal/store"
)

// maxEventNameLen bounds a Goal-Event's name (matching groups.maxGroupNameLen's precedent for a
// free-text field that crosses the client -> server trust boundary; T-04.1-62).
const maxEventNameLen = 80

// maxTargetValue is an ASVS-style "absurdly large" ceiling on TargetValue (whether it names a
// distance in metres or a duration in seconds), matching internal/plan's PlateCalculator 1000kg
// precedent -- generous enough to cover any real-world target, small enough to reject
// overflow-shaped or nonsensical input.
const maxTargetValue = 1_000_000

// Target kind constants -- the closed set GoalEventTarget's Go mirror accepts. "none" means the
// group isn't racing toward a shared number (docs/group-events.md §2); "distance" and "duration"
// each require TargetValue to be present.
const (
	TargetKindNone     = "none"
	TargetKindDistance = "distance"
	TargetKindDuration = "duration"
)

// knownActivityTypes mirrors RithamCore's ActivityType.known raw values
// (RithamCore/Sources/RithamCore/Cardio/ActivityType.swift: run, walk, cycle, hike, swim,
// elliptical) so the client and this service accept exactly the same activity vocabulary without
// a second source of truth that could drift from the first.
var knownActivityTypes = map[string]bool{
	"run":        true,
	"walk":       true,
	"cycle":      true,
	"hike":       true,
	"swim":       true,
	"elliptical": true,
}

var (
	// ErrUnknownEvent is returned by every event-scoped method when eventID does not name an
	// existing goal_events row.
	ErrUnknownEvent = errors.New("events: unknown event")
	// ErrUnknownActivityType is returned by Create when ActivityType is not one of
	// knownActivityTypes.
	ErrUnknownActivityType = errors.New("events: unknown activity type")
	// ErrNameTooLong is returned by Create when Name exceeds maxEventNameLen.
	ErrNameTooLong = errors.New("events: name exceeds the maximum length")
	// ErrInvalidTarget is returned by Create when TargetKind is not one of the three known
	// values, when TargetKind is "none" but TargetValue is non-nil, or when TargetKind is
	// "distance"/"duration" but TargetValue is nil, non-positive, or over maxTargetValue.
	ErrInvalidTarget = errors.New("events: invalid target")
	// ErrInvalidEventWindow is returned by Create when EndsOn precedes StartsOn.
	ErrInvalidEventWindow = errors.New("events: end date precedes start date")
)

// MembershipGate is the capability this package needs from internal/groups -- satisfied by
// *groups.Service's own RequireMember method, passed in through this interface rather than
// restated (T-04.1-57): two definitions of "is this user a member of this group" would
// eventually disagree, and this is the boundary where that disagreement would let a non-member
// read or write group-scoped event data.
type MembershipGate interface {
	RequireMember(ctx context.Context, userID, groupID uuid.UUID) error
}

// Service is Goal-Events, RSVP, and completion logging's single entry point.
type Service struct {
	store        *store.Store
	gate         MembershipGate
	now          func() time.Time
	photoChecker PhotoOwnershipChecker
}

// New constructs a Service. gate is called before every event-, RSVP-, or completion-scoped read
// or write this package performs. photoChecker defaults to noopPhotoOwnershipChecker (see
// SetPhotoOwnershipChecker in completions.go) -- call SetPhotoOwnershipChecker once a real
// *photo.Service is available.
func New(st *store.Store, gate MembershipGate, now func() time.Time) *Service {
	return &Service{store: st, gate: gate, now: now, photoChecker: noopPhotoOwnershipChecker{}}
}

// NewGoalEvent is the input to Create.
type NewGoalEvent struct {
	Name         string
	ActivityType string
	TargetKind   string
	TargetValue  *float64
	StartsOn     time.Time
	EndsOn       time.Time
}

// GoalEvent is a goal_events row.
type GoalEvent struct {
	ID              uuid.UUID
	GroupID         uuid.UUID
	Name            string
	ActivityType    string
	TargetKind      string
	TargetValue     *float64
	StartsOn        time.Time
	EndsOn          time.Time
	OrganizerUserID uuid.UUID
	CreatedAt       time.Time
}

// Create makes organizerUserID a Goal-Event's organizer within groupID. organizerUserID must
// already be a member of groupID -- a non-member's attempt fails with the gate's own sentinel and
// creates nothing.
func (s *Service) Create(ctx context.Context, organizerUserID, groupID uuid.UUID, in NewGoalEvent) (GoalEvent, error) {
	if err := s.gate.RequireMember(ctx, organizerUserID, groupID); err != nil {
		return GoalEvent{}, err
	}
	if len(in.Name) > maxEventNameLen {
		return GoalEvent{}, ErrNameTooLong
	}
	if !knownActivityTypes[in.ActivityType] {
		return GoalEvent{}, ErrUnknownActivityType
	}
	if err := validateTarget(in.TargetKind, in.TargetValue); err != nil {
		return GoalEvent{}, err
	}
	if in.EndsOn.Before(in.StartsOn) {
		return GoalEvent{}, ErrInvalidEventWindow
	}

	id := uuid.New()
	createdAt := s.now()
	const query = `
		INSERT INTO goal_events (id, group_id, name, activity_type, target_kind, target_value, starts_on, ends_on, organizer_user_id, created_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
	`
	_, err := s.store.Pool().Exec(ctx, query,
		id, groupID, in.Name, in.ActivityType, in.TargetKind, in.TargetValue, in.StartsOn, in.EndsOn, organizerUserID, createdAt)
	if err != nil {
		return GoalEvent{}, err
	}

	return GoalEvent{
		ID:              id,
		GroupID:         groupID,
		Name:            in.Name,
		ActivityType:    in.ActivityType,
		TargetKind:      in.TargetKind,
		TargetValue:     in.TargetValue,
		StartsOn:        in.StartsOn,
		EndsOn:          in.EndsOn,
		OrganizerUserID: organizerUserID,
		CreatedAt:       createdAt,
	}, nil
}

// validateTarget enforces the closed TargetKind set and TargetValue's required-presence-or-absence
// and bounds, matching TargetKind (see this file's constants).
func validateTarget(kind string, value *float64) error {
	switch kind {
	case TargetKindNone:
		if value != nil {
			return ErrInvalidTarget
		}
	case TargetKindDistance, TargetKindDuration:
		if value == nil || *value <= 0 || *value > maxTargetValue {
			return ErrInvalidTarget
		}
	default:
		return ErrInvalidTarget
	}
	return nil
}

// List returns every Goal-Event in groupID, soonest-starting first. userID must already be a
// member of groupID -- a non-member gets nothing (the gate's own sentinel), never a filtered
// empty list that could imply the group itself is reachable.
func (s *Service) List(ctx context.Context, userID, groupID uuid.UUID) ([]GoalEvent, error) {
	if err := s.gate.RequireMember(ctx, userID, groupID); err != nil {
		return nil, err
	}

	const query = `
		SELECT id, group_id, name, activity_type, target_kind, target_value, starts_on, ends_on, organizer_user_id, created_at
		FROM goal_events
		WHERE group_id = $1
		ORDER BY starts_on, created_at
	`
	rows, err := s.store.Pool().Query(ctx, query, groupID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	events := []GoalEvent{}
	for rows.Next() {
		e, err := scanGoalEvent(rows)
		if err != nil {
			return nil, err
		}
		events = append(events, e)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return events, nil
}

// Get returns a single Goal-Event from userID's point of view. userID must already be a member of
// the event's group.
func (s *Service) Get(ctx context.Context, userID, eventID uuid.UUID) (GoalEvent, error) {
	return s.requireEventMembership(ctx, userID, eventID)
}

// rowScanner is satisfied by both pgx.Rows and pgx.Row, so scanGoalEvent serves both List's
// multi-row path and requireEventMembership's single-row path with one scan order.
type rowScanner interface {
	Scan(dest ...any) error
}

func scanGoalEvent(row rowScanner) (GoalEvent, error) {
	var e GoalEvent
	err := row.Scan(&e.ID, &e.GroupID, &e.Name, &e.ActivityType, &e.TargetKind, &e.TargetValue,
		&e.StartsOn, &e.EndsOn, &e.OrganizerUserID, &e.CreatedAt)
	return e, err
}

// requireEventMembership resolves eventID to its full row, then confirms userID is a member of
// its group via the injected gate -- the first step of every method below that is handed an
// eventID rather than a groupID directly (RSVP, WithdrawRSVP, RSVPState, LogCompletion,
// Completions, Get). The event lookup itself never returns event data to a non-member: it exists
// only to learn which group to check membership against, and any error from the gate is returned
// unchanged, before this method's own result is ever computed.
func (s *Service) requireEventMembership(ctx context.Context, userID, eventID uuid.UUID) (GoalEvent, error) {
	const query = `
		SELECT id, group_id, name, activity_type, target_kind, target_value, starts_on, ends_on, organizer_user_id, created_at
		FROM goal_events
		WHERE id = $1
	`
	e, err := scanGoalEvent(s.store.Pool().QueryRow(ctx, query, eventID))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return GoalEvent{}, ErrUnknownEvent
		}
		return GoalEvent{}, err
	}

	if err := s.gate.RequireMember(ctx, userID, e.GroupID); err != nil {
		return GoalEvent{}, err
	}
	return e, nil
}
