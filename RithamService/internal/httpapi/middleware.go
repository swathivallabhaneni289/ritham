package httpapi

import (
	"context"
	"net/http"
	"strings"

	"github.com/google/uuid"
)

// authenticator is the minimal capability RequireSession needs from an identity service -- a
// one-method structural interface so middleware_test.go can substitute a stub with no database,
// while *identity.Service (main.go's real implementation) satisfies it with no explicit
// declaration required (T-04.1-13's key_links: RequireSession calls AuthenticateBearer on every
// protected route).
type authenticator interface {
	AuthenticateBearer(ctx context.Context, token string) (uuid.UUID, error)
}

// contextKeyUserID is the sole key RequireSession ever writes into a request context.
type contextKeyType int

const contextKeyUserID contextKeyType = iota

// bearerPrefix is the only Authorization scheme RequireSession accepts.
const bearerPrefix = "Bearer "

// RequireSession wraps next so it is only ever reached with a valid, unexpired, unrevoked bearer
// token. Every failure -- a missing header, a malformed scheme, or an authentication error from
// auth -- writes the identical generic 401 via writeJSONError; the caller can never distinguish
// which one occurred (T-04.1-12).
func RequireSession(auth authenticator, next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		token, ok := bearerToken(r)
		if !ok {
			writeJSONError(w, http.StatusUnauthorized, "authentication failed")
			return
		}

		userID, err := auth.AuthenticateBearer(r.Context(), token)
		if err != nil {
			writeJSONError(w, http.StatusUnauthorized, "authentication failed")
			return
		}

		ctx := context.WithValue(r.Context(), contextKeyUserID, userID)
		next(w, r.WithContext(ctx))
	}
}

// UserIDFromContext is the only reader of the user id RequireSession stores in the request
// context. ok is false whenever RequireSession never ran (or failed) for this request.
func UserIDFromContext(ctx context.Context) (uuid.UUID, bool) {
	userID, ok := ctx.Value(contextKeyUserID).(uuid.UUID)
	return userID, ok
}

// bearerToken extracts the token from an "Authorization: Bearer <token>" header. It requires the
// exact "Bearer " scheme (case-sensitive, per RFC 6750) and a non-empty token.
func bearerToken(r *http.Request) (string, bool) {
	header := r.Header.Get("Authorization")
	if !strings.HasPrefix(header, bearerPrefix) {
		return "", false
	}
	token := strings.TrimPrefix(header, bearerPrefix)
	if token == "" {
		return "", false
	}
	return token, true
}
