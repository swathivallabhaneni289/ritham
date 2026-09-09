package httpapi

import (
	"encoding/json"
	"errors"
	"net/http"
	"time"

	"github.com/swathivallabhaneni289/ritham/RithamService/internal/identity"
	"github.com/swathivallabhaneni289/ritham/RithamService/internal/plan"
)

// maxRequestBodyBytes caps a request body well above any legitimate three-field payload but far
// below anything that could tie up the decoder or memory (T-02-15: DoS mitigation).
const maxRequestBodyBytes = 1 << 16 // 64 KiB

// NewMux registers every route this service exposes. idsvc is the identity service backing the
// four identity routes; when it is nil (no database configured at startup, per main.go), those
// four routes are simply not registered rather than being wired to a nil receiver that would
// panic on the first request -- the pre-existing workout-plan route is unaffected either way.
// A GET (or any other unregistered method) to a registered path is rejected with 405 by the
// router itself, via Go 1.22+'s method-and-path pattern syntax -- not by hand-written branching.
func NewMux(idsvc *identity.Service) *http.ServeMux {
	mux := http.NewServeMux()
	mux.HandleFunc("POST /v1/workout-plan", handleWorkoutPlan)

	if idsvc != nil {
		// Sign-in is deliberately unwrapped -- it is the request that establishes a session in
		// the first place. The other three sit behind RequireSession (T-04.1-13: this is the
		// single wrapper and the only writer of the request-scoped user id).
		mux.HandleFunc("POST /v1/identity/apple", handleAppleSignIn(idsvc))
		mux.HandleFunc("POST /v1/identity/revoke", RequireSession(idsvc, handleRevokeSession(idsvc)))
		mux.HandleFunc("GET /v1/identity/me", RequireSession(idsvc, handleMe(idsvc)))
		mux.HandleFunc("PUT /v1/identity/display-name", RequireSession(idsvc, handleSetDisplayName(idsvc)))
	}

	return mux
}

// handleWorkoutPlan is three separately checked steps -- decode, generate, encode -- each with
// its own error check and its own response, per Go Backend Research §7's note that adjacent
// error-returning calls each need their own check.
func handleWorkoutPlan(w http.ResponseWriter, r *http.Request) {
	req, err := decodeWorkoutPlanRequest(w, r)
	if err != nil {
		writeJSONError(w, http.StatusBadRequest, "invalid request body")
		return
	}

	generated, err := plan.Generate(req.FrequencyPerWeek, req.ExperienceLevel, req.GuidancePermission)
	if err != nil {
		writeJSONError(w, statusForGenerateError(err), err.Error())
		return
	}

	body, err := json.Marshal(WorkoutPlanResponse{Plan: generated})
	if err != nil {
		writeJSONError(w, http.StatusInternalServerError, "failed to encode response")
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	w.Write(body)
}

// decodeWorkoutPlanRequest reads and decodes the request body, rejecting a body above
// maxRequestBodyBytes and any unknown field so the D-07 boundary stays enforced rather than
// merely documented -- an unexpected key fails loudly instead of being silently dropped.
func decodeWorkoutPlanRequest(w http.ResponseWriter, r *http.Request) (WorkoutPlanRequest, error) {
	r.Body = http.MaxBytesReader(w, r.Body, maxRequestBodyBytes)
	decoder := json.NewDecoder(r.Body)
	decoder.DisallowUnknownFields()

	var req WorkoutPlanRequest
	if err := decoder.Decode(&req); err != nil {
		return WorkoutPlanRequest{}, err
	}
	return req, nil
}

// statusForGenerateError maps each of plan.Generate's exported sentinel errors to 400; any other
// error (none currently reachable, since Generate returns only these sentinels or nil) maps to
// 500 so a future new failure mode fails safely rather than being silently treated as a client
// error.
func statusForGenerateError(err error) int {
	switch {
	case errors.Is(err, plan.ErrUnsupportedFrequency),
		errors.Is(err, plan.ErrUnknownExperienceLevel),
		errors.Is(err, plan.ErrUnknownGuidancePermission):
		return http.StatusBadRequest
	default:
		return http.StatusInternalServerError
	}
}

// handleAppleSignIn is unauthenticated -- it is the request that establishes a session.
func handleAppleSignIn(idsvc *identity.Service) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		req, err := decodeAppleSignInRequest(w, r)
		if err != nil {
			writeJSONError(w, http.StatusBadRequest, "invalid request body")
			return
		}

		result, err := idsvc.SignInWithApple(r.Context(), req.IdentityToken, req.Nonce, req.DisplayName)
		if err != nil {
			writeJSONError(w, statusForIdentityError(err), identityErrorMessage(err))
			return
		}

		body, err := json.Marshal(SessionResponse{
			UserID:       result.UserID.String(),
			DisplayName:  result.DisplayName,
			SessionToken: result.SessionToken,
			ExpiresAt:    result.ExpiresAt.UTC().Format(time.RFC3339),
		})
		if err != nil {
			writeJSONError(w, http.StatusInternalServerError, "failed to encode response")
			return
		}

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Write(body)
	}
}

