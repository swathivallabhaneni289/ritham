package identity

import (
	"context"
	"crypto"
	"crypto/rsa"
	"encoding/base64"
	"errors"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/swathivallabhaneni289/ritham/RithamService/internal/store"
)

// testHarness wires a Service against a real, live database (RITHAM_DATABASE_URL) and a
// controllable clock/key pair, following plan 04.1-01's store_test.go convention: skip loudly,
// with an actionable message, when no database is configured, rather than silently passing
// nothing.
type testHarness struct {
	svc   *Service
	store *store.Store
	key   *rsa.PrivateKey
	clock time.Time
}

func (h *testHarness) now() time.Time { return h.clock }

func (h *testHarness) advance(d time.Duration) { h.clock = h.clock.Add(d) }

// mintValidToken mints a token that verifies successfully against h's key and clock at the
// moment of the call.
func (h *testHarness) mintValidToken(t *testing.T, subject, nonce string) string {
	t.Helper()
	return mintToken(t, h.key, testKID, appleIssuer, testAudience, subject, h.clock.Add(-time.Minute), h.clock.Add(time.Hour), nonce)
}

func newTestHarness(t *testing.T) *testHarness {
	t.Helper()
	databaseURL := store.DatabaseURLFromEnv()
	if databaseURL == "" {
		t.Skip("RITHAM_DATABASE_URL is unset -- start a database (see " +
			"docker-compose.dev.yml, or a native Postgres per 04.1-01-SUMMARY.md) and run this " +
			"test with `RITHAM_DATABASE_URL=postgres://$(whoami)@localhost:5432/ritham_dev" +
			"?sslmode=disable go test ./internal/identity/...`")
	}

	ctx := context.Background()
	st, err := store.New(ctx, databaseURL)
	if err != nil {
		t.Fatalf("store.New: unexpected error: %v", err)
	}
	t.Cleanup(st.Close)

	key := newTestRSAKey(t)
	h := &testHarness{store: st, key: key, clock: time.Date(2026, 9, 9, 12, 0, 0, 0, time.UTC)}
	keys := stubKeySource{keys: map[string]crypto.PublicKey{testKID: &key.PublicKey}}
	h.svc = New(st, keys, testAudience, h.now)
	return h
}

// uniqueSubject returns an Apple-subject-shaped string that is unique per test run, so the
// unique/not-null apple_subject column never collides across repeated runs against the same
// long-lived dev database (a fixed literal subject would pass on run 1 and then silently corrupt
// the "first sign-in inserts a new row" assertion on run 2).
func uniqueSubject(t *testing.T) string {
	t.Helper()
	return "subject." + uuid.NewString()
}

// cleanupUser deletes the sessions and users rows this test created, so repeated runs never
// accumulate rows in the shared dev database.
func cleanupUser(t *testing.T, h *testHarness, userID uuid.UUID) {
	t.Helper()
	t.Cleanup(func() {
		ctx := context.Background()
		_, _ = h.store.Pool().Exec(ctx, "DELETE FROM sessions WHERE user_id = $1", userID)
		_, _ = h.store.Pool().Exec(ctx, "DELETE FROM users WHERE id = $1", userID)
	})
}

func TestSignInWithApple_FirstSignInInsertsNewUser(t *testing.T) {
	h := newTestHarness(t)
	subject := uniqueSubject(t)
	token := h.mintValidToken(t, subject, "")

	result, err := h.svc.SignInWithApple(context.Background(), token, "", "")
	if err != nil {
		t.Fatalf("SignInWithApple: unexpected error: %v", err)
	}
	cleanupUser(t, h, result.UserID)

	if result.UserID == uuid.Nil {
		t.Errorf("SignInWithApple: got zero-value UserID, want a real id")
	}
	if result.SessionToken == "" {
		t.Errorf("SignInWithApple: got empty SessionToken")
	}
}

