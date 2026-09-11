package httpapi

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/google/uuid"

	"github.com/swathivallabhaneni289/ritham/RithamService/internal/feed"
)

// stubFeedsService lets the feed handler tests exercise every response-shaping branch with no
// database, mirroring stubEventsService's precedent from this same phase. gotLimit captures the
// last limit value passed through by the handler layer, for the clamping test below.
type stubFeedsService struct {
	groupFeedFunc            func(ctx context.Context, userID, groupID uuid.UUID, cursor string, limit int) (feed.Page, error)
	eventFeedFunc            func(ctx context.Context, userID, eventID uuid.UUID, cursor string, limit int) (feed.Page, error)
	sendCheerFunc            func(ctx context.Context, userID, completionID uuid.UUID, cheer string) error
	withdrawCheerFunc        func(ctx context.Context, userID, completionID uuid.UUID, cheer string) error
	requestExportConsentFunc func(ctx context.Context, ownerUserID, photoAssetID uuid.UUID, subjectUserIDs []uuid.UUID) error
	grantExportConsentFunc   func(ctx context.Context, subjectUserID, photoAssetID uuid.UUID) error
	exportAllowedFunc        func(ctx context.Context, exporterUserID, photoAssetID uuid.UUID) (feed.ExportGate, error)
}

func (s *stubFeedsService) GroupFeed(ctx context.Context, userID, groupID uuid.UUID, cursor string, limit int) (feed.Page, error) {
	return s.groupFeedFunc(ctx, userID, groupID, cursor, limit)
}

func (s *stubFeedsService) EventFeed(ctx context.Context, userID, eventID uuid.UUID, cursor string, limit int) (feed.Page, error) {
	return s.eventFeedFunc(ctx, userID, eventID, cursor, limit)
}

func (s *stubFeedsService) SendCheer(ctx context.Context, userID, completionID uuid.UUID, cheer string) error {
	return s.sendCheerFunc(ctx, userID, completionID, cheer)
}

func (s *stubFeedsService) WithdrawCheer(ctx context.Context, userID, completionID uuid.UUID, cheer string) error {
	return s.withdrawCheerFunc(ctx, userID, completionID, cheer)
}

func (s *stubFeedsService) RequestExportConsent(ctx context.Context, ownerUserID, photoAssetID uuid.UUID, subjectUserIDs []uuid.UUID) error {
	return s.requestExportConsentFunc(ctx, ownerUserID, photoAssetID, subjectUserIDs)
}

func (s *stubFeedsService) GrantExportConsent(ctx context.Context, subjectUserID, photoAssetID uuid.UUID) error {
	return s.grantExportConsentFunc(ctx, subjectUserID, photoAssetID)
}

func (s *stubFeedsService) ExportAllowed(ctx context.Context, exporterUserID, photoAssetID uuid.UUID) (feed.ExportGate, error) {
	return s.exportAllowedFunc(ctx, exporterUserID, photoAssetID)
}

// feedRouteCase names one of the seven feed/cheer/export-consent routes together with the
// handler that serves it, for the unauthenticated-returns-401 table test below.
type feedRouteCase struct {
	name    string
	method  string
	path    string
	handler func(svc feedsService) http.HandlerFunc
}

func feedRouteCases() []feedRouteCase {
	return []feedRouteCase{
		{"group feed", http.MethodGet, "/v1/groups/{id}/feed", handleGroupFeed},
		{"event feed", http.MethodGet, "/v1/events/{id}/feed", handleEventFeed},
		{"send cheer", http.MethodPost, "/v1/completions/{id}/cheers", handleSendCheer},
		{"withdraw cheer", http.MethodDelete, "/v1/completions/{id}/cheers", handleWithdrawCheer},
		{"request export consent", http.MethodPost, "/v1/photos/{id}/export-consent/request", handleRequestExportConsent},
		{"grant export consent", http.MethodPost, "/v1/photos/{id}/export-consent/grant", handleGrantExportConsent},
		{"get export consent", http.MethodGet, "/v1/photos/{id}/export-consent", handleGetExportConsent},
	}
}

