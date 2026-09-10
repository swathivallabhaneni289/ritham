package httpapi

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"reflect"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/swathivallabhaneni289/ritham/RithamService/internal/events"
	"github.com/swathivallabhaneni289/ritham/RithamService/internal/groups"
)

// stubEventsService lets the events handler tests exercise every response-shaping branch with no
// database, mirroring stubGroupsService's and stubFriendsService's precedent from this same
// phase.
type stubEventsService struct {
	createFunc        func(ctx context.Context, organizerUserID, groupID uuid.UUID, in events.NewGoalEvent) (events.GoalEvent, error)
	listFunc          func(ctx context.Context, userID, groupID uuid.UUID) ([]events.GoalEvent, error)
	getFunc           func(ctx context.Context, userID, eventID uuid.UUID) (events.GoalEvent, error)
	rsvpFunc          func(ctx context.Context, userID, eventID uuid.UUID) (events.RSVPState, error)
	withdrawRSVPFunc  func(ctx context.Context, userID, eventID uuid.UUID) (events.RSVPState, error)
	rsvpStateFunc     func(ctx context.Context, userID, eventID uuid.UUID) (events.RSVPState, error)
	logCompletionFunc func(ctx context.Context, userID, eventID uuid.UUID, in events.NewCompletion) (events.Completion, error)
	completionsFunc   func(ctx context.Context, userID, eventID uuid.UUID) ([]events.Completion, error)
}

func (s *stubEventsService) Create(ctx context.Context, organizerUserID, groupID uuid.UUID, in events.NewGoalEvent) (events.GoalEvent, error) {
	return s.createFunc(ctx, organizerUserID, groupID, in)
}

func (s *stubEventsService) List(ctx context.Context, userID, groupID uuid.UUID) ([]events.GoalEvent, error) {
	return s.listFunc(ctx, userID, groupID)
}

func (s *stubEventsService) Get(ctx context.Context, userID, eventID uuid.UUID) (events.GoalEvent, error) {
	return s.getFunc(ctx, userID, eventID)
}

func (s *stubEventsService) RSVP(ctx context.Context, userID, eventID uuid.UUID) (events.RSVPState, error) {
	return s.rsvpFunc(ctx, userID, eventID)
}

func (s *stubEventsService) WithdrawRSVP(ctx context.Context, userID, eventID uuid.UUID) (events.RSVPState, error) {
	return s.withdrawRSVPFunc(ctx, userID, eventID)
}

func (s *stubEventsService) RSVPState(ctx context.Context, userID, eventID uuid.UUID) (events.RSVPState, error) {
	return s.rsvpStateFunc(ctx, userID, eventID)
}

func (s *stubEventsService) LogCompletion(ctx context.Context, userID, eventID uuid.UUID, in events.NewCompletion) (events.Completion, error) {
	return s.logCompletionFunc(ctx, userID, eventID, in)
}

func (s *stubEventsService) Completions(ctx context.Context, userID, eventID uuid.UUID) ([]events.Completion, error) {
	return s.completionsFunc(ctx, userID, eventID)
}

// eventsRouteCase names one of the eight event routes together with the handler that serves it,
// for the unauthenticated-returns-401 table test below.
type eventsRouteCase struct {
	name    string
	method  string
	path    string
	handler func(svc eventsService) http.HandlerFunc
}

func eventsRouteCases() []eventsRouteCase {
	return []eventsRouteCase{
		{"create event", http.MethodPost, "/v1/groups/{id}/events", handleCreateEvent},
		{"list events", http.MethodGet, "/v1/groups/{id}/events", handleListEvents},
		{"get event", http.MethodGet, "/v1/events/{id}", handleGetEvent},
		{"rsvp", http.MethodPost, "/v1/events/{id}/rsvp", handleRSVP},
		{"withdraw rsvp", http.MethodDelete, "/v1/events/{id}/rsvp", handleWithdrawRSVP},
		{"get rsvp state", http.MethodGet, "/v1/events/{id}/rsvp", handleGetRSVPState},
		{"log completion", http.MethodPost, "/v1/events/{id}/completions", handleLogCompletion},
		{"list completions", http.MethodGet, "/v1/events/{id}/completions", handleListCompletions},
	}
}

