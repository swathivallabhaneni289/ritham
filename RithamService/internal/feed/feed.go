// Package feed is the group-only, chronological, membership-scoped feed (GROUPEVENTS-04) built on
// top of plan 04.1-10's internal/events completions. It is the surface every group member reads
// after logging their own completions -- and the one place docs/group-events.md §2's enumerated
// prohibitions (no pace, no time-based rank, no first-to-complete marker, no denominator paired
// against completions, no precise location) all converge, because this is the response every
// member of a group actually sees.
//
// The membership check that authorizes reading a feed page is part of the feed SQL itself -- a
// JOIN against group_members keyed on the requesting (viewer) user id -- never a preceding call
// that a later refactor could skip or a caller could bypass by supplying a group/event id alone.
// See groupFeedRows/eventFeedRows below, and nodenominator_test.go's structural gate, which fails
// the build if an aggregate or ranking construct is ever introduced anywhere in this package or
// internal/httpapi.
//
// This file holds the feed queries and their shared plumbing. cheers.go holds the fixed,
// count-free cheer mechanic. exportconsent.go holds the per-visible-person export consent gate.
package feed

import (
	"context"
	"encoding/base64"
	"errors"
	"fmt"
	"strconv"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/swathivallabhaneni289/ritham/RithamService/internal/groups"
	"github.com/swathivallabhaneni289/ritham/RithamService/internal/store"
)

// ErrNotAMember is a true alias for groups.ErrNotAMember (var, not a fresh errors.New), not a
// second sentinel for the same condition -- mirroring internal/events' own precedent of
// surfacing the membership gate's sentinel unchanged. A fresh error value here would silently
// break errors.Is(err, groups.ErrNotAMember) at every call site that still checks the original.
var ErrNotAMember = groups.ErrNotAMember

const (
	// defaultPageLimit is used when a caller requests no explicit page size.
	defaultPageLimit = 30
	// maxPageLimit is the hard cap on a single page -- a caller requesting more gets this many,
	// never an error (T-04.1-76: unbounded feed page requests is a documented DoS vector).
	maxPageLimit = 50
	// photoURLTTL bounds how long a feed item's photo URL stays valid. A permanent public URL
	// would be the generic shareable link GROUPEVENTS-04 forbids, so the short TTL is the
	// mechanism, not a performance choice -- every page request resolves a fresh URL.
	photoURLTTL = 15 * time.Minute
)

// PhotoURLSource is the capability this package needs to turn a shared_object_key into a
// time-limited URL -- satisfied by *photo.ObjectStore's own SharedURL method, passed in through
// this interface rather than restated, mirroring internal/events.PhotoOwnershipChecker's
// precedent. Feed tests substitute a stub, so no running S3-compatible backend is required to
// exercise every behavior below except the URL's own bytes.
type PhotoURLSource interface {
	SharedURL(ctx context.Context, key string, ttl time.Duration) (string, error)
}

// Person is one completion's author -- an id and a display name, the minimal identity a feed
// item needs. Declared locally so this package's wire-facing types hold no dependency on
// internal/events' or internal/groups' own Member shapes.
type Person struct {
	UserID      uuid.UUID `json:"userId"`
	DisplayName string    `json:"displayName"`
}

// ViewerCheers reflects only the requesting user's own cheer state on one completion -- two
// booleans, never a count, never any other viewer's state. Two users who both cheer the same
// completion each see only their own two booleans; neither learns anything about the other
// (docs/group-events.md §2/§4).
type ViewerCheers struct {
	NiceWorkSentByViewer  bool `json:"niceWorkSentByViewer"`
	KeepGoingSentByViewer bool `json:"keepGoingSentByViewer"`
}

// Item is one feed entry: a completion, its author, the event it belongs to, and the viewer's own
// cheer state. Every optional field is nil unless the completion actually carries it -- an own
// time, a photo, a place name, and a caption are all genuinely optional, matching
// events.Completion's own shape. There is deliberately no field here for a position, a rank, or
// any figure derived from comparing this item to any other.
type Item struct {
	CompletionID   uuid.UUID    `json:"completionId"`
	Actor          Person       `json:"actor"`
	EventID        uuid.UUID    `json:"eventId"`
	EventName      string       `json:"eventName"`
	ActivityType   string       `json:"activityType"`
	CompletedAt    time.Time    `json:"completedAt"`
	OwnTimeSeconds *int         `json:"ownTimeSeconds,omitempty"`
	PhotoURL       *string      `json:"photoUrl,omitempty"`
	PlaceName      *string      `json:"placeName,omitempty"`
	Caption        *string      `json:"caption,omitempty"`
	PostedAt       time.Time    `json:"postedAt"`
	Cheers         ViewerCheers `json:"cheers"`
}

