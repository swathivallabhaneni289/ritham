package events

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgerrcode"
	"github.com/jackc/pgx/v5/pgconn"

	"github.com/swathivallabhaneni289/ritham/RithamService/internal/groups"
	"github.com/swathivallabhaneni289/ritham/RithamService/internal/photo"
)

// maxCaptionLen and maxPlaceNameLen bound the two free-text fields a completion may carry
// (T-04.1-62: oversized free-text input).
const (
	maxCaptionLen   = 280
	maxPlaceNameLen = 120
	// maxOwnTimeSeconds is a generous ceiling (24 hours) on the one optional numeric field this
	// package ever accepts -- an own time is a fact about the person who supplied it, never
	// required, never inferred, and this bound exists only to reject nonsensical input, never
	// to rank it (docs/group-events.md §2).
	maxOwnTimeSeconds = 24 * 60 * 60
)

var (
	// ErrOutsideEventWindow is returned by LogCompletion when CompletedAt falls outside
	// [StartsOn, EndsOn] (inclusive, by calendar date).
	ErrOutsideEventWindow = errors.New("events: completion falls outside the event window")
	// ErrAlreadyCompleted is returned by LogCompletion when userID already has a completion row
	// for this eventID -- a second completion is rejected rather than duplicated.
	ErrAlreadyCompleted = errors.New("events: already completed this event")
	// ErrCaptionTooLong is returned by LogCompletion when Caption exceeds maxCaptionLen.
	ErrCaptionTooLong = errors.New("events: caption exceeds the maximum length")
	// ErrPlaceNameTooLong is returned by LogCompletion when PlaceName exceeds maxPlaceNameLen.
	// Not in this plan's own must_haves sentinel list, but the plan's behavior list explicitly
	// requires "a caption or place name over its bound is rejected", and reusing
	// ErrCaptionTooLong for a place-name violation would misreport the actual failing field in
	// every caller-facing error message (Rule 2 deviation -- see 04.1-10-SUMMARY.md).
	ErrPlaceNameTooLong = errors.New("events: place name exceeds the maximum length")
	// ErrInvalidOwnTime is returned by LogCompletion when OwnTimeSeconds is negative or exceeds
	// maxOwnTimeSeconds.
	ErrInvalidOwnTime = errors.New("events: own time is outside the accepted range")
	// ErrPhotoNotOwned is returned by LogCompletion when PhotoAssetID does not name an asset the
	// caller owns (including when it does not exist at all -- see photo.ErrAssetNotFound's own
	// doc comment on why those two cases are never distinguishable).
	ErrPhotoNotOwned = errors.New("events: photo asset is not owned by this user")
)

// PhotoOwnershipChecker is the capability LogCompletion needs from internal/photo to verify a
// referenced photo asset belongs to the caller -- satisfied by *photo.Service's own Asset method,
// passed in through this interface rather than restated (mirroring MembershipGate's precedent).
// Construction-time-optional: a Service with no call to SetPhotoOwnershipChecker uses
// noopPhotoOwnershipChecker, under which any PhotoAssetID reference fails closed with
// ErrPhotoNotOwned (never silently accepted), matching groups.CompletionVisibility's
// safe-default-is-a-no-op precedent inverted for a check that must fail safe, not succeed safe.
type PhotoOwnershipChecker interface {
	Asset(ctx context.Context, requesterUserID, assetID uuid.UUID) (photo.Asset, error)
}

// noopPhotoOwnershipChecker satisfies PhotoOwnershipChecker by rejecting every asset reference --
// the safe default when no real photo service has been wired in yet.
type noopPhotoOwnershipChecker struct{}

func (noopPhotoOwnershipChecker) Asset(ctx context.Context, requesterUserID, assetID uuid.UUID) (photo.Asset, error) {
	return photo.Asset{}, photo.ErrAssetNotFound
}