// TestFeedRoutes_UnauthenticatedReturns401 mirrors TestEventsRoutes_UnauthenticatedReturns401: an
// empty stub (every *Func field nil) would panic if any handler reached into the service, proving
// RequireSession stopped the request before the handler body ran.
func TestFeedRoutes_UnauthenticatedReturns401(t *testing.T) {
	svc := &stubFeedsService{}
	auth := stubAuthenticator{}

	for _, tc := range feedRouteCases() {
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

// TestHandleGroupFeed_NonMemberReturns404 asserts feed.ErrNotAMember maps to 404, never 403.
func TestHandleGroupFeed_NonMemberReturns404(t *testing.T) {
	svc := &stubFeedsService{
		groupFeedFunc: func(ctx context.Context, userID, groupID uuid.UUID, cursor string, limit int) (feed.Page, error) {
			return feed.Page{}, feed.ErrNotAMember
		},
	}
	auth := stubAuthenticator{userID: uuid.New()}
	handler := RequireSession(auth, handleGroupFeed(svc))

	groupID := uuid.New()
	req := httptest.NewRequest(http.MethodGet, "/v1/groups/"+groupID.String()+"/feed", nil)
	req.SetPathValue("id", groupID.String())
	req.Header.Set("Authorization", "Bearer test-token")
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusNotFound {
		t.Fatalf("got status %d, want 404 for a non-member's feed request", rec.Code)
	}
}

// TestHandleGroupFeed_PageSizeAboveCapIsClampedNotRejected asserts a "limit" query parameter above
// the cap is passed through to the service layer (whose own clamping applies it), never rejected
// with a 400 at the handler layer.
func TestHandleGroupFeed_PageSizeAboveCapIsClampedNotRejected(t *testing.T) {
	var gotLimit int
	svc := &stubFeedsService{
		groupFeedFunc: func(ctx context.Context, userID, groupID uuid.UUID, cursor string, limit int) (feed.Page, error) {
			gotLimit = limit
			return feed.Page{Items: []feed.Item{}}, nil
		},
	}
	auth := stubAuthenticator{userID: uuid.New()}
	handler := RequireSession(auth, handleGroupFeed(svc))

	groupID := uuid.New()
	req := httptest.NewRequest(http.MethodGet, "/v1/groups/"+groupID.String()+"/feed?limit=999", nil)
	req.SetPathValue("id", groupID.String())
	req.Header.Set("Authorization", "Bearer test-token")
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("got status %d, want 200 (an above-cap limit is clamped, not rejected)", rec.Code)
	}
	if gotLimit != 999 {
		t.Fatalf("handler passed limit=%d to the service, want 999 (the raw requested value -- clamping is the service's own job)", gotLimit)
	}
}

// TestHandleSendCheer_UnknownCheerReturns400 asserts feed.ErrUnknownCheer maps to 400.
func TestHandleSendCheer_UnknownCheerReturns400(t *testing.T) {
	svc := &stubFeedsService{
		sendCheerFunc: func(ctx context.Context, userID, completionID uuid.UUID, cheer string) error {
			return feed.ErrUnknownCheer
		},
	}
	auth := stubAuthenticator{userID: uuid.New()}
	handler := RequireSession(auth, handleSendCheer(svc))

	completionID := uuid.New()
	body := `{"cheer":"fistBump"}`
	req := httptest.NewRequest(http.MethodPost, "/v1/completions/"+completionID.String()+"/cheers", bytes.NewBufferString(body))
	req.SetPathValue("id", completionID.String())
	req.Header.Set("Authorization", "Bearer test-token")
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("got status %d, want 400 for an unknown cheer value", rec.Code)
	}
}