// Page is one page of feed items, newest-posted first, plus an opaque cursor for the next page.
//
// Page deliberately has no field for a total, a remaining count, a member count, or a completion
// fraction -- a completion count sitting beside a membership figure is precisely the juxtaposition
// docs/group-events.md §2 rules out, and the safest way to guarantee it never renders is for the
// response to have nowhere to put it. nodenominator_test.go pins this struct's exact JSON key set
// by reflection and by serialization, so a future field addition fails a test rather than shipping
// silently. NextCursor is empty ("") once the caller has reached the end of the feed.
type Page struct {
	Items      []Item `json:"items"`
	NextCursor string `json:"nextCursor,omitempty"`
}

// Service is the group feed, cheer, and export-consent gate's single entry point.
type Service struct {
	store  *store.Store
	photos PhotoURLSource
	now    func() time.Time
}

// New constructs a Service.
func New(st *store.Store, photos PhotoURLSource, now func() time.Time) *Service {
	return &Service{store: st, photos: photos, now: now}
}

// feedRow is the shared shape every feed query scans into before URL resolution and clamping.
type feedRow struct {
	item Item
	// photoKey is the shared_object_key behind item.PhotoURL, resolved to a real URL only after
	// clamping to the page's own limit (so a dropped lookahead row never costs a wasted presign
	// call).
	photoKey *string
}

// GroupFeed returns groupID's feed page, newest-posted first, from viewerUserID's point of view.
// viewerUserID must be a current member of groupID -- a non-member gets ErrNotAMember and no
// items, even when groupID names a real group with real completions.
func (s *Service) GroupFeed(ctx context.Context, viewerUserID, groupID uuid.UUID, cursor string, limit int) (Page, error) {
	limit = clampPageLimit(limit)

	rows, err := s.groupFeedRows(ctx, viewerUserID, groupID, cursor, limit)
	if err != nil {
		return Page{}, err
	}
	if len(rows) == 0 {
		isMember, err := s.isGroupMember(ctx, groupID, viewerUserID)
		if err != nil {
			return Page{}, err
		}
		if !isMember {
			return Page{}, ErrNotAMember
		}
	}
	return s.toPage(ctx, rows, limit)
}

// EventFeed returns eventID's feed page, newest-posted first, from viewerUserID's point of view.
// viewerUserID must be a current member of eventID's group -- a non-member (or an unknown event
// id) gets ErrNotAMember and no items, identically, so an event id alone never confirms the
// event's existence.
func (s *Service) EventFeed(ctx context.Context, viewerUserID, eventID uuid.UUID, cursor string, limit int) (Page, error) {
	limit = clampPageLimit(limit)

	rows, err := s.eventFeedRows(ctx, viewerUserID, eventID, cursor, limit)
	if err != nil {
		return Page{}, err
	}
	if len(rows) == 0 {
		groupID, err := s.groupIDForEvent(ctx, eventID)
		if err != nil {
			if errors.Is(err, pgx.ErrNoRows) {
				return Page{}, ErrNotAMember
			}
			return Page{}, err
		}
		isMember, err := s.isGroupMember(ctx, groupID, viewerUserID)
		if err != nil {
			return Page{}, err
		}
		if !isMember {
			return Page{}, ErrNotAMember
		}
	}
	return s.toPage(ctx, rows, limit)
}

// groupFeedRows is the raw, membership-scoped query for GroupFeed -- unexported so a same-package
// test can call it directly and assert it returns zero rows for a non-member against a group
// holding real completions, proving the membership condition lives in this query's own JOIN
// (gm.user_id = viewerUserID) rather than in a preceding, skippable check. It fetches limit+1 rows
// so the caller can detect whether a next page exists without a separate count query.
//
// The JOIN below is scoped to the viewer's own membership only -- never the completion author's.
// A completion posted by someone who has since left the group must still appear (unless they left
// with the remove-posts disposition, which clears group_visible directly), and joining on the
// author's membership would silently break that.
func (s *Service) groupFeedRows(ctx context.Context, viewerUserID, groupID uuid.UUID, cursor string, limit int) ([]feedRow, error) {
	where, args, err := cursorPredicate("ge.group_id = $2", []any{viewerUserID, groupID}, cursor)
	if err != nil {
		return nil, err
	}
	args = append(args, limit+1)
	query := feedSelectPrefix + where + feedOrderAndLimit(len(args))
	return s.queryFeedRows(ctx, query, args)
}