// SetPhotoOwnershipChecker overrides the default fail-closed PhotoOwnershipChecker. Not part of
// New's own signature (locked by this plan's artifacts) since it is a construction-time-optional
// dependency, mirroring groups.Service.SetCompletionVisibility's precedent.
func (s *Service) SetPhotoOwnershipChecker(checker PhotoOwnershipChecker) {
	s.photoChecker = checker
}

// Member is one completion's author -- a user id and display name, the minimal identity a
// completion card needs. Declared locally (not imported from internal/groups) so this package's
// wire-facing types have no dependency on groups' own Member shape.
type Member struct {
	UserID      uuid.UUID
	DisplayName string
}

// NewCompletion is the input to LogCompletion. Every field but CompletedAt is optional and absent
// by default -- this is the whole boundary a personal distance, pace, or route is never accepted
// through, because GROUPEVENTS-02 keeps that data in the user's own private log by construction,
// not by a filter that could be got wrong.
type NewCompletion struct {
	CompletedAt    time.Time
	OwnTimeSeconds *int
	PhotoAssetID   *uuid.UUID
	PlaceName      *string
	Caption        *string
}

// Completion is an event_completions row, joined with its author's display name. It has no field
// for a position, a total, or how many members completed -- the only ordering input anywhere in
// this package is PostedAt (see Completions).
type Completion struct {
	ID             uuid.UUID
	EventID        uuid.UUID
	User           Member
	CompletedAt    time.Time
	OwnTimeSeconds *int
	PhotoAssetID   *uuid.UUID
	PlaceName      *string
	Caption        *string
	PostedAt       time.Time
}

// LogCompletion records that userID finished eventID -- a binary fact, optionally carrying their
// own time. userID must already be a member of eventID's group; a second completion for the same
// person and event is rejected rather than duplicated; a completion outside the event's window is
// rejected; a referenced photo asset the caller does not own is rejected and stores nothing.
func (s *Service) LogCompletion(ctx context.Context, userID, eventID uuid.UUID, in NewCompletion) (Completion, error) {
	evt, err := s.requireEventMembership(ctx, userID, eventID)
	if err != nil {
		return Completion{}, err
	}

	if !withinEventWindow(in.CompletedAt, evt.StartsOn, evt.EndsOn) {
		return Completion{}, ErrOutsideEventWindow
	}
	if in.OwnTimeSeconds != nil && (*in.OwnTimeSeconds < 0 || *in.OwnTimeSeconds > maxOwnTimeSeconds) {
		return Completion{}, ErrInvalidOwnTime
	}
	if in.Caption != nil && len(*in.Caption) > maxCaptionLen {
		return Completion{}, ErrCaptionTooLong
	}
	if in.PlaceName != nil && len(*in.PlaceName) > maxPlaceNameLen {
		return Completion{}, ErrPlaceNameTooLong
	}
	if in.PhotoAssetID != nil {
		if _, err := s.photoChecker.Asset(ctx, userID, *in.PhotoAssetID); err != nil {
			if errors.Is(err, photo.ErrAssetNotFound) {
				return Completion{}, ErrPhotoNotOwned
			}
			return Completion{}, err
		}
	}

	id := uuid.New()
	postedAt := s.now()
	const query = `
		INSERT INTO event_completions (id, event_id, user_id, completed_at, own_time_seconds, photo_asset_id, place_name, caption, posted_at, group_visible)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, true)
	`
	_, err = s.store.Pool().Exec(ctx, query,
		id, eventID, userID, in.CompletedAt, in.OwnTimeSeconds, in.PhotoAssetID, in.PlaceName, in.Caption, postedAt)
	if err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == pgerrcode.UniqueViolation {
			return Completion{}, ErrAlreadyCompleted
		}
		return Completion{}, err
	}

	displayName, err := s.userDisplayName(ctx, userID)
	if err != nil {
		return Completion{}, err
	}

	return Completion{
		ID:             id,
		EventID:        eventID,
		User:           Member{UserID: userID, DisplayName: displayName},
		CompletedAt:    in.CompletedAt,
		OwnTimeSeconds: in.OwnTimeSeconds,
		PhotoAssetID:   in.PhotoAssetID,
		PlaceName:      in.PlaceName,
		Caption:        in.Caption,
		PostedAt:       postedAt,
	}, nil
}

