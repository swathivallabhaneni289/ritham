package httpapi

import (
	"encoding/json"
	"errors"
	"net/http"

	"github.com/swathivallabhaneni289/ritham/RithamService/internal/plan"
)

// maxRequestBodyBytes caps a request body well above any legitimate three-field payload but far
// below anything that could tie up the decoder or memory (T-02-15: DoS mitigation).
const maxRequestBodyBytes = 1 << 16 // 64 KiB

// NewMux registers the one route this service exposes. A GET (or any other method) to the same
// path is rejected with 405 by the router itself, via Go 1.22+'s method-and-path pattern syntax
// -- not by hand-written branching.
func NewMux() *http.ServeMux {
	mux := http.NewServeMux()
	mux.HandleFunc("POST /v1/workout-plan", handleWorkoutPlan)
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

func writeJSONError(w http.ResponseWriter, status int, message string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(map[string]string{"error": message})
}
