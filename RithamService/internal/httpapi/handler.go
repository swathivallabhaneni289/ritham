package httpapi

import "net/http"

// NewMux registers the one route this service exposes.
func NewMux() *http.ServeMux {
	mux := http.NewServeMux()
	mux.HandleFunc("POST /v1/workout-plan", handleWorkoutPlan)
	return mux
}

func handleWorkoutPlan(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
}