func TestEventsRoutes_UnauthenticatedReturns401(t *testing.T) {
	// An empty stub: every *Func field is nil. If any handler under test reached into the
	// service, this stub panics -- proving RequireSession stopped the request before the handler
	// body ran, per T-04.1-13.
	svc := &stubEventsService{}
	auth := stubAuthenticator{}

	for _, tc := range eventsRouteCases() {
		t.Run(tc.name, func(t *testing.T) {
			handler := RequireSession(auth, tc.handler(svc))
			req := httptest.NewRequest(tc.method, tc.path, nil)
			rec := httptest.NewRecorder()
			handler.ServeHTTP(rec, req)

			if rec.Code != http.StatusUnauthorized {
				t.Errorf("got status %d, want 401 (no Authorization header)", rec.Code)
			}
		})
	}
}

func TestHandleLogCompletion_UnexpectedFieldReturns400(t *testing.T) {
	svc := &stubEventsService{}
	auth := stubAuthenticator{userID: uuid.New()}
	handler := RequireSession(auth, handleLogCompletion(svc))

	body := `{"completedAt":"2026-09-12T10:00:00Z","ownTimeSeconds":900,"distanceMetres":5000}`
	req := httptest.NewRequest(http.MethodPost, "/v1/events/"+uuid.New().String()+"/completions", bytes.NewBufferString(body))
	req.SetPathValue("id", uuid.New().String())
	req.Header.Set("Authorization", "Bearer test-token")
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("got status %d, want 400 for an unexpected field", rec.Code)
	}
}

func TestHandleGetEvent_NonMemberReturns404(t *testing.T) {
	svc := &stubEventsService{
		getFunc: func(ctx context.Context, userID, eventID uuid.UUID) (events.GoalEvent, error) {
			return events.GoalEvent{}, groups.ErrNotAMember
		},
	}
	auth := stubAuthenticator{userID: uuid.New()}
	handler := RequireSession(auth, handleGetEvent(svc))

	eventID := uuid.New()
	req := httptest.NewRequest(http.MethodGet, "/v1/events/"+eventID.String(), nil)
	req.SetPathValue("id", eventID.String())
	req.Header.Set("Authorization", "Bearer test-token")
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusNotFound {
		t.Fatalf("got status %d, want 404 for a non-member's Get", rec.Code)
	}
}

func TestHandleLogCompletion_NonMemberReturns404(t *testing.T) {
	svc := &stubEventsService{
		logCompletionFunc: func(ctx context.Context, userID, eventID uuid.UUID, in events.NewCompletion) (events.Completion, error) {
			return events.Completion{}, groups.ErrNotAMember
		},
	}
	auth := stubAuthenticator{userID: uuid.New()}
	handler := RequireSession(auth, handleLogCompletion(svc))

	eventID := uuid.New()
	body := `{"completedAt":"2026-09-12T10:00:00Z"}`
	req := httptest.NewRequest(http.MethodPost, "/v1/events/"+eventID.String()+"/completions", bytes.NewBufferString(body))
	req.SetPathValue("id", eventID.String())
	req.Header.Set("Authorization", "Bearer test-token")
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusNotFound {
		t.Fatalf("got status %d, want 404 for a non-member's completion attempt", rec.Code)
	}
}

