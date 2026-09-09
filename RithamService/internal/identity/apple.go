package identity

import (
	"context"
	"crypto"
	"errors"
	"time"
)

// appleIssuer is the only "iss" claim value VerifyIdentityToken ever accepts.
const appleIssuer = "https://appleid.apple.com"

// Sentinel errors returned by VerifyIdentityToken for each independently distinguishable
// verification failure. httpapi maps each to an HTTP status via errors.Is, matching
// internal/plan's statusForGenerateError convention -- never a string comparison.
var (
	ErrTokenInvalid  = errors.New("identity: apple identity token is invalid")
	ErrTokenAudience = errors.New("identity: apple identity token has an unexpected audience")
	ErrTokenIssuer   = errors.New("identity: apple identity token has an unexpected issuer")
	ErrTokenExpired  = errors.New("identity: apple identity token is expired")
	ErrTokenNonce    = errors.New("identity: apple identity token nonce does not match")
)

// AppleClaims is the subset of an Apple identity token's claims this service reads. Only the
// verified subject, email, and validity window survive VerifyIdentityToken -- no other claim
// Apple's token carries is exposed.
type AppleClaims struct {
	Subject       string
	Email         string
	EmailVerified bool
	Audience      string
	IssuedAt      time.Time
	ExpiresAt     time.Time
}

// AppleKeySource supplies Apple's published signing keys, keyed by key id (kid).
type AppleKeySource interface {
	PublicKeys(ctx context.Context) (map[string]crypto.PublicKey, error)
}

// VerifyIdentityToken is stubbed pending Task 1's implementation.
func VerifyIdentityToken(ctx context.Context, keys AppleKeySource, rawToken, expectedAudience, expectedNonce string, now time.Time) (AppleClaims, error) {
	return AppleClaims{}, ErrTokenInvalid
}
