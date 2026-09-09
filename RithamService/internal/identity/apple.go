package identity

import (
	"context"
	"crypto"
	"crypto/rsa"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"math/big"
	"net/http"
	"sync"
	"time"

	"github.com/golang-jwt/jwt/v5"
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

// keyRefresher is an optional capability a AppleKeySource implementation (NewAppleJWKS's
// concrete type) can satisfy to force a re-fetch when a presented kid is not in the current
// cache. VerifyIdentityToken uses this opportunistically -- a stub AppleKeySource used in tests
// need not implement it, and simply fails closed with ErrTokenInvalid on an unknown kid instead.
type keyRefresher interface {
	Refresh(ctx context.Context) (map[string]crypto.PublicKey, error)
}

// VerifyIdentityToken verifies rawToken's signature against a key in keys, then checks issuer,
// audience, expiry (against the injected now, never wall time), and -- when expectedNonce is
// non-empty -- the token's nonce claim, in that order. Each failure returns its own sentinel and
// a zero AppleClaims; only a token that passes every check yields real claims.
//
// The parser is constructed with an explicit asymmetric-algorithm allowlist (RS256 only) so a
// "none"-algorithm or HMAC-signed token is rejected by the parser itself, before any claim is
// even read -- never by a later check that a future edit could accidentally skip. Claims
// validation is intentionally disabled on the parser (WithoutClaimsValidation) so this function,
// not the library's own time.Now()-based default, is the single place expiry is evaluated --
// otherwise the injected clock behavior this package requires would be structurally impossible.
func VerifyIdentityToken(ctx context.Context, keys AppleKeySource, rawToken, expectedAudience, expectedNonce string, now time.Time) (AppleClaims, error) {
	keySet, err := keys.PublicKeys(ctx)
	if err != nil {
		return AppleClaims{}, ErrTokenInvalid
	}

	parser := jwt.NewParser(
		jwt.WithValidMethods([]string{jwt.SigningMethodRS256.Alg()}),
		jwt.WithoutClaimsValidation(),
	)

	var rawClaims jwt.MapClaims
	_, err = parser.ParseWithClaims(rawToken, &rawClaims, func(t *jwt.Token) (interface{}, error) {
		kid, ok := t.Header["kid"].(string)
		if !ok {
			return nil, ErrTokenInvalid
		}
		if key, ok := keySet[kid]; ok {
			return key, nil
		}
		if refresher, ok := keys.(keyRefresher); ok {
			if refreshed, rerr := refresher.Refresh(ctx); rerr == nil {
				if key, ok := refreshed[kid]; ok {
					return key, nil
				}
			}
		}
		return nil, ErrTokenInvalid
	})
	if err != nil {
		return AppleClaims{}, ErrTokenInvalid
	}

	issuer, _ := rawClaims.GetIssuer()
	if issuer != appleIssuer {
		return AppleClaims{}, ErrTokenIssuer
	}

	audienceList, _ := rawClaims.GetAudience()
	if !containsAudience(audienceList, expectedAudience) {
		return AppleClaims{}, ErrTokenAudience
	}

	expiresAt, _ := rawClaims.GetExpirationTime()
	if expiresAt == nil || !now.Before(expiresAt.Time) {
		return AppleClaims{}, ErrTokenExpired
	}

	if expectedNonce != "" {
		nonce, _ := rawClaims["nonce"].(string)
		if nonce != expectedNonce {
			return AppleClaims{}, ErrTokenNonce
		}
	}

	subject, _ := rawClaims.GetSubject()

	var issuedAtTime time.Time
	if issuedAt, _ := rawClaims.GetIssuedAt(); issuedAt != nil {
		issuedAtTime = issuedAt.Time
	}

	audience := ""
	if len(audienceList) > 0 {
		audience = audienceList[0]
	}

	return AppleClaims{
		Subject:       subject,
		Email:         claimString(rawClaims, "email"),
		EmailVerified: claimBool(rawClaims, "email_verified"),
		Audience:      audience,
		IssuedAt:      issuedAtTime,
		ExpiresAt:     expiresAt.Time,
	}, nil
}

func containsAudience(audiences jwt.ClaimStrings, want string) bool {
	for _, a := range audiences {
		if a == want {
			return true
		}
	}
	return false
}

func claimString(claims jwt.MapClaims, key string) string {
	v, _ := claims[key].(string)
	return v
}

// claimBool reads a boolean-ish claim. Apple's identity token encodes "email_verified" as either
// a JSON boolean or a JSON string ("true"/"false") depending on the token type, so both shapes
// are accepted here rather than assuming one.
func claimBool(claims jwt.MapClaims, key string) bool {
	switch v := claims[key].(type) {
	case bool:
		return v
	case string:
		return v == "true"
	default:
		return false
	}
}

// --- Apple JWKS key source -------------------------------------------------------------------

const (
	appleJWKSURL     = "https://appleid.apple.com/auth/keys"
	jwksCacheTTL     = time.Hour
	jwksFetchTimeout = 5 * time.Second
	jwksMaxBodyBytes = 1 << 20 // 1 MiB -- Apple's key set is small; this is a generous ceiling.
)

// jwk is one entry in Apple's published JSON Web Key Set.
type jwk struct {
	Kty string `json:"kty"`
	Kid string `json:"kid"`
	Use string `json:"use"`
	Alg string `json:"alg"`
	N   string `json:"n"`
	E   string `json:"e"`
}

type jwkSet struct {
	Keys []jwk `json:"keys"`
}

// jwksKeySource fetches and caches Apple's published public keys. It is safe for concurrent use.
type jwksKeySource struct {
	client *http.Client
	url    string

	mu        sync.Mutex
	cached    map[string]crypto.PublicKey
	fetchedAt time.Time
}

// NewAppleJWKS returns an AppleKeySource backed by Apple's published JWKS endpoint, cached for
// jwksCacheTTL. client should have its own timeout configured by the caller in addition to this
// package's own per-request timeout; a nil client is replaced by one with jwksFetchTimeout.
func NewAppleJWKS(client *http.Client, url string) AppleKeySource {
	if client == nil {
		client = &http.Client{Timeout: jwksFetchTimeout}
	}
	if url == "" {
		url = appleJWKSURL
	}
	return &jwksKeySource{client: client, url: url}
}

// PublicKeys returns the cached key set, fetching it first if the cache is empty or has expired.
func (s *jwksKeySource) PublicKeys(ctx context.Context) (map[string]crypto.PublicKey, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if s.cached != nil && time.Since(s.fetchedAt) < jwksCacheTTL {
		return s.cached, nil
	}
	return s.refreshLocked(ctx)
}

// Refresh forces a re-fetch regardless of TTL, used by VerifyIdentityToken when a presented kid
// is not found in an otherwise-still-fresh cache (a key rotation between cache refreshes).
func (s *jwksKeySource) Refresh(ctx context.Context) (map[string]crypto.PublicKey, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.refreshLocked(ctx)
}

func (s *jwksKeySource) refreshLocked(ctx context.Context) (map[string]crypto.PublicKey, error) {
	keys, err := s.fetch(ctx)
	if err != nil {
		return nil, err
	}
	s.cached = keys
	s.fetchedAt = time.Now()
	return keys, nil
}

func (s *jwksKeySource) fetch(ctx context.Context) (map[string]crypto.PublicKey, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, s.url, nil)
	if err != nil {
		return nil, err
	}

	resp, err := s.client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("identity: fetching apple jwks: unexpected status %d", resp.StatusCode)
	}

	body, err := io.ReadAll(io.LimitReader(resp.Body, jwksMaxBodyBytes))
	if err != nil {
		return nil, err
	}

	var set jwkSet
	if err := json.Unmarshal(body, &set); err != nil {
		return nil, err
	}

	keys := make(map[string]crypto.PublicKey, len(set.Keys))
	for _, k := range set.Keys {
		if k.Kty != "RSA" {
			continue
		}
		pub, err := rsaPublicKeyFromJWK(k)
		if err != nil {
			continue
		}
		keys[k.Kid] = pub
	}
	return keys, nil
}

// rsaPublicKeyFromJWK decodes a JWK's base64url-encoded modulus (n) and exponent (e) into an
// *rsa.PublicKey.
func rsaPublicKeyFromJWK(k jwk) (*rsa.PublicKey, error) {
	nBytes, err := base64.RawURLEncoding.DecodeString(k.N)
	if err != nil {
		return nil, err
	}
	eBytes, err := base64.RawURLEncoding.DecodeString(k.E)
	if err != nil {
		return nil, err
	}

	n := new(big.Int).SetBytes(nBytes)
	e := new(big.Int).SetBytes(eBytes)

	return &rsa.PublicKey{N: n, E: int(e.Int64())}, nil
}
