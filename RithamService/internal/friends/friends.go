// Package friends is the mutual friend graph and its three closed-loop connection paths
// (HOUSEHOLD-02, GROUPEVENTS-01). Every connection begins with a request, and a friendship exists
// only after both people have independently said yes -- there is no one-directional follow
// anywhere in this schema (docs/group-events.md §1). This file holds the request/accept/decline
// graph itself; invites.go and contactmatch.go hold the two connection paths that produce a
// request without a prior lookup.
package friends

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgerrcode"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"

	"github.com/swathivallabhaneni289/ritham/RithamService/internal/store"
)

// ConnectionPath records which of the three closed-loop paths (docs/group-events.md §1) produced
// a given friend request.
type ConnectionPath string

const (
	PathContactMatch ConnectionPath = "contact_match"
	PathInviteLink    ConnectionPath = "invite_link"
	PathDirectShare   ConnectionPath = "direct_share"
)

// requestState is the closed set of states a friend_requests row can hold. Unexported: callers
// observe state only through Request.State (a string, for JSON-friendliness at the HTTP layer)
// and through this package's own exported sentinels, never by constructing a state literal.
type requestState string

const (
	statePending  requestState = "pending"
	stateAccepted requestState = "accepted"
	stateDeclined requestState = "declined"
)

var (
	// ErrSelfRequest is returned when fromUserID and toUserID are the same user.
	ErrSelfRequest = errors.New("friends: cannot send a friend request to yourself")
	// ErrAlreadyFriends is returned when the two users are already friends.
	ErrAlreadyFriends = errors.New("friends: users are already friends")
	// ErrRequestExists is returned when a pending request already exists for the same ordered
	// (from, to) pair -- enforced at the database level by friend_requests_pending_pair_idx, not
	// only by this check.
	ErrRequestExists = errors.New("friends: a pending request already exists")
	// ErrNoSuchRequest is returned by Accept/Decline both when the request id does not exist and
	// when it exists but is addressed to someone else -- a request id alone is never sufficient
	// authority, and the caller must not be able to distinguish the two cases (T-04.1-30).
	ErrNoSuchRequest = errors.New("friends: no such pending request")
	// ErrNotFriends is returned by Unfriend when the two users have no friendship row.
	ErrNotFriends = errors.New("friends: users are not friends")
)

// Request is a friend_requests row.
type Request struct {
	ID             uuid.UUID
	FromUserID     uuid.UUID
	ToUserID       uuid.UUID
	State          string
	ConnectionPath ConnectionPath
	CreatedAt      time.Time
	ResolvedAt     *time.Time
}

// Friendship is a friendships row: an established, mutual connection stored once as an unordered
// pair.
type Friendship struct {
	UserAID       uuid.UUID
	UserBID       uuid.UUID
	EstablishedAt time.Time
}

// Friend is a friendship or a contact-match candidate resolved against the users table, from the
// perspective of the caller who is not UserID.
type Friend struct {
	UserID        uuid.UUID
	DisplayName   string
	EstablishedAt time.Time
}

// dbtx is the minimal capability friends.go/invites.go/contactmatch.go need from a database
// handle -- satisfied structurally by both *pgxpool.Pool and pgx.Tx, so every mutating helper can
// run either as its own standalone statement or as one step inside a larger transaction (e.g.
// invites.go's RedeemInvite) without duplicating its logic for each case.
type dbtx interface {
	Exec(ctx context.Context, sql string, args ...any) (pgconn.CommandTag, error)
	Query(ctx context.Context, sql string, args ...any) (pgx.Rows, error)
	QueryRow(ctx context.Context, sql string, args ...any) pgx.Row
}

// Service is the friends domain's single entry point.
type Service struct {
	store *store.Store
	now   func() time.Time
}

// New constructs a Service.
func New(st *store.Store, now func() time.Time) *Service {
	return &Service{store: st, now: now}
}

