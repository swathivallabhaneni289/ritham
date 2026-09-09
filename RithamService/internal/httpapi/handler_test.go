package httpapi

import (
	"bytes"
	"context"
	"crypto"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"reflect"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/swathivallabhaneni289/ritham/RithamService/internal/identity"
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

	NewMux(nil, nil, nil).ServeHTTP(rec, req)

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

	NewMux(nil, nil, nil).ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Errorf("got status %d, want 400", rec.Code)
	}
}

func TestHandleWorkoutPlan_StringFrequencyReturns400(t *testing.T) {
	body := `{"frequencyPerWeek":"5","experienceLevel":"intermediate","guidancePermission":"none"}`
	req := httptest.NewRequest(http.MethodPost, "/v1/workout-plan", bytes.NewBufferString(body))
	rec := httptest.NewRecorder()

	NewMux(nil, nil, nil).ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Errorf("got status %d, want 400", rec.Code)
	}
}

func TestHandleWorkoutPlan_UnsupportedFrequencyReturns400(t *testing.T) {
	body := `{"frequencyPerWeek":4,"experienceLevel":"intermediate","guidancePermission":"none"}`
	req := httptest.NewRequest(http.MethodPost, "/v1/workout-plan", bytes.NewBufferString(body))
	rec := httptest.NewRecorder()

	NewMux(nil, nil, nil).ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Errorf("got status %d, want 400", rec.Code)
	}
}

func TestHandleWorkoutPlan_UnknownExperienceLevelReturns400(t *testing.T) {
	body := `{"frequencyPerWeek":5,"experienceLevel":"expert","guidancePermission":"none"}`
	req := httptest.NewRequest(http.MethodPost, "/v1/workout-plan", bytes.NewBufferString(body))
	rec := httptest.NewRecorder()

	NewMux(nil, nil, nil).ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Errorf("got status %d, want 400", rec.Code)
	}
}

func TestHandleWorkoutPlan_UnknownFieldReturns400(t *testing.T) {
	body := `{"frequencyPerWeek":5,"experienceLevel":"intermediate","guidancePermission":"none","userId":"abc123"}`
	req := httptest.NewRequest(http.MethodPost, "/v1/workout-plan", bytes.NewBufferString(body))
	rec := httptest.NewRecorder()

	NewMux(nil, nil, nil).ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Errorf("got status %d, want 400 for an unexpected field (D-07 boundary enforcement)", rec.Code)
	}
}

func TestHandleWorkoutPlan_GETReturns405(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/v1/workout-plan", nil)
	rec := httptest.NewRecorder()

	NewMux(nil, nil, nil).ServeHTTP(rec, req)

	if rec.Code != http.StatusMethodNotAllowed {
		t.Errorf("got status %d, want 405", rec.Code)
	}
}

// assertExactJSONFields is the WorkoutPlanRequest reflection-based field-count/JSON-tag pattern
// (see TestWorkoutPlanRequest_ShapeIsExactlyThreeMinimizedFields above), generalized for reuse
// across this task's four new request/response types.
func assertExactJSONFields(t *testing.T, v interface{}, wantTags map[string]bool) {
	t.Helper()
	typ := reflect.TypeOf(v)
	if typ.NumField() != len(wantTags) {
		t.Fatalf("%s has %d fields, want exactly %d", typ.Name(), typ.NumField(), len(wantTags))
	}
	seen := make(map[string]bool, len(wantTags))
	for i := 0; i < typ.NumField(); i++ {
		tag := typ.Field(i).Tag.Get("json")
		if _, ok := wantTags[tag]; !ok {
			t.Errorf("%s: unexpected JSON tag %q on field %s", typ.Name(), tag, typ.Field(i).Name)
			continue
		}
		seen[tag] = true
	}
	for tag := range wantTags {
		if !seen[tag] {
			t.Errorf("%s: expected a field tagged %q, none found", typ.Name(), tag)
		}
	}
}

