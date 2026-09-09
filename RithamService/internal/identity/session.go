package identity

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"errors"
	"time"

	"github.com/google/uuid"
)

// ErrSessionInvalid is returned by AuthenticateBearer for every failure mode -- unissued,
// expired, and revoked all map to this one sentinel, so a caller cannot distinguish which
// condition failed (T-04.1-12).
var ErrSessionInvalid = errors.New("identity: session token is invalid")

// ErrDisplayNameTooLong is returned when a display name exceeds displayNameMaxLen. Names are
// rejected, never truncated.
var ErrDisplayNameTooLong = errors.New("identity: display name exceeds maximum length")

// sessionTokenBytes is the raw entropy of an issued session token before base64url encoding --
// at least 32 bytes, per this package's own behavior contract.
const sessionTokenBytes = 32

// SignInResult is what a successful Sign in with Apple call returns.
type SignInResult struct {
	UserID       uuid.UUID
	DisplayName  string
	SessionToken string
	ExpiresAt    time.Time
}

// SignInWithApple verifies rawToken via Task 1's VerifyIdentityToken, resolves (or creates) the
// Ritham user for the token's Apple subject, optionally records displayName on first sign-in
// only, and issues a fresh session. The same Apple subject always resolves to the same user id --
// the whole ACCOUNT-01 cross-device-continuity mechanism.
func (s *Service) SignInWithApple(ctx context.Context, rawToken, nonce, displayName string) (SignInResult, error) {
	if err := validateDisplayName(displayName); err != nil {
		return SignInResult{}, err
	}

	claims, err := VerifyIdentityToken(ctx, s.keys, rawToken, s.audience, nonce, s.now())
	if err != nil {
		return SignInResult{}, err
	}

	userID, resolvedName, err := s.upsertUser(ctx, claims.Subject, displayName)
	if err != nil {
		return SignInResult{}, err
	}

	token, expiresAt, err := s.IssueSession(ctx, userID)
	if err != nil {
		return SignInResult{}, err
	}

	return SignInResult{
		UserID:       userID,
		DisplayName:  resolvedName,
		SessionToken: token,
		ExpiresAt:    expiresAt,
	}, nil
}

// upsertUser inserts a new users row for appleSubject, or -- on a second sign-in with the same
// subject -- returns the existing row's id unchanged, per ACCOUNT-01's cross-device continuity
// guarantee. displayName is stored only when supplied and the existing stored value is still
// empty; an existing non-empty display name is never overwritten by a later sign-in.
func (s *Service) upsertUser(ctx context.Context, appleSubject, displayName string) (uuid.UUID, string, error) {
	const query = `
		INSERT INTO users (id, apple_subject, display_name)
		VALUES ($1, $2, $3)
		ON CONFLICT (apple_subject) DO UPDATE
		SET display_name = CASE
			WHEN users.display_name = '' AND $3 <> '' THEN $3
			ELSE users.display_name
		END
		RETURNING id, display_name
	`
	var (
		userID uuid.UUID
		stored string
	)
	err := s.store.Pool().QueryRow(ctx, query, uuid.New(), appleSubject, displayName).Scan(&userID, &stored)
	if err != nil {
		return uuid.UUID{}, "", err
	}
	return userID, stored, nil
}

// IssueSession generates a new opaque, high-entropy bearer token from crypto/rand, persists only
// its SHA-256 digest (hashToken is the sole writer of sessions.token_sha256), and returns the
// plaintext token to the caller exactly once -- it is never stored, logged, or included in any
// error string anywhere in this package.
func (s *Service) IssueSession(ctx context.Context, userID uuid.UUID) (string, time.Time, error) {
	raw := make([]byte, sessionTokenBytes)
	if _, err := rand.Read(raw); err != nil {
		return "", time.Time{}, err
	}
	token := base64.RawURLEncoding.EncodeToString(raw)
	digest := hashToken(token)
	expiresAt := s.now().Add(sessionTTL)

	const query = `
		INSERT INTO sessions (id, user_id, token_sha256, expires_at)
		VALUES ($1, $2, $3, $4)
	`
	if _, err := s.store.Pool().Exec(ctx, query, uuid.New(), userID, digest, expiresAt); err != nil {
		return "", time.Time{}, err
	}

	return token, expiresAt, nil
}

// hashToken is the only writer of sessions.token_sha256 -- SHA-256 is the whole hashing surface
// here, per 04.1-RESEARCH.md's Don't Hand-Roll table.
func hashToken(token string) []byte {
	sum := sha256.Sum256([]byte(token))
	return sum[:]
}

// AuthenticateBearer hashes the presented token and looks it up by digest, with the expiry and
// revocation predicates inside the SQL WHERE clause itself -- not a separate Go-side check --
// so an expired or revoked row can never be resurrected by a later code path that forgets to
// test it. Every failure (unissued, revoked, or expired) returns the identical ErrSessionInvalid,
// so a caller cannot distinguish which condition failed.
func (s *Service) AuthenticateBearer(ctx context.Context, token string) (uuid.UUID, error) {
	digest := hashToken(token)

	const query = `
		SELECT user_id FROM sessions
		WHERE token_sha256 = $1 AND revoked_at IS NULL AND expires_at > $2
	`
	var userID uuid.UUID
	err := s.store.Pool().QueryRow(ctx, query, digest, s.now()).Scan(&userID)
	if err != nil {
		return uuid.UUID{}, ErrSessionInvalid
	}
	return userID, nil
}

// RevokeSession stamps revoked_at on the session matching token's digest. Revocation takes
// effect immediately: AuthenticateBearer's own WHERE clause excludes any row with a non-null
// revoked_at, so the very next authentication attempt against this token fails.
func (s *Service) RevokeSession(ctx context.Context, token string) error {
	digest := hashToken(token)
	const query = `
		UPDATE sessions SET revoked_at = $1
		WHERE token_sha256 = $2 AND revoked_at IS NULL
	`
	_, err := s.store.Pool().Exec(ctx, query, s.now(), digest)
	return err
}

// SetDisplayName rejects a name longer than displayNameMaxLen rather than truncating it.
func (s *Service) SetDisplayName(ctx context.Context, userID uuid.UUID, name string) error {
	if err := validateDisplayName(name); err != nil {
		return err
	}
	const query = `UPDATE users SET display_name = $1 WHERE id = $2`
	_, err := s.store.Pool().Exec(ctx, query, name, userID)
	return err
}

// User returns userID's current display name. This backs the GET /v1/identity/me route: the
// middleware already proved userID is a valid, unexpired, unrevoked session's owner, so this is
// a plain read with no further authorization check.
func (s *Service) User(ctx context.Context, userID uuid.UUID) (string, error) {
	const query = `SELECT display_name FROM users WHERE id = $1`
	var displayName string
	if err := s.store.Pool().QueryRow(ctx, query, userID).Scan(&displayName); err != nil {
		return "", err
	}
	return displayName, nil
}

// validateDisplayName enforces displayNameMaxLen. An empty name is always valid (it means "no
// display name supplied"); SignInWithApple and SetDisplayName both route through this so the
// bound is enforced in exactly one place.
func validateDisplayName(name string) error {
	if len(name) > displayNameMaxLen {
		return ErrDisplayNameTooLong
	}
	return nil
}