// SendRequest creates a pending friend request from fromUserID to toUserID. It creates no
// friendship -- that happens only when the recipient calls Accept.
func (s *Service) SendRequest(ctx context.Context, fromUserID, toUserID uuid.UUID, path ConnectionPath) (Request, error) {
	if fromUserID == toUserID {
		return Request{}, ErrSelfRequest
	}

	areFriends, err := s.AreFriends(ctx, fromUserID, toUserID)
	if err != nil {
		return Request{}, err
	}
	if areFriends {
		return Request{}, ErrAlreadyFriends
	}

	return insertFriendRequest(ctx, s.store.Pool(), fromUserID, toUserID, path, s.now())
}

// insertFriendRequest is the sole writer of new friend_requests rows, shared by SendRequest (its
// own statement, against the pool) and invites.go's RedeemInvite (one statement inside a larger
// transaction, against a pgx.Tx) -- both routes to a new request go through the identical insert
// and identical unique-violation handling.
func insertFriendRequest(ctx context.Context, db dbtx, fromUserID, toUserID uuid.UUID, path ConnectionPath, now time.Time) (Request, error) {
	id := uuid.New()
	const query = `
		INSERT INTO friend_requests (id, from_user_id, to_user_id, state, connection_path, created_at)
		VALUES ($1, $2, $3, $4, $5, $6)
	`
	if _, err := db.Exec(ctx, query, id, fromUserID, toUserID, string(statePending), string(path), now); err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == pgerrcode.UniqueViolation {
			return Request{}, ErrRequestExists
		}
		return Request{}, err
	}

	return Request{
		ID:             id,
		FromUserID:     fromUserID,
		ToUserID:       toUserID,
		State:          string(statePending),
		ConnectionPath: path,
		CreatedAt:      now,
	}, nil
}

// Accept resolves requestID as accepted and creates the friendship, in one transaction. userID
// must be the request's to_user_id -- a request id alone is never sufficient authority, so acting
// on someone else's request fails with the identical ErrNoSuchRequest a nonexistent request id
// would produce (T-04.1-30).
func (s *Service) Accept(ctx context.Context, userID, requestID uuid.UUID) (Friendship, error) {
	tx, err := s.store.Pool().Begin(ctx)
	if err != nil {
		return Friendship{}, err
	}
	defer tx.Rollback(ctx)

	now := s.now()
	const updateQuery = `
		UPDATE friend_requests
		SET state = $1, resolved_at = $2
		WHERE id = $3 AND to_user_id = $4 AND state = $5
		RETURNING from_user_id, to_user_id
	`
	var fromUserID, toUserID uuid.UUID
	err = tx.QueryRow(ctx, updateQuery, string(stateAccepted), now, requestID, userID, string(statePending)).
		Scan(&fromUserID, &toUserID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return Friendship{}, ErrNoSuchRequest
		}
		return Friendship{}, err
	}

	userA, userB := orderPair(fromUserID, toUserID)

	// ON CONFLICT DO NOTHING: the other direction's pending request (B->A, a distinct row from
	// the A->B just accepted, per friend_requests_pending_pair_idx's ordered-pair scoping) may
	// already have been accepted first, in which case the friendship row already exists --
	// without this, the second Accept call would 500 on the friendships PRIMARY KEY rather than
	// simply confirming the pair is (still) friends.
	const insertQuery = `
		INSERT INTO friendships (user_a_id, user_b_id, established_at)
		VALUES ($1, $2, $3)
		ON CONFLICT (user_a_id, user_b_id) DO NOTHING
		RETURNING established_at
	`
	var establishedAt time.Time
	err = tx.QueryRow(ctx, insertQuery, userA, userB, now).Scan(&establishedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			// Conflict: the pair was already friends (the reverse request was accepted first).
			// Read the row that already exists rather than fabricating a value.
			const selectQuery = `SELECT established_at FROM friendships WHERE user_a_id = $1 AND user_b_id = $2`
			if err := tx.QueryRow(ctx, selectQuery, userA, userB).Scan(&establishedAt); err != nil {
				return Friendship{}, err
			}
		} else {
			return Friendship{}, err
		}
	}

	if err := tx.Commit(ctx); err != nil {
		return Friendship{}, err
	}

	return Friendship{UserAID: userA, UserBID: userB, EstablishedAt: establishedAt}, nil
}