func TestAppleSignInRequest_ShapeIsExactlyThreeMinimizedFields(t *testing.T) {
	assertExactJSONFields(t, AppleSignInRequest{}, map[string]bool{
		"identityToken": false,
		"nonce":         false,
		"displayName":   false,
	})
}

func TestSessionResponse_ShapeIsExactlyFourFields(t *testing.T) {
	assertExactJSONFields(t, SessionResponse{}, map[string]bool{
		"userId":       false,
		"displayName":  false,
		"sessionToken": false,
		"expiresAt":    false,
	})
}

func TestMeResponse_ShapeIsExactlyTwoFields(t *testing.T) {
	assertExactJSONFields(t, MeResponse{}, map[string]bool{
		"userId":      false,
		"displayName": false,
	})
}

func TestDisplayNameRequest_ShapeIsExactlyOneField(t *testing.T) {
	assertExactJSONFields(t, DisplayNameRequest{}, map[string]bool{
		"displayName": false,
	})
}

func TestWorkoutPlanRequest_StillHasExactlyOriginalThreeFieldsAfterIdentityRoutesAdded(t *testing.T) {
	// 04.1-RESEARCH.md Pitfall 4 / this plan's threat T-04.1-15: identity threads through the new
	// routes only. WorkoutPlanRequest's own reflection shape test above already pins this; this
	// second assertion exists specifically to survive an accidental future edit to that first
	// test's expectations without anyone noticing the boundary moved.
	typ := reflect.TypeOf(WorkoutPlanRequest{})
	if typ.NumField() != 3 {
		t.Fatalf("WorkoutPlanRequest has %d fields after adding identity routes, want unchanged 3", typ.NumField())
	}
	for _, want := range []string{"frequencyPerWeek", "experienceLevel", "guidancePermission"} {
		found := false
		for i := 0; i < typ.NumField(); i++ {
			if typ.Field(i).Tag.Get("json") == want {
				found = true
				break
			}
		}
		if !found {
			t.Errorf("WorkoutPlanRequest lost its %q field/tag", want)
		}
	}
}

// noopAppleKeySource is a minimal identity.AppleKeySource stub used only to construct a
// non-nil *identity.Service for route-registration tests -- these tests never reach a code path
// that calls PublicKeys or touches the database.
type noopAppleKeySource struct{}

func (noopAppleKeySource) PublicKeys(ctx context.Context) (map[string]crypto.PublicKey, error) {
	return nil, nil
}

func TestNewMux_IdentityRoutesRegisteredOnlyWhenServiceProvided(t *testing.T) {
	t.Run("nil service leaves identity routes unregistered", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/v1/identity/me", nil)
		rec := httptest.NewRecorder()

		NewMux(nil, nil, nil).ServeHTTP(rec, req)

		if rec.Code != http.StatusNotFound {
			t.Errorf("got status %d, want 404 for an unregistered route when idsvc is nil", rec.Code)
		}
	})

	t.Run("real service registers identity routes behind RequireSession", func(t *testing.T) {
		idsvc := identity.New(nil, noopAppleKeySource{}, "com.ritham.app", time.Now)
		req := httptest.NewRequest(http.MethodGet, "/v1/identity/me", nil)
		rec := httptest.NewRecorder()

		NewMux(idsvc, nil, nil).ServeHTTP(rec, req)

		if rec.Code != http.StatusUnauthorized {
			t.Errorf("got status %d, want 401 (route exists, no Authorization header)", rec.Code)
		}
	})
}

func TestNewMux_PhotoRoutesRegisteredOnlyWhenServiceProvided(t *testing.T) {
	idsvc := identity.New(nil, noopAppleKeySource{}, "com.ritham.app", time.Now)

	t.Run("nil photo service leaves photo routes unregistered", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/v1/photos/"+uuid.New().String(), nil)
		rec := httptest.NewRecorder()

		NewMux(idsvc, nil, nil).ServeHTTP(rec, req)

		if rec.Code != http.StatusNotFound {
			t.Errorf("got status %d, want 404 for an unregistered route when photosvc/objectStore are nil", rec.Code)
		}
	})
}