// TestHandleGetExportConsent_OutstandingConsentsReturnsPendingSubjectsAndClosedGate asserts the
// export-status route surfaces both the closed gate and exactly which subjects are still pending.
func TestHandleGetExportConsent_OutstandingConsentsReturnsPendingSubjectsAndClosedGate(t *testing.T) {
	pendingSubject := uuid.New()
	svc := &stubFeedsService{
		exportAllowedFunc: func(ctx context.Context, exporterUserID, photoAssetID uuid.UUID) (feed.ExportGate, error) {
			return feed.ExportGate{Allowed: false, AwaitingSubjectIDs: []uuid.UUID{pendingSubject}}, nil
		},
	}
	auth := stubAuthenticator{userID: uuid.New()}
	handler := RequireSession(auth, handleGetExportConsent(svc))

	photoID := uuid.New()
	req := httptest.NewRequest(http.MethodGet, "/v1/photos/"+photoID.String()+"/export-consent", nil)
	req.SetPathValue("id", photoID.String())
	req.Header.Set("Authorization", "Bearer test-token")
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("got status %d, want 200", rec.Code)
	}

	var resp ExportConsentResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
		t.Fatalf("decoding response: %v", err)
	}
	if resp.Allowed {
		t.Error("resp.Allowed = true, want false (a subject is still outstanding)")
	}
	if len(resp.AwaitingSubjectIDs) != 1 || resp.AwaitingSubjectIDs[0] != pendingSubject.String() {
		t.Errorf("resp.AwaitingSubjectIDs = %v, want exactly [%s]", resp.AwaitingSubjectIDs, pendingSubject)
	}
}

// TestHandleGetExportConsent_BystanderDenied is CR-01's handler-layer regression test: asserts a
// caller feed.ExportAllowed rejects (a bystander or departed group member, neither the photo's
// owner nor a recorded subject) gets 403 through this exact route -- not photo consent data of any
// kind. Covers both halves of the review's own stated proof obligation: the status code, and that
// the response body carries no ExportConsentResponse JSON (in particular, no awaitingSubjectIds
// key, which is precisely the information this route was leaking before the fix).
func TestHandleGetExportConsent_BystanderDenied(t *testing.T) {
	svc := &stubFeedsService{
		exportAllowedFunc: func(ctx context.Context, exporterUserID, photoAssetID uuid.UUID) (feed.ExportGate, error) {
			return feed.ExportGate{}, feed.ErrNotPhotoOwner
		},
	}
	auth := stubAuthenticator{userID: uuid.New()}
	handler := RequireSession(auth, handleGetExportConsent(svc))

	photoID := uuid.New()
	req := httptest.NewRequest(http.MethodGet, "/v1/photos/"+photoID.String()+"/export-consent", nil)
	req.SetPathValue("id", photoID.String())
	req.Header.Set("Authorization", "Bearer test-token")
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusForbidden {
		t.Fatalf("got status %d, want 403 for a bystander/departed-member export-consent status check", rec.Code)
	}

	var resp ExportConsentResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err == nil {
		if resp.Allowed || len(resp.AwaitingSubjectIDs) != 0 {
			t.Fatalf("403 response body decoded as non-empty ExportConsentResponse %+v -- the denied caller must never see consent data", resp)
		}
	}
	if bytes.Contains(rec.Body.Bytes(), []byte("awaitingSubjectIds")) {
		t.Fatalf("403 response body contains awaitingSubjectIds -- must never leak which subjects are outstanding to a denied caller: %s", rec.Body.String())
	}
}

// TestHandleRequestExportConsent_NotOwnerReturns403 asserts feed.ErrNotPhotoOwner maps to 403 --
// this plan's own explicit instruction, a deliberate divergence from statusForEventsError's
// photo-not-owned-is-404 precedent (recorded in 04.1-12-SUMMARY.md's Threat Flags).
func TestHandleRequestExportConsent_NotOwnerReturns403(t *testing.T) {
	svc := &stubFeedsService{
		requestExportConsentFunc: func(ctx context.Context, ownerUserID, photoAssetID uuid.UUID, subjectUserIDs []uuid.UUID) error {
			return feed.ErrNotPhotoOwner
		},
	}
	auth := stubAuthenticator{userID: uuid.New()}
	handler := RequireSession(auth, handleRequestExportConsent(svc))

	photoID := uuid.New()
	body := `{"subjectUserIds":["` + uuid.New().String() + `"]}`
	req := httptest.NewRequest(http.MethodPost, "/v1/photos/"+photoID.String()+"/export-consent/request", bytes.NewBufferString(body))
	req.SetPathValue("id", photoID.String())
	req.Header.Set("Authorization", "Bearer test-token")
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusForbidden {
		t.Fatalf("got status %d, want 403 for a non-owner's export-consent request", rec.Code)
	}
}