// handleRevokeSession re-extracts the bearer token RequireSession already validated -- the
// middleware exposes only the authenticated user id via UserIDFromContext, never the raw token
// itself, so revocation reads the Authorization header directly rather than widening that
// context contract for one caller.
func handleRevokeSession(idsvc *identity.Service) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		token, ok := bearerToken(r)
		if !ok {
			writeJSONError(w, http.StatusUnauthorized, "authentication failed")
			return
		}

		if err := idsvc.RevokeSession(r.Context(), token); err != nil {
			writeJSONError(w, http.StatusInternalServerError, "internal error")
			return
		}

		w.WriteHeader(http.StatusNoContent)
	}
}

func handleMe(idsvc *identity.Service) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID, ok := UserIDFromContext(r.Context())
		if !ok {
			writeJSONError(w, http.StatusUnauthorized, "authentication failed")
			return
		}

		displayName, err := idsvc.User(r.Context(), userID)
		if err != nil {
			writeJSONError(w, http.StatusInternalServerError, "internal error")
			return
		}

		body, err := json.Marshal(MeResponse{UserID: userID.String(), DisplayName: displayName})
		if err != nil {
			writeJSONError(w, http.StatusInternalServerError, "failed to encode response")
			return
		}

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Write(body)
	}
}

func handleSetDisplayName(idsvc *identity.Service) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID, ok := UserIDFromContext(r.Context())
		if !ok {
			writeJSONError(w, http.StatusUnauthorized, "authentication failed")
			return
		}

		req, err := decodeDisplayNameRequest(w, r)
		if err != nil {
			writeJSONError(w, http.StatusBadRequest, "invalid request body")
			return
		}

		if err := idsvc.SetDisplayName(r.Context(), userID, req.DisplayName); err != nil {
			writeJSONError(w, statusForIdentityError(err), identityErrorMessage(err))
			return
		}

		body, err := json.Marshal(MeResponse{UserID: userID.String(), DisplayName: req.DisplayName})
		if err != nil {
			writeJSONError(w, http.StatusInternalServerError, "failed to encode response")
			return
		}

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Write(body)
	}
}

func decodeAppleSignInRequest(w http.ResponseWriter, r *http.Request) (AppleSignInRequest, error) {
	r.Body = http.MaxBytesReader(w, r.Body, maxRequestBodyBytes)
	decoder := json.NewDecoder(r.Body)
	decoder.DisallowUnknownFields()

	var req AppleSignInRequest
	if err := decoder.Decode(&req); err != nil {
		return AppleSignInRequest{}, err
	}
	return req, nil
}

func decodeDisplayNameRequest(w http.ResponseWriter, r *http.Request) (DisplayNameRequest, error) {
	r.Body = http.MaxBytesReader(w, r.Body, maxRequestBodyBytes)
	decoder := json.NewDecoder(r.Body)
	decoder.DisallowUnknownFields()

	var req DisplayNameRequest
	if err := decoder.Decode(&req); err != nil {
		return DisplayNameRequest{}, err
	}
	return req, nil
}

// statusForIdentityError maps identity's exported sentinel errors to an HTTP status, mirroring
// statusForGenerateError's pattern: every token/session failure is 401, an over-length display
// name is 400, anything else is 500.
func statusForIdentityError(err error) int {
	switch {
	case errors.Is(err, identity.ErrTokenInvalid),
		errors.Is(err, identity.ErrTokenAudience),
		errors.Is(err, identity.ErrTokenIssuer),
		errors.Is(err, identity.ErrTokenExpired),
		errors.Is(err, identity.ErrTokenNonce),
		errors.Is(err, identity.ErrSessionInvalid):
		return http.StatusUnauthorized
	case errors.Is(err, identity.ErrDisplayNameTooLong):
		return http.StatusBadRequest
	default:
		return http.StatusInternalServerError
	}
}

// identityErrorMessage returns a response body message for an identity error. Every
// authentication failure (token or session) gets the identical generic message -- a caller must
// never be able to distinguish an invalid token from an expired one from a revoked session
// (T-04.1-12) -- while a validation failure like an over-length display name can safely describe
// itself.
func identityErrorMessage(err error) string {
	switch {
	case errors.Is(err, identity.ErrDisplayNameTooLong):
		return err.Error()
	case errors.Is(err, identity.ErrTokenInvalid),
		errors.Is(err, identity.ErrTokenAudience),
		errors.Is(err, identity.ErrTokenIssuer),
		errors.Is(err, identity.ErrTokenExpired),
		errors.Is(err, identity.ErrTokenNonce),
		errors.Is(err, identity.ErrSessionInvalid):
		return "authentication failed"
	default:
		return "internal error"
	}
}

func writeJSONError(w http.ResponseWriter, status int, message string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(map[string]string{"error": message})
}
