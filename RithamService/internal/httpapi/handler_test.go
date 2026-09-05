package httpapi

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"reflect"
	"testing"

	"github.com/swathivallabhaneni289/ritham/RithamService/internal/plan"
)

func TestWorkoutPlanRequest_ShapeIsExactlyThreeMinimizedFields(t *testing.T) {
	typ := reflect.TypeOf(WorkoutPlanRequest{})
	if typ.NumField() != 3 {
		t.Fatalf("WorkoutPlanRequest has %d fields, want exactly 3 (D-07's minimized boundary)", typ.NumField())
	}

	wantTags := map[string]bool{
		"frequencyPerWeek":   false,
		"experienceLevel":    false,
		"guidancePermission": false,
	}
	for i := 0; i < typ.NumField(); i++ {
		tag := typ.Field(i).Tag.Get("json")
		if _, ok := wantTags[tag]; !ok {
			t.Errorf("unexpected JSON tag %q on field %s", tag, typ.Field(i).Name)
			continue
		}
		wantTags[tag] = true
	}
	for tag, found := range wantTags {
		if !found {
			t.Errorf("expected a field tagged %q, none found", tag)
		}
	}
}

func TestWorkoutPlanRequest_MarshaledFieldNamesMatchWireContract(t *testing.T) {
	// Guards against a tag that is present but misspelled: reflection alone can't catch a typo
	// that's consistently wrong on both sides of a round trip, but the literal marshaled bytes
	// will always spell the tag correctly if the tag itself is correct.
	body, err := json.Marshal(WorkoutPlanRequest{
		FrequencyPerWeek:   5,
		ExperienceLevel:    plan.ExperienceIntermediate,
		GuidancePermission: plan.PermissionNone,
	})
	if err != nil {
		t.Fatalf("unexpected marshal error: %v", err)
	}
	for _, want := range []string{`"frequencyPerWeek"`, `"experienceLevel"`, `"guidancePermission"`} {
		if !bytes.Contains(body, []byte(want)) {
			t.Errorf("marshaled request %s does not contain expected tag %s", body, want)
		}
	}
}

func TestWorkoutPlanRequest_RoundTrips(t *testing.T) {
	original := WorkoutPlanRequest{
		FrequencyPerWeek:   5,
		ExperienceLevel:    plan.ExperienceIntermediate,
		GuidancePermission: plan.PermissionRecommended,
	}
	body, err := json.Marshal(original)
	if err != nil {
		t.Fatalf("unexpected marshal error: %v", err)
	}
	var decoded WorkoutPlanRequest
	if err := json.Unmarshal(body, &decoded); err != nil {
		t.Fatalf("unexpected unmarshal error: %v", err)
	}
	if !reflect.DeepEqual(original, decoded) {
		t.Errorf("round trip mismatch: original %+v, decoded %+v", original, decoded)
	}
}

func TestHandleWorkoutPlan_ValidRequestReturns200WithPlanKey(t *testing.T) {
	body := `{"frequencyPerWeek":5,"experienceLevel":"intermediate","guidancePermission":"none"}`
	req := httptest.NewRequest(http.MethodPost, "/v1/workout-plan", bytes.NewBufferString(body))
	rec := httptest.NewRecorder()

	NewMux().ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("got status %d, want 200; body: %s", rec.Code, rec.Body.String())
	}
	var decoded map[string]json.RawMessage
	if err := json.Unmarshal(rec.Body.Bytes(), &decoded); err != nil {
		t.Fatalf("response body is not valid JSON: %v", err)
	}
	if _, ok := decoded["plan"]; !ok {
		t.Errorf("response body %s has no top-level \"plan\" key", rec.Body.String())
	}
}

func TestHandleWorkoutPlan_InvalidJSONReturns400(t *testing.T) {
	req := httptest.NewRequest(http.MethodPost, "/v1/workout-plan", bytes.NewBufferString("{not json"))
	rec := httptest.NewRecorder()

	NewMux().ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Errorf("got status %d, want 400", rec.Code)
	}
}

func TestHandleWorkoutPlan_StringFrequencyReturns400(t *testing.T) {
	body := `{"frequencyPerWeek":"5","experienceLevel":"intermediate","guidancePermission":"none"}`
	req := httptest.NewRequest(http.MethodPost, "/v1/workout-plan", bytes.NewBufferString(body))
	rec := httptest.NewRecorder()

	NewMux().ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Errorf("got status %d, want 400", rec.Code)
	}
}

func TestHandleWorkoutPlan_UnsupportedFrequencyReturns400(t *testing.T) {
	body := `{"frequencyPerWeek":4,"experienceLevel":"intermediate","guidancePermission":"none"}`
	req := httptest.NewRequest(http.MethodPost, "/v1/workout-plan", bytes.NewBufferString(body))
	rec := httptest.NewRecorder()

	NewMux().ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Errorf("got status %d, want 400", rec.Code)
	}
}

func TestHandleWorkoutPlan_UnknownExperienceLevelReturns400(t *testing.T) {
	body := `{"frequencyPerWeek":5,"experienceLevel":"expert","guidancePermission":"none"}`
	req := httptest.NewRequest(http.MethodPost, "/v1/workout-plan", bytes.NewBufferString(body))
	rec := httptest.NewRecorder()

	NewMux().ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Errorf("got status %d, want 400", rec.Code)
	}
}

func TestHandleWorkoutPlan_UnknownFieldReturns400(t *testing.T) {
	body := `{"frequencyPerWeek":5,"experienceLevel":"intermediate","guidancePermission":"none","userId":"abc123"}`
	req := httptest.NewRequest(http.MethodPost, "/v1/workout-plan", bytes.NewBufferString(body))
	rec := httptest.NewRecorder()

	NewMux().ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Errorf("got status %d, want 400 for an unexpected field (D-07 boundary enforcement)", rec.Code)
	}
}

func TestHandleWorkoutPlan_GETReturns405(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/v1/workout-plan", nil)
	rec := httptest.NewRecorder()

	NewMux().ServeHTTP(rec, req)

	if rec.Code != http.StatusMethodNotAllowed {
		t.Errorf("got status %d, want 405", rec.Code)
	}
}
