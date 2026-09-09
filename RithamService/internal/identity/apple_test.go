package identity

import (
	"context"
	"crypto"
	"crypto/rand"
	"crypto/rsa"
	"errors"
	"testing"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

// stubKeySource serves a fixed, in-memory key set -- no network access, no live call to Apple,
// per this task's acceptance criteria.
type stubKeySource struct {
	keys map[string]crypto.PublicKey
}

func (s stubKeySource) PublicKeys(ctx context.Context) (map[string]crypto.PublicKey, error) {
	return s.keys, nil
}

const (
	testKID              = "test-key-1"
	testAudience         = "com.ritham.app"
	testWrongAudience    = "com.other.app"
	testWrongIssuer      = "https://example.com"
	testSubject          = "001234.abcd5678.5678"
	testNonce            = "expected-nonce-value"
)

// mintToken builds and signs an RS256 identity token whose claims mirror what Apple's own
// identity tokens carry, with the given key, kid, issuer, audience, expiry and nonce.
func mintToken(t *testing.T, key *rsa.PrivateKey, kid, issuer, audience, subject string, issuedAt, expiresAt time.Time, nonce string) string {
	t.Helper()
	claims := jwt.MapClaims{
		"iss":            issuer,
		"aud":            audience,
		"sub":            subject,
		"iat":            jwt.NewNumericDate(issuedAt),
		"exp":            jwt.NewNumericDate(expiresAt),
		"email":          "user@example.com",
		"email_verified": "true",
	}
	if nonce != "" {
		claims["nonce"] = nonce
	}
	token := jwt.NewWithClaims(jwt.SigningMethodRS256, claims)
	token.Header["kid"] = kid
	signed, err := token.SignedString(key)
	if err != nil {
		t.Fatalf("signing test token: %v", err)
	}
	return signed
}

func mintUnsignedToken(t *testing.T, kid, issuer, audience, subject string, issuedAt, expiresAt time.Time) string {
	t.Helper()
	claims := jwt.MapClaims{
		"iss": issuer,
		"aud": audience,
		"sub": subject,
		"iat": jwt.NewNumericDate(issuedAt),
		"exp": jwt.NewNumericDate(expiresAt),
	}
	token := jwt.NewWithClaims(jwt.SigningMethodNone, claims)
	token.Header["kid"] = kid
	signed, err := token.SignedString(jwt.UnsafeAllowNoneSignatureType)
	if err != nil {
		t.Fatalf("signing unsigned test token: %v", err)
	}
	return signed
}

func mintHMACToken(t *testing.T, kid, issuer, audience, subject string, issuedAt, expiresAt time.Time) string {
	t.Helper()
	claims := jwt.MapClaims{
		"iss": issuer,
		"aud": audience,
		"sub": subject,
		"iat": jwt.NewNumericDate(issuedAt),
		"exp": jwt.NewNumericDate(expiresAt),
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	token.Header["kid"] = kid
	signed, err := token.SignedString([]byte("shared-secret-not-apple"))
	if err != nil {
		t.Fatalf("signing HMAC test token: %v", err)
	}
	return signed
}

func newTestRSAKey(t *testing.T) *rsa.PrivateKey {
	t.Helper()
	key, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		t.Fatalf("generating RSA key: %v", err)
	}
	return key
}

func TestVerifyIdentityToken_ValidTokenVerifiesAndYieldsSubject(t *testing.T) {
	key := newTestRSAKey(t)
	keys := stubKeySource{keys: map[string]crypto.PublicKey{testKID: &key.PublicKey}}
	now := time.Date(2026, 9, 9, 12, 0, 0, 0, time.UTC)
	token := mintToken(t, key, testKID, appleIssuer, testAudience, testSubject, now.Add(-time.Minute), now.Add(time.Hour), "")

	claims, err := VerifyIdentityToken(context.Background(), keys, token, testAudience, "", now)
	if err != nil {
		t.Fatalf("VerifyIdentityToken: unexpected error: %v", err)
	}
	if claims.Subject != testSubject {
		t.Errorf("claims.Subject = %q, want %q", claims.Subject, testSubject)
	}
	if claims.Audience != testAudience {
		t.Errorf("claims.Audience = %q, want %q", claims.Audience, testAudience)
	}
	if !claims.EmailVerified {
		t.Errorf("claims.EmailVerified = false, want true")
	}
}

func TestVerifyIdentityToken_UnknownKeyFailsWithInvalidSentinel(t *testing.T) {
	key := newTestRSAKey(t)
	// Key source knows about a different kid entirely -- simulates a token signed by a key not
	// present in Apple's published set.
	keys := stubKeySource{keys: map[string]crypto.PublicKey{"some-other-kid": &key.PublicKey}}
	now := time.Date(2026, 9, 9, 12, 0, 0, 0, time.UTC)
	token := mintToken(t, key, testKID, appleIssuer, testAudience, testSubject, now.Add(-time.Minute), now.Add(time.Hour), "")

	_, err := VerifyIdentityToken(context.Background(), keys, token, testAudience, "", now)
	if !errors.Is(err, ErrTokenInvalid) {
		t.Fatalf("VerifyIdentityToken: got error %v, want ErrTokenInvalid", err)
	}
}

func TestVerifyIdentityToken_WrongAudienceFailsAndReturnsNoClaims(t *testing.T) {
	key := newTestRSAKey(t)
	keys := stubKeySource{keys: map[string]crypto.PublicKey{testKID: &key.PublicKey}}
	now := time.Date(2026, 9, 9, 12, 0, 0, 0, time.UTC)
	token := mintToken(t, key, testKID, appleIssuer, testWrongAudience, testSubject, now.Add(-time.Minute), now.Add(time.Hour), "")

	claims, err := VerifyIdentityToken(context.Background(), keys, token, testAudience, "", now)
	if !errors.Is(err, ErrTokenAudience) {
		t.Fatalf("VerifyIdentityToken: got error %v, want ErrTokenAudience", err)
	}
	if claims != (AppleClaims{}) {
		t.Errorf("VerifyIdentityToken: got non-zero claims %+v on audience failure, want zero value", claims)
	}
}

func TestVerifyIdentityToken_WrongIssuerFailsWithIssuerSentinel(t *testing.T) {
	key := newTestRSAKey(t)
	keys := stubKeySource{keys: map[string]crypto.PublicKey{testKID: &key.PublicKey}}
	now := time.Date(2026, 9, 9, 12, 0, 0, 0, time.UTC)
	token := mintToken(t, key, testKID, testWrongIssuer, testAudience, testSubject, now.Add(-time.Minute), now.Add(time.Hour), "")

	_, err := VerifyIdentityToken(context.Background(), keys, token, testAudience, "", now)
	if !errors.Is(err, ErrTokenIssuer) {
		t.Fatalf("VerifyIdentityToken: got error %v, want ErrTokenIssuer", err)
	}
}

func TestVerifyIdentityToken_ExpiredTokenFailsAgainstInjectedClock(t *testing.T) {
	key := newTestRSAKey(t)
	keys := stubKeySource{keys: map[string]crypto.PublicKey{testKID: &key.PublicKey}}
	now := time.Date(2026, 9, 9, 12, 0, 0, 0, time.UTC)
	// Minted as already-expired relative to the injected clock, not wall time.
	token := mintToken(t, key, testKID, appleIssuer, testAudience, testSubject, now.Add(-2*time.Hour), now.Add(-time.Hour), "")

	_, err := VerifyIdentityToken(context.Background(), keys, token, testAudience, "", now)
	if !errors.Is(err, ErrTokenExpired) {
		t.Fatalf("VerifyIdentityToken: got error %v, want ErrTokenExpired", err)
	}
}

func TestVerifyIdentityToken_NoneAlgorithmIsRejected(t *testing.T) {
	key := newTestRSAKey(t)
	keys := stubKeySource{keys: map[string]crypto.PublicKey{testKID: &key.PublicKey}}
	now := time.Date(2026, 9, 9, 12, 0, 0, 0, time.UTC)
	token := mintUnsignedToken(t, testKID, appleIssuer, testAudience, testSubject, now.Add(-time.Minute), now.Add(time.Hour))

	_, err := VerifyIdentityToken(context.Background(), keys, token, testAudience, "", now)
	if !errors.Is(err, ErrTokenInvalid) {
		t.Fatalf("VerifyIdentityToken: got error %v, want ErrTokenInvalid for none-alg token", err)
	}
}

func TestVerifyIdentityToken_SymmetricAlgorithmIsRejected(t *testing.T) {
	key := newTestRSAKey(t)
	keys := stubKeySource{keys: map[string]crypto.PublicKey{testKID: &key.PublicKey}}
	now := time.Date(2026, 9, 9, 12, 0, 0, 0, time.UTC)
	token := mintHMACToken(t, testKID, appleIssuer, testAudience, testSubject, now.Add(-time.Minute), now.Add(time.Hour))

	_, err := VerifyIdentityToken(context.Background(), keys, token, testAudience, "", now)
	if !errors.Is(err, ErrTokenInvalid) {
		t.Fatalf("VerifyIdentityToken: got error %v, want ErrTokenInvalid for HMAC-alg token", err)
	}
}

func TestVerifyIdentityToken_MismatchedNonceFailsWithNonceSentinel(t *testing.T) {
	key := newTestRSAKey(t)
	keys := stubKeySource{keys: map[string]crypto.PublicKey{testKID: &key.PublicKey}}
	now := time.Date(2026, 9, 9, 12, 0, 0, 0, time.UTC)
	token := mintToken(t, key, testKID, appleIssuer, testAudience, testSubject, now.Add(-time.Minute), now.Add(time.Hour), "a-different-nonce")

	_, err := VerifyIdentityToken(context.Background(), keys, token, testAudience, testNonce, now)
	if !errors.Is(err, ErrTokenNonce) {
		t.Fatalf("VerifyIdentityToken: got error %v, want ErrTokenNonce", err)
	}
}

func TestVerifyIdentityToken_MatchingNonceSucceeds(t *testing.T) {
	key := newTestRSAKey(t)
	keys := stubKeySource{keys: map[string]crypto.PublicKey{testKID: &key.PublicKey}}
	now := time.Date(2026, 9, 9, 12, 0, 0, 0, time.UTC)
	token := mintToken(t, key, testKID, appleIssuer, testAudience, testSubject, now.Add(-time.Minute), now.Add(time.Hour), testNonce)

	claims, err := VerifyIdentityToken(context.Background(), keys, token, testAudience, testNonce, now)
	if err != nil {
		t.Fatalf("VerifyIdentityToken: unexpected error: %v", err)
	}
	if claims.Subject != testSubject {
		t.Errorf("claims.Subject = %q, want %q", claims.Subject, testSubject)
	}
}