// TestCompletionRequest_ShapeIsExactlyFiveMinimizedFields mirrors
// TestWorkoutPlanRequest_ShapeIsExactlyThreeMinimizedFields: CompletionRequest is the most
// important type in this phase's wire surface, and its field set is reflection-locked so widening
// it (e.g. adding a distance, pace, or route field) fails a test rather than shipping silently.
func TestCompletionRequest_ShapeIsExactlyFiveMinimizedFields(t *testing.T) {
	typ := reflect.TypeOf(CompletionRequest{})
	if typ.NumField() != 5 {
		t.Fatalf("CompletionRequest has %d fields, want exactly 5 (GROUPEVENTS-02's minimized boundary)", typ.NumField())
	}

	wantTags := map[string]bool{
		"completedAt":    false,
		"ownTimeSeconds": false,
		"photoAssetId":   false,
		"placeName":      false,
		"caption":        false,
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

// TestCompletionResponse_ShapeIsExactlyTenFields locks CompletionResponse's own field set the
// same way -- no position, total, or completed-count field, and no field for a personal distance,
// pace, or route.
//
// <!-- planner-discipline-allow: distance|pace|route -->
func TestCompletionResponse_ShapeIsExactlyTenFields(t *testing.T) {
	typ := reflect.TypeOf(CompletionResponse{})
	wantKeys := []string{
		"id", "eventId", "userId", "displayName", "completedAt",
		"ownTimeSeconds", "photoAssetId", "placeName", "caption", "postedAt",
	}
	if typ.NumField() != len(wantKeys) {
		t.Fatalf("CompletionResponse has %d fields, want exactly %d", typ.NumField(), len(wantKeys))
	}

	seen := map[string]bool{}
	for i := 0; i < typ.NumField(); i++ {
		tag := typ.Field(i).Tag.Get("json")
		// Strip a trailing ",omitempty" for comparison purposes.
		for j := 0; j < len(tag); j++ {
			if tag[j] == ',' {
				tag = tag[:j]
				break
			}
		}
		seen[tag] = true
	}
	for _, want := range wantKeys {
		if !seen[want] {
			t.Errorf("expected a field tagged %q, none found", want)
		}
	}
}

// TestCompletionResponse_WithAndWithoutOwnTimeDifferByExactlyOneKey asserts the marshaled JSON
// key sets for a completion logged with an own time and one logged without differ by exactly the
// "ownTimeSeconds" key -- proving the omitempty boundary docs/group-events.md §2's copy table
// describes ("Priya completed the Saturday 5K Walk." vs "...— 32:14.", both equally complete
// cards) is real on the wire, not just in prose.
func TestCompletionResponse_WithAndWithoutOwnTimeDifferByExactlyOneKey(t *testing.T) {
	completedAt := time.Date(2026, 9, 12, 10, 0, 0, 0, time.UTC)
	postedAt := time.Date(2026, 9, 12, 10, 5, 0, 0, time.UTC)
	base := events.Completion{
		ID:          uuid.New(),
		EventID:     uuid.New(),
		User:        events.Member{UserID: uuid.New(), DisplayName: "Priya"},
		CompletedAt: completedAt,
		PostedAt:    postedAt,
	}

	without := base
	withTime := base
	ownTime := 1934
	withTime.OwnTimeSeconds = &ownTime

	withoutKeys := jsonKeySet(t, completionResponse(without))
	withKeys := jsonKeySet(t, completionResponse(withTime))

	diff := symmetricDifference(withoutKeys, withKeys)
	if len(diff) != 1 || !diff["ownTimeSeconds"] {
		t.Fatalf("key-set difference between without-time and with-time responses = %v, want exactly {ownTimeSeconds}", diff)
	}
}

func jsonKeySet(t *testing.T, v any) map[string]bool {
	t.Helper()
	body, err := json.Marshal(v)
	if err != nil {
		t.Fatalf("unexpected marshal error: %v", err)
	}
	var decoded map[string]json.RawMessage
	if err := json.Unmarshal(body, &decoded); err != nil {
		t.Fatalf("unexpected unmarshal error: %v", err)
	}
	keys := map[string]bool{}
	for k := range decoded {
		keys[k] = true
	}
	return keys
}

func symmetricDifference(a, b map[string]bool) map[string]bool {
	diff := map[string]bool{}
	for k := range a {
		if !b[k] {
			diff[k] = true
		}
	}
	for k := range b {
		if !a[k] {
			diff[k] = true
		}
	}
	return diff
}
