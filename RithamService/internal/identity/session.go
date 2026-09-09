package identity

import (
	"context"
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

// SignInResult is what a successful Sign in with Apple call returns.
type SignInResult struct {
	UserID       uuid.UUID
	DisplayName  string
	SessionToken string
	ExpiresAt    time.Time
}

// SignInWithApple is stubbed pending Task 2's implementation.
func (s *Service) SignInWithApple(ctx context.Context, rawToken, nonce, displayName string) (SignInResult, error) {
	return SignInResult{}, ErrSessionInvalid
}

// IssueSession is stubbed pending Task 2's implementation.
func (s *Service) IssueSession(ctx context.Context, userID uuid.UUID) (string, time.Time, error) {
	return "", time.Time{}, ErrSessionInvalid
}

// AuthenticateBearer is stubbed pending Task 2's implementation.
func (s *Service) AuthenticateBearer(ctx context.Context, token string) (uuid.UUID, error) {
	return uuid.UUID{}, ErrSessionInvalid
}

// RevokeSession is stubbed pending Task 2's implementation.
func (s *Service) RevokeSession(ctx context.Context, token string) error {
	return ErrSessionInvalid
}

// SetDisplayName is stubbed pending Task 2's implementation.
func (s *Service) SetDisplayName(ctx context.Context, userID uuid.UUID, name string) error {
	return ErrDisplayNameTooLong
}