func TestSignInWithApple_SecondSignInReturnsSameUserID(t *testing.T) {
	h := newTestHarness(t)
	subject := uniqueSubject(t)

	first, err := h.svc.SignInWithApple(context.Background(), h.mintValidToken(t, subject, ""), "", "")
	if err != nil {
		t.Fatalf("SignInWithApple (first): unexpected error: %v", err)
	}
	cleanupUser(t, h, first.UserID)

	second, err := h.svc.SignInWithApple(context.Background(), h.mintValidToken(t, subject, ""), "", "")
	if err != nil {
		t.Fatalf("SignInWithApple (second): unexpected error: %v", err)
	}

	if first.UserID != second.UserID {
		t.Errorf("SignInWithApple: second sign-in returned UserID %s, want %s (cross-device continuity)", second.UserID, first.UserID)
	}

	var count int
	err = h.store.Pool().QueryRow(context.Background(),
		"SELECT COUNT(*) FROM users WHERE apple_subject = $1", subject).Scan(&count)
	if err != nil {
		t.Fatalf("counting users rows: %v", err)
	}
	if count != 1 {
		t.Errorf("got %d users rows for one apple_subject, want exactly 1 (no duplicate insert)", count)
	}
}

func TestSignInWithApple_DifferentSubjectsNeverCollide(t *testing.T) {
	h := newTestHarness(t)
	subjectA := uniqueSubject(t)
	subjectB := uniqueSubject(t)

	resultA, err := h.svc.SignInWithApple(context.Background(), h.mintValidToken(t, subjectA, ""), "", "")
	if err != nil {
		t.Fatalf("SignInWithApple (A): unexpected error: %v", err)
	}
	cleanupUser(t, h, resultA.UserID)

	resultB, err := h.svc.SignInWithApple(context.Background(), h.mintValidToken(t, subjectB, ""), "", "")
	if err != nil {
		t.Fatalf("SignInWithApple (B): unexpected error: %v", err)
	}
	cleanupUser(t, h, resultB.UserID)

	if resultA.UserID == resultB.UserID {
		t.Errorf("two different Apple subjects resolved to the same user id %s", resultA.UserID)
	}
}

func TestIssueSession_TokenHasAtLeast32BytesOfEntropyAndIsBase64URL(t *testing.T) {
	h := newTestHarness(t)
	subject := uniqueSubject(t)
	signIn, err := h.svc.SignInWithApple(context.Background(), h.mintValidToken(t, subject, ""), "", "")
	if err != nil {
		t.Fatalf("SignInWithApple: unexpected error: %v", err)
	}
	cleanupUser(t, h, signIn.UserID)

	token, expiresAt, err := h.svc.IssueSession(context.Background(), signIn.UserID)
	if err != nil {
		t.Fatalf("IssueSession: unexpected error: %v", err)
	}
	if expiresAt.Before(h.now()) {
		t.Errorf("IssueSession: expiresAt %v is not in the future relative to %v", expiresAt, h.now())
	}

	decoded, err := base64.RawURLEncoding.DecodeString(token)
	if err != nil {
		t.Fatalf("session token %q is not valid base64url: %v", token, err)
	}
	if len(decoded) < 32 {
		t.Errorf("session token has %d bytes of entropy, want at least 32", len(decoded))
	}
}

func TestIssueSession_PersistsOnlyAHashedDigestNeverThePlaintext(t *testing.T) {
	h := newTestHarness(t)
	subject := uniqueSubject(t)
	signIn, err := h.svc.SignInWithApple(context.Background(), h.mintValidToken(t, subject, ""), "", "")
	if err != nil {
		t.Fatalf("SignInWithApple: unexpected error: %v", err)
	}
	cleanupUser(t, h, signIn.UserID)

	token, _, err := h.svc.IssueSession(context.Background(), signIn.UserID)
	if err != nil {
		t.Fatalf("IssueSession: unexpected error: %v", err)
	}

	var (
		id, userID           uuid.UUID
		tokenSHA256          []byte
		issuedAt, expiresAt  time.Time
	)
	err = h.store.Pool().QueryRow(context.Background(),
		"SELECT id, user_id, token_sha256, issued_at, expires_at FROM sessions WHERE user_id = $1",
		signIn.UserID,
	).Scan(&id, &userID, &tokenSHA256, &issuedAt, &expiresAt)
	if err != nil {
		t.Fatalf("querying sessions row: %v", err)
	}

	if len(tokenSHA256) != 32 {
		t.Errorf("token_sha256 has %d bytes, want exactly 32 (a SHA-256 digest)", len(tokenSHA256))
	}

	textColumns := []string{id.String(), userID.String(), issuedAt.String(), expiresAt.String()}
	for _, col := range textColumns {
		if strings.Contains(col, token) {
			t.Errorf("plaintext session token found in a persisted text column: %q", col)
		}
	}
	if string(tokenSHA256) == token {
		t.Errorf("token_sha256 column literally equals the plaintext token")
	}
}