// Decline resolves requestID as declined and creates nothing. userID must be the request's
// to_user_id, matching Accept's authorization scoping.
func (s *Service) Decline(ctx context.Context, userID, requestID uuid.UUID) error {
	const query = `
		UPDATE friend_requests
		SET state = $1, resolved_at = $2
		WHERE id = $3 AND to_user_id = $4 AND state = $5
	`
	tag, err := s.store.Pool().Exec(ctx, query, string(stateDeclined), s.now(), requestID, userID, string(statePending))
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrNoSuchRequest
	}
	return nil
}

// Incoming lists the pending requests addressed to userID, oldest first.
func (s *Service) Incoming(ctx context.Context, userID uuid.UUID) ([]Request, error) {
	const query = `
		SELECT id, from_user_id, to_user_id, state, connection_path, created_at, resolved_at
		FROM friend_requests
		WHERE to_user_id = $1 AND state = $2
		ORDER BY created_at
	`
	rows, err := s.store.Pool().Query(ctx, query, userID, string(statePending))
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var requests []Request
	for rows.Next() {
		var (
			r          Request
			path       string
			state      string
			resolvedAt *time.Time
		)
		if err := rows.Scan(&r.ID, &r.FromUserID, &r.ToUserID, &state, &path, &r.CreatedAt, &resolvedAt); err != nil {
			return nil, err
		}
		r.State = state
		r.ConnectionPath = ConnectionPath(path)
		r.ResolvedAt = resolvedAt
		requests = append(requests, r)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return requests, nil
}

// List returns userID's friends, oldest friendship first. Returns an empty (non-nil) slice, never
// an error, when userID has no friends.
func (s *Service) List(ctx context.Context, userID uuid.UUID) ([]Friend, error) {
	const query = `
		SELECT u.id, u.display_name, f.established_at
		FROM friendships f
		JOIN users u ON u.id = CASE WHEN f.user_a_id = $1 THEN f.user_b_id ELSE f.user_a_id END
		WHERE f.user_a_id = $1 OR f.user_b_id = $1
		ORDER BY f.established_at
	`
	rows, err := s.store.Pool().Query(ctx, query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	friendsList := []Friend{}
	for rows.Next() {
		var f Friend
		if err := rows.Scan(&f.UserID, &f.DisplayName, &f.EstablishedAt); err != nil {
			return nil, err
		}
		friendsList = append(friendsList, f)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return friendsList, nil
}

// Unfriend removes the single friendship row between userID and otherUserID. Returns
// ErrNotFriends if no such row exists.
func (s *Service) Unfriend(ctx context.Context, userID, otherUserID uuid.UUID) error {
	userA, userB := orderPair(userID, otherUserID)
	const query = `DELETE FROM friendships WHERE user_a_id = $1 AND user_b_id = $2`
	tag, err := s.store.Pool().Exec(ctx, query, userA, userB)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFriends
	}
	return nil
}

// AreFriends reports whether a and b have a friendship row. Symmetric: the argument order never
// changes the answer, since the pair is normalized into constraint order before querying.
func (s *Service) AreFriends(ctx context.Context, a, b uuid.UUID) (bool, error) {
	userA, userB := orderPair(a, b)
	const query = `SELECT EXISTS(SELECT 1 FROM friendships WHERE user_a_id = $1 AND user_b_id = $2)`
	var exists bool
	err := s.store.Pool().QueryRow(ctx, query, userA, userB).Scan(&exists)
	if err != nil {
		return false, err
	}
	return exists, nil
}

// orderPair returns (a, b) reordered so the first return value is the smaller by byte comparison
// of its 16 canonical bytes -- exactly how PostgreSQL's own uuid_cmp orders two uuid values, so a
// pair normalized here always satisfies friendships' CHECK (user_a_id < user_b_id) constraint
// regardless of which direction a request was sent in.
func orderPair(a, b uuid.UUID) (uuid.UUID, uuid.UUID) {
	for i := range a {
		if a[i] != b[i] {
			if a[i] < b[i] {
				return a, b
			}
			return b, a
		}
	}
	return a, b
}
