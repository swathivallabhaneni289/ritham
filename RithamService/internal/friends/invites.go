package friends

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

// ErrInviteExpired is returned when the presented token's expiry window has already closed,
// evaluated against the Service's injected clock.
var ErrInviteExpired = errors.New("friends: invite has expired")

// ErrInviteConsumed is returned when the presented token has already been redeemed once.
var ErrInviteConsumed = errors.New("friends: invite has already been used")

// ErrInviteUnknown is returned when the presented token does not match any issued invite. At the
// HTTP layer this must be indistinguishable from ErrInviteConsumed (T-04.1-31) -- callers that
// need that guarantee map both to the same status and message, not this package.
var ErrInviteUnknown = errors.New("friends: invite token is unknown")

// ErrInviteSelfRedeem is returned when the issuer attempts to redeem their own invite.
var ErrInviteSelfRedeem = errors.New("friends: cannot redeem your own invite")

// inviteTTL is how long a created invite remains redeemable. inviteTokenBytes is the raw entropy
// of an issued invite token before base64url encoding, matching identity/session.go's
// sessionTokenBytes discipline.
const (
	inviteTTL        = 7 * 24 * time.Hour
	inviteTokenBytes = 32
)

// Invite is what a successful CreateInvite call returns. Token is the plaintext bearer value,
// returned exactly once -- only its SHA-256 digest is ever persisted.
type Invite struct {
	Token     string
	ExpiresAt time.Time
}

// CreateInvite generates a new opaque, high-entropy invite token via crypto/rand and persists
// only its SHA-256 digest. userID is the invite's issuer.
func (s *Service) CreateInvite(ctx context.Context, userID uuid.UUID) (Invite, error) {
	raw := make([]byte, inviteTokenBytes)
	if _, err := rand.Read(raw); err != nil {
		return Invite{}, err
	}
	token := base64.RawURLEncoding.EncodeToString(raw)
	digest := hashInviteToken(token)
	expiresAt := s.now().Add(inviteTTL)

	const query = `
		INSERT INTO invite_tokens (token_sha256, issuer_user_id, expires_at)
		VALUES ($1, $2, $3)
	`
	if _, err := s.store.Pool().Exec(ctx, query, digest, userID, expiresAt); err != nil {
		return Invite{}, err
	}

	return Invite{Token: token, ExpiresAt: expiresAt}, nil
}

// hashInviteToken is the sole writer of invite_tokens.token_sha256 -- SHA-256 is the whole
// hashing surface here, mirroring identity/session.go's hashToken.
func hashInviteToken(token string) []byte {
	sum := sha256.Sum256([]byte(token))
	return sum[:]
}

// RedeemInvite atomically consumes token and, on success, creates a friend request from the
// invite's issuer to redeemerUserID -- both steps in one transaction, so two concurrent
// redemptions of the same token can never both succeed (docs/group-events.md §1's "links die"
// requirement, T-04.1-29). The conditional UPDATE's WHERE clause (consumed_at IS NULL AND
// expires_at > now) is the single enforcement point for both the single-use and the
// window-expiry rules -- there is no separate pre-check a second, racing caller could slip past.
func (s *Service) RedeemInvite(ctx context.Context, redeemerUserID uuid.UUID, token string) (Request, error) {
	digest := hashInviteToken(token)
	now := s.now()

	tx, err := s.store.Pool().Begin(ctx)
	if err != nil {
		return Request{}, err
	}
	defer tx.Rollback(ctx)

	const consumeQuery = `
		UPDATE invite_tokens
		SET consumed_at = $1, consumed_by_user_id = $2
		WHERE token_sha256 = $3 AND consumed_at IS NULL AND expires_at > $1
		RETURNING issuer_user_id
	`
	var issuerUserID uuid.UUID
	err = tx.QueryRow(ctx, consumeQuery, now, redeemerUserID, digest).Scan(&issuerUserID)
	if err != nil {
		if !errors.Is(err, pgx.ErrNoRows) {
			return Request{}, err
		}
		// The conditional UPDATE matched no row: read the token's actual state (inside this same
		// transaction, so it sees a consistent snapshot) to report which of the three reasons
		// applies. This lookup does not change which concurrent redeemer "won" -- that was
		// already decided by the UPDATE above, before this branch runs.
		return Request{}, classifyInviteFailure(ctx, tx, digest, now)
	}

	if issuerUserID == redeemerUserID {
		// tx is rolled back via the deferred call above (Commit is never reached), so this
		// consume attempt never takes effect -- a self-redemption attempt does not burn the
		// invite for its eventual, legitimate redeemer.
		return Request{}, ErrInviteSelfRedeem
	}

	req, err := insertFriendRequest(ctx, tx, issuerUserID, redeemerUserID, PathInviteLink, now)
	if err != nil {
		return Request{}, err
	}

	if err := tx.Commit(ctx); err != nil {
		return Request{}, err
	}

	return req, nil
}

// classifyInviteFailure determines why the conditional consume UPDATE in RedeemInvite affected no
// row: unknown token, already consumed, or expired -- checked in that priority order since a
// consumed row is also, incidentally, likely past its window, and "already used" is the more
// specific and useful of the two for the issuer to know.
func classifyInviteFailure(ctx context.Context, tx pgx.Tx, digest []byte, now time.Time) error {
	const query = `SELECT expires_at, consumed_at FROM invite_tokens WHERE token_sha256 = $1`
	var (
		expiresAt  time.Time
		consumedAt *time.Time
	)
	err := tx.QueryRow(ctx, query, digest).Scan(&expiresAt, &consumedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return ErrInviteUnknown
		}
		return err
	}
	if consumedAt != nil {
		return ErrInviteConsumed
	}
	if !expiresAt.After(now) {
		return ErrInviteExpired
	}
	// The row exists, is unconsumed, and is unexpired, yet the UPDATE still matched nothing --
	// not reachable under READ COMMITTED's row-locking semantics for this statement shape, but
	// fails safe (rather than crashing on a doubly-nil-checked case) if it ever is.
	return ErrInviteUnknown
}