// withinEventWindow reports whether completedAt's calendar date (UTC) falls within
// [startsOn, endsOn] inclusive. startsOn/endsOn are `date` columns (scanned as UTC midnight);
// endsOn is treated as an inclusive whole day, so a single-day event (endsOn == startsOn) still
// accepts a completion posted any time during that day.
func withinEventWindow(completedAt, startsOn, endsOn time.Time) bool {
	completedDate := completedAt.UTC()
	windowStart := startsOn.UTC()
	windowEnd := endsOn.UTC().AddDate(0, 0, 1) // exclusive upper bound: the day after endsOn
	return !completedDate.Before(windowStart) && completedDate.Before(windowEnd)
}

// userDisplayName reads a user's current display name, for stamping onto a freshly logged
// Completion's Member.
func (s *Service) userDisplayName(ctx context.Context, userID uuid.UUID) (string, error) {
	const query = `SELECT display_name FROM users WHERE id = $1`
	var name string
	if err := s.store.Pool().QueryRow(ctx, query, userID).Scan(&name); err != nil {
		return "", err
	}
	return name, nil
}

// Completions returns eventID's group-visible completions, oldest-post-time first, and nothing
// else -- no count query, no aggregate, no join to event_rsvps. userID must already be a member
// of eventID's group.
func (s *Service) Completions(ctx context.Context, userID, eventID uuid.UUID) ([]Completion, error) {
	if _, err := s.requireEventMembership(ctx, userID, eventID); err != nil {
		return nil, err
	}

	const query = `
		SELECT ec.id, ec.event_id, u.id, u.display_name, ec.completed_at, ec.own_time_seconds,
		       ec.photo_asset_id, ec.place_name, ec.caption, ec.posted_at
		FROM event_completions ec
		JOIN users u ON u.id = ec.user_id
		WHERE ec.event_id = $1 AND ec.group_visible = true
		ORDER BY ec.posted_at
	`
	rows, err := s.store.Pool().Query(ctx, query, eventID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	completions := []Completion{}
	for rows.Next() {
		var c Completion
		if err := rows.Scan(&c.ID, &c.EventID, &c.User.UserID, &c.User.DisplayName, &c.CompletedAt,
			&c.OwnTimeSeconds, &c.PhotoAssetID, &c.PlaceName, &c.Caption, &c.PostedAt); err != nil {
			return nil, err
		}
		completions = append(completions, c)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return completions, nil
}

// completionVisibility is this package's real implementation of groups.CompletionVisibility,
// wired in via groupsSvc.SetCompletionVisibility (main.go) -- plan 04.1-08 left this seam as a
// tested no-op pending event_completions' existence. It holds no dependencies of its own:
// HideGroupCompletions receives its transaction handle (tx) from its caller (membership.go's
// Leave, inside the same transaction as the membership row's deletion), and every other value it
// needs (groupID, userID) arrives as an argument.
type completionVisibility struct{}

// NewCompletionVisibility constructs the real CompletionVisibility implementation backing
// groups.Service.Leave's remove-posts disposition.
func NewCompletionVisibility() groups.CompletionVisibility {
	return completionVisibility{}
}

// HideGroupCompletions clears group_visible on every one of userID's completions for a Goal-Event
// within groupID. event_completions carries no group_id column of its own -- a completion's
// group.Event.GroupID is the sole source of truth for which group it belongs to, so this joins
// through goal_events rather than restating that relationship as a second column.
func (completionVisibility) HideGroupCompletions(ctx context.Context, tx groups.DBTX, groupID, userID uuid.UUID) error {
	const query = `
		UPDATE event_completions
		SET group_visible = false
		WHERE user_id = $2
		  AND event_id IN (SELECT id FROM goal_events WHERE group_id = $1)
	`
	_, err := tx.Exec(ctx, query, groupID, userID)
	return err
}
