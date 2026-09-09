package httpapi

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/google/uuid"
)

// stubAuthenticator lets middleware tests exercise RequireSession with no database, per this
// task's action ("Use a stub authenticator so this suite needs no database").
type stubAuthenticator struct {
	userID uuid.UUID
	err    error
}

func (s stubAuthenticator) AuthenticateBearer(ctx context.Context, token string) (uuid.UUID, error) {
	if s.err != nil {
		return uuid.UUID{}, s.err
	}
	return s.userID, nil
}

func TestRequireSession_NoHeaderReturns401(t *testing.T) {
	auth := stubAuthenticator{userID: uuid.New()}
	handler := RequireSession(auth, func(w http.ResponseWriter, r *http.Request) {
		t.Fatal("next handler must not be reached with no Authorization header")
	})

	req := httptest.NewRequest(http.MethodGet, "/v1/identity/me", nil)
	rec := httptest.NewRecorder()
	handler(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Errorf("got status %d, want 401", rec.Code)
	}
}

func TestRequireSession_MalformedSchemeReturns401(t *testing.T) {
	auth := stubAuthenticator{userID: uuid.New()}
	handler := RequireSession(auth, func(w http.ResponseWriter, r *http.Request) {
		t.Fatal("next handler must not be reached with a malformed Authorization scheme")
	})

	req := httptest.NewRequest(http.MethodGet, "/v1/identity/me", nil)
	req.Header.Set("Authorization", "Basic dXNlcjpwYXNz")
	rec := httptest.NewRecorder()
	handler(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Errorf("got status %d, want 401", rec.Code)
	}
}

func TestRequireSession_ValidTokenReachesHandlerWithUserIDInContext(t *testing.T) {
	wantUserID := uuid.New()
	auth := stubAuthenticator{userID: wantUserID}
	reached := false
	handler := RequireSession(auth, func(w http.ResponseWriter, r *http.Request) {
		reached = true
		gotUserID, ok := UserIDFromContext(r.Context())
		if !ok {
			t.Errorf("UserIDFromContext: ok = false, want true")
		}
		if gotUserID != wantUserID {
			t.Errorf("UserIDFromContext: got %s, want %s", gotUserID, wantUserID)
		}
		w.WriteHeader(http.StatusOK)
	})

	req := httptest.NewRequest(http.MethodGet, "/v1/identity/me", nil)
	req.Header.Set("Authorization", "Bearer some-valid-token")
	rec := httptest.NewRecorder()
	handler(rec, req)

	if !reached {
		t.Errorf("next handler was not reached for a valid token")
	}
	if rec.Code != http.StatusOK {
		t.Errorf("got status %d, want 200", rec.Code)
	}
}

func TestRequireSession_RevokedTokenReturns401(t *testing.T) {
	// A stub returning an error simulates identity.AuthenticateBearer's ErrSessionInvalid for a
	// revoked token -- RequireSession must not special-case which error came back.
	auth := stubAuthenticator{err: errors.New("stub: session invalid")}
	handler := RequireSession(auth, func(w http.ResponseWriter, r *http.Request) {
		t.Fatal("next handler must not be reached with a revoked token")
	})

	req := httptest.NewRequest(http.MethodGet, "/v1/identity/me", nil)
	req.Header.Set("Authorization", "Bearer revoked-token")
	rec := httptest.NewRecorder()
	handler(rec, req)

	if rec.Code != http.StatusUnauthorized {
		t.Errorf("got status %d, want 401", rec.Code)
	}
}

func TestUserIDFromContext_NoValuePresentReturnsFalse(t *testing.T) {
	_, ok := UserIDFromContext(context.Background())
	if ok {
		t.Errorf("UserIDFromContext on a bare context: ok = true, want false")
	}
}