// eventFeedRows is EventFeed's raw, membership-scoped query -- see groupFeedRows' doc comment for
// the shared shape and the why-viewer-only-join rationale.
func (s *Service) eventFeedRows(ctx context.Context, viewerUserID, eventID uuid.UUID, cursor string, limit int) ([]feedRow, error) {
	where, args, err := cursorPredicate("ec.event_id = $2", []any{viewerUserID, eventID}, cursor)
	if err != nil {
		return nil, err
	}
	args = append(args, limit+1)
	query := feedSelectPrefix + where + feedOrderAndLimit(len(args))
	return s.queryFeedRows(ctx, query, args)
}

// feedSelectPrefix is shared by groupFeedRows and eventFeedRows -- they differ only in their scope
// predicate (group_id vs event_id), appended by the caller as $2. $1 is always the viewer's own
// user id, reused for the membership JOIN and both per-viewer cheer EXISTS subqueries -- a
// per-viewer lookup, never an aggregate -- this file's own acceptance gate greps for the two SQL
// aggregate functions a completion total could be built from and requires zero matches.
const feedSelectPrefix = `
	SELECT ec.id, ec.user_id, u.display_name, ec.event_id, ge.name, ge.activity_type,
	       ec.completed_at, ec.own_time_seconds, pa.shared_object_key, ec.place_name, ec.caption,
	       ec.posted_at,
	       EXISTS(SELECT 1 FROM completion_cheers cc WHERE cc.completion_id = ec.id AND cc.user_id = $1 AND cc.cheer = 'niceWork'),
	       EXISTS(SELECT 1 FROM completion_cheers cc WHERE cc.completion_id = ec.id AND cc.user_id = $1 AND cc.cheer = 'keepGoing')
	FROM event_completions ec
	JOIN goal_events ge ON ge.id = ec.event_id
	JOIN group_members gm ON gm.group_id = ge.group_id AND gm.user_id = $1
	JOIN users u ON u.id = ec.user_id
	LEFT JOIN photo_assets pa ON pa.id = ec.photo_asset_id
	WHERE ec.group_visible = true AND `

// cursorPredicate appends the scope predicate and, when cursor is non-empty, a keyset predicate
// over (posted_at, id) so pagination is stable and disjoint across pages. scopePredicate must
// reference $2; args must already hold exactly [viewerUserID, scopeID] in that order.
func cursorPredicate(scopePredicate string, args []any, cursor string) (string, []any, error) {
	if cursor == "" {
		return scopePredicate, args, nil
	}
	postedAt, id, err := decodeCursor(cursor)
	if err != nil {
		return "", nil, err
	}
	args = append(args, postedAt, id)
	n := len(args)
	predicate := fmt.Sprintf("%s AND (ec.posted_at, ec.id) < ($%d, $%d)", scopePredicate, n-1, n)
	return predicate, args, nil
}

// feedOrderAndLimit appends the shared ORDER BY / LIMIT clause. n is the 1-based ordinal of the
// limit argument (always the last element of args).
func feedOrderAndLimit(n int) string {
	return fmt.Sprintf(" ORDER BY ec.posted_at DESC, ec.id DESC LIMIT $%d", n)
}