func TestAuthenticateBearer_ValidUnexpiredTokenYieldsUserID(t *testing.T) {
	h := newTestHarness(t)
	subject := uniqueSubject(t)
	signIn, err := h.svc.SignInWithApple(context.Background(), h.mintValidToken(t, subject, ""), "", "")
	if err != nil {
		t.Fatalf("SignInWithApple: unexpected error: %v", err)
	}
	cleanupUser(t, h, signIn.UserID)

	userID, err := h.svc.AuthenticateBearer(context.Background(), signIn.SessionToken)
	if err != nil {
		t.Fatalf("AuthenticateBearer: unexpected error: %v", err)
	}
	if userID != signIn.UserID {
		t.Errorf("AuthenticateBearer: got user id %s, want %s", userID, signIn.UserID)
	}
}

func TestAuthenticateBearer_RevokedTokenFailsOnNextCall(t *testing.T) {
	h := newTestHarness(t)
	subject := uniqueSubject(t)
	signIn, err := h.svc.SignInWithApple(context.Background(), h.mintValidToken(t, subject, ""), "", "")
	if err != nil {
		t.Fatalf("SignInWithApple: unexpected error: %v", err)
	}
	cleanupUser(t, h, signIn.UserID)

	if err := h.svc.RevokeSession(context.Background(), signIn.SessionToken); err != nil {
		t.Fatalf("RevokeSession: unexpected error: %v", err)
	}

	_, err = h.svc.AuthenticateBearer(context.Background(), signIn.SessionToken)
	if !errors.Is(err, ErrSessionInvalid) {
		t.Fatalf("AuthenticateBearer after revoke: got error %v, want ErrSessionInvalid", err)
	}
}

func TestAuthenticateBearer_ExpiredTokenFailsAgainstInjectedClock(t *testing.T) {
	h := newTestHarness(t)
	subject := uniqueSubject(t)
	signIn, err := h.svc.SignInWithApple(context.Background(), h.mintValidToken(t, subject, ""), "", "")
	if err != nil {
		t.Fatalf("SignInWithApple: unexpected error: %v", err)
	}
	cleanupUser(t, h, signIn.UserID)

	h.advance(sessionTTL + time.Hour)

	_, err = h.svc.AuthenticateBearer(context.Background(), signIn.SessionToken)
	if !errors.Is(err, ErrSessionInvalid) {
		t.Fatalf("AuthenticateBearer after expiry: got error %v, want ErrSessionInvalid", err)
	}
}

func TestAuthenticateBearer_NeverIssuedTokenFailsWithSameSentinelAsRevoked(t *testing.T) {
	h := newTestHarness(t)
	_, err := h.svc.AuthenticateBearer(context.Background(), "this-token-was-never-issued-by-anyone")
	if !errors.Is(err, ErrSessionInvalid) {
		t.Fatalf("AuthenticateBearer for an unissued token: got error %v, want ErrSessionInvalid (indistinguishable from revoked)", err)
	}
}

func TestSetDisplayName_RejectsOverLongNameRatherThanTruncating(t *testing.T) {
	h := newTestHarness(t)
	subject := uniqueSubject(t)
	signIn, err := h.svc.SignInWithApple(context.Background(), h.mintValidToken(t, subject, ""), "", "Original Name")
	if err != nil {
		t.Fatalf("SignInWithApple: unexpected error: %v", err)
	}
	cleanupUser(t, h, signIn.UserID)

	tooLong := strings.Repeat("a", displayNameMaxLen+1)
	err = h.svc.SetDisplayName(context.Background(), signIn.UserID, tooLong)
	if err == nil {
		t.Fatalf("SetDisplayName: got nil error for a %d-char name, want rejection", len(tooLong))
	}

	var stored string
	scanErr := h.store.Pool().QueryRow(context.Background(),
		"SELECT display_name FROM users WHERE id = $1", signIn.UserID).Scan(&stored)
	if scanErr != nil {
		t.Fatalf("querying stored display_name: %v", scanErr)
	}
	if stored != "Original Name" {
		t.Errorf("stored display_name = %q after a rejected over-long update, want unchanged %q (never truncated)", stored, "Original Name")
	}
}