// queryFeedRows executes query with args and scans every row into a feedRow. It never resolves a
// photo URL itself -- that happens only after toPage clamps to the requested page size, so a
// lookahead row that gets dropped never costs a wasted presign call.
func (s *Service) queryFeedRows(ctx context.Context, query string, args []any) ([]feedRow, error) {
	rows, err := s.store.Pool().Query(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []feedRow
	for rows.Next() {
		var r feedRow
		if err := rows.Scan(
			&r.item.CompletionID, &r.item.Actor.UserID, &r.item.Actor.DisplayName,
			&r.item.EventID, &r.item.EventName, &r.item.ActivityType,
			&r.item.CompletedAt, &r.item.OwnTimeSeconds, &r.photoKey, &r.item.PlaceName, &r.item.Caption,
			&r.item.PostedAt,
			&r.item.Cheers.NiceWorkSentByViewer, &r.item.Cheers.KeepGoingSentByViewer,
		); err != nil {
			return nil, err
		}
		out = append(out, r)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return out, nil
}

// toPage clamps rows to limit, resolves each kept item's photo URL (if any), and derives the next
// cursor from the last kept item when more rows exist beyond limit.
func (s *Service) toPage(ctx context.Context, rows []feedRow, limit int) (Page, error) {
	page := Page{Items: []Item{}}
	if len(rows) == 0 {
		return page, nil
	}

	hasMore := len(rows) > limit
	if hasMore {
		rows = rows[:limit]
	}

	for _, r := range rows {
		item := r.item
		if r.photoKey != nil {
			url, err := s.photos.SharedURL(ctx, *r.photoKey, photoURLTTL)
			if err != nil {
				return Page{}, err
			}
			item.PhotoURL = &url
		}
		page.Items = append(page.Items, item)
	}

	if hasMore {
		last := rows[len(rows)-1].item
		page.NextCursor = encodeCursor(last.PostedAt, last.CompletionID)
	}
	return page, nil
}

// encodeCursor and decodeCursor round-trip a (posted_at, completion_id) keyset position as an
// opaque, URL-safe token -- callers never construct or parse one themselves.
func encodeCursor(postedAt time.Time, id uuid.UUID) string {
	raw := postedAt.UTC().Format(time.RFC3339Nano) + "|" + id.String()
	return base64.RawURLEncoding.EncodeToString([]byte(raw))
}

func decodeCursor(cursor string) (time.Time, uuid.UUID, error) {
	raw, err := base64.RawURLEncoding.DecodeString(cursor)
	if err != nil {
		return time.Time{}, uuid.UUID{}, fmt.Errorf("feed: invalid cursor: %w", err)
	}
	parts := strings.SplitN(string(raw), "|", 2)
	if len(parts) != 2 {
		return time.Time{}, uuid.UUID{}, errors.New("feed: invalid cursor")
	}
	postedAt, err := time.Parse(time.RFC3339Nano, parts[0])
	if err != nil {
		return time.Time{}, uuid.UUID{}, fmt.Errorf("feed: invalid cursor: %w", err)
	}
	id, err := uuid.Parse(parts[1])
	if err != nil {
		return time.Time{}, uuid.UUID{}, fmt.Errorf("feed: invalid cursor: %w", err)
	}
	return postedAt, id, nil
}

// clampPageLimit maps a caller-requested page size to a usable value: non-positive or unset
// becomes defaultPageLimit, anything above maxPageLimit is clamped down to it -- never an error
// (T-04.1-76).
func clampPageLimit(requested int) int {
	if requested <= 0 {
		return defaultPageLimit
	}
	if requested > maxPageLimit {
		return maxPageLimit
	}
	return requested
}

// isGroupMember reports whether userID currently belongs to groupID, read directly against
// group_members -- the same table the feed queries themselves join against, so this check can
// never disagree with what the feed query just did.
func (s *Service) isGroupMember(ctx context.Context, groupID, userID uuid.UUID) (bool, error) {
	var exists bool
	err := s.store.Pool().QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM group_members WHERE group_id = $1 AND user_id = $2)`,
		groupID, userID,
	).Scan(&exists)
	return exists, err
}

// groupIDForEvent resolves eventID to its owning group, or pgx.ErrNoRows when eventID names no
// goal_events row -- callers map that to ErrNotAMember, the same sentinel a non-member gets, so an
// event id alone never confirms the event's existence.
func (s *Service) groupIDForEvent(ctx context.Context, eventID uuid.UUID) (uuid.UUID, error) {
	var groupID uuid.UUID
	err := s.store.Pool().QueryRow(ctx,
		`SELECT group_id FROM goal_events WHERE id = $1`, eventID,
	).Scan(&groupID)
	return groupID, err
}

// requireVisibleCompletion confirms completionID names a group_visible completion viewerUserID
// can currently see (a current member of that completion's group), returning its eventID and
// groupID. cheers.go's SendCheer/WithdrawCheer call this so a cheer's authorization runs through
// exactly the same visibility test as reading the feed -- a user who cannot see a completion
// cannot cheer it -- rather than a second, potentially diverging membership check. A completion
// that doesn't exist and one the viewer isn't authorized to see are, deliberately, the identical
// ErrNotAMember, so probing a completion id never confirms its existence.
func (s *Service) requireVisibleCompletion(ctx context.Context, viewerUserID, completionID uuid.UUID) (eventID, groupID uuid.UUID, err error) {
	const query = `
		SELECT ec.event_id, ge.group_id
		FROM event_completions ec
		JOIN goal_events ge ON ge.id = ec.event_id
		JOIN group_members gm ON gm.group_id = ge.group_id AND gm.user_id = $2
		WHERE ec.id = $1 AND ec.group_visible = true
	`
	err = s.store.Pool().QueryRow(ctx, query, completionID, viewerUserID).Scan(&eventID, &groupID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return uuid.UUID{}, uuid.UUID{}, ErrNotAMember
		}
		return uuid.UUID{}, uuid.UUID{}, err
	}
	return eventID, groupID, nil
}

// parseLimit is a small shared helper for the HTTP layer (feed_handler.go) -- kept here rather
// than duplicated, since it's the same non-positive-vs-invalid distinction clampPageLimit itself
// makes: an empty or unparseable string yields 0 (clampPageLimit's own "unset" sentinel), never an
// error, so a malformed limit parameter degrades to the default page size rather than 400ing.
func parseLimit(raw string) int {
	if raw == "" {
		return 0
	}
	n, err := strconv.Atoi(raw)
	if err != nil {
		return 0
	}
	return n
}
