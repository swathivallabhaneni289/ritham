package httpapi

import (
	"context"
	"errors"
	"net/http"
	"strconv"

	"github.com/google/uuid"

	"github.com/swathivallabhaneni289/ritham/RithamService/internal/feed"
)

// feedsService is the minimal capability the feed handlers need from internal/feed.Service -- a
// structural interface so feed_handler_test.go can substitute a stub with no database, mirroring
// eventsService's precedent from plan 04.1-10. *feed.Service satisfies this with no explicit
// declaration required.
type feedsService interface {
	GroupFeed(ctx context.Context, userID, groupID uuid.UUID, cursor string, limit int) (feed.Page, error)
	EventFeed(ctx context.Context, userID, eventID uuid.UUID, cursor string, limit int) (feed.Page, error)
	SendCheer(ctx context.Context, userID, completionID uuid.UUID, cheer string) error
	WithdrawCheer(ctx context.Context, userID, completionID uuid.UUID, cheer string) error
	RequestExportConsent(ctx context.Context, ownerUserID, photoAssetID uuid.UUID, subjectUserIDs []uuid.UUID) error
	GrantExportConsent(ctx context.Context, subjectUserID, photoAssetID uuid.UUID) error
	ExportAllowed(ctx context.Context, exporterUserID, photoAssetID uuid.UUID) (feed.ExportGate, error)
}

// Wire types for the routes this file adds. Every mutating route's acting user id comes from
// RequireSession's context, never a request body field (T-04.1-35), matching every other handler
// file from this phase.
//
// feed.Page and feed.Item, not a second translation struct, ARE the wire contract for the two feed
// routes -- they already carry json tags for exactly this purpose, and internal/feed's own
// nodenominator_test.go pins their exact JSON key set. Encoding them directly here means there is
// only ever one struct definition to keep GROUPEVENTS-04's shape promise true, not two that could
// drift apart.

// CheerRequest is the entire request body for POST/DELETE /v1/completions/{id}/cheers.
type CheerRequest struct {
	Cheer string `json:"cheer"`
}

// RequestExportConsentRequest is the entire request body for
// POST /v1/photos/{id}/export-consent/request.
type RequestExportConsentRequest struct {
	SubjectUserIDs []string `json:"subjectUserIds"`
}

// ExportConsentResponse is returned by both the request/grant routes (on success) and the GET
// status route -- the caller's current view of whether photoAssetID may leave Ritham, and exactly
// who is still outstanding when it may not.
type ExportConsentResponse struct {
	Allowed            bool     `json:"allowed"`
	AwaitingSubjectIDs []string `json:"awaitingSubjectIds"`
}

func handleGroupFeed(svc feedsService) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID, ok := UserIDFromContext(r.Context())
		if !ok {
			writeJSONError(w, http.StatusUnauthorized, "authentication failed")
			return
		}

		groupID, err := uuid.Parse(r.PathValue("id"))
		if err != nil {
			writeJSONError(w, http.StatusBadRequest, "invalid group id")
			return
		}

		page, err := svc.GroupFeed(r.Context(), userID, groupID, r.URL.Query().Get("cursor"), feedLimitFromQuery(r))
		if err != nil {
			writeJSONError(w, statusForFeedError(err), feedErrorMessage(err))
			return
		}

		writeJSON(w, http.StatusOK, page)
	}
}

func handleEventFeed(svc feedsService) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID, ok := UserIDFromContext(r.Context())
		if !ok {
			writeJSONError(w, http.StatusUnauthorized, "authentication failed")
			return
		}

		eventID, err := uuid.Parse(r.PathValue("id"))
		if err != nil {
			writeJSONError(w, http.StatusBadRequest, "invalid event id")
			return
		}

		page, err := svc.EventFeed(r.Context(), userID, eventID, r.URL.Query().Get("cursor"), feedLimitFromQuery(r))
		if err != nil {
			writeJSONError(w, statusForFeedError(err), feedErrorMessage(err))
			return
		}

		writeJSON(w, http.StatusOK, page)
	}
}

func handleSendCheer(svc feedsService) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID, completionID, req, ok := userCompletionIDAndCheer(w, r)
		if !ok {
			return
		}

		if err := svc.SendCheer(r.Context(), userID, completionID, req.Cheer); err != nil {
			writeJSONError(w, statusForFeedError(err), feedErrorMessage(err))
			return
		}

		w.WriteHeader(http.StatusNoContent)
	}
}

func handleWithdrawCheer(svc feedsService) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID, completionID, req, ok := userCompletionIDAndCheer(w, r)
		if !ok {
			return
		}

		if err := svc.WithdrawCheer(r.Context(), userID, completionID, req.Cheer); err != nil {
			writeJSONError(w, statusForFeedError(err), feedErrorMessage(err))
			return
		}

		w.WriteHeader(http.StatusNoContent)
	}
}

func handleRequestExportConsent(svc feedsService) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID, photoAssetID, ok := userAndPhotoAssetID(w, r)
		if !ok {
			return
		}

		var req RequestExportConsentRequest
		if err := decodeJSONBody(w, r, maxRequestBodyBytes, &req); err != nil {
			writeJSONError(w, http.StatusBadRequest, "invalid request body")
			return
		}

		subjectIDs := make([]uuid.UUID, 0, len(req.SubjectUserIDs))
		for _, raw := range req.SubjectUserIDs {
			id, err := uuid.Parse(raw)
			if err != nil {
				writeJSONError(w, http.StatusBadRequest, "invalid subjectUserIds entry")
				return
			}
			subjectIDs = append(subjectIDs, id)
		}

		if err := svc.RequestExportConsent(r.Context(), userID, photoAssetID, subjectIDs); err != nil {
			writeJSONError(w, statusForFeedError(err), feedErrorMessage(err))
			return
		}

		w.WriteHeader(http.StatusNoContent)
	}
}

func handleGrantExportConsent(svc feedsService) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID, photoAssetID, ok := userAndPhotoAssetID(w, r)
		if !ok {
			return
		}

		if err := svc.GrantExportConsent(r.Context(), userID, photoAssetID); err != nil {
			writeJSONError(w, statusForFeedError(err), feedErrorMessage(err))
			return
		}

		w.WriteHeader(http.StatusNoContent)
	}
}

func handleGetExportConsent(svc feedsService) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID, photoAssetID, ok := userAndPhotoAssetID(w, r)
		if !ok {
			return
		}

		gate, err := svc.ExportAllowed(r.Context(), userID, photoAssetID)
		if err != nil {
			writeJSONError(w, statusForFeedError(err), feedErrorMessage(err))
			return
		}

		writeJSON(w, http.StatusOK, exportConsentResponse(gate))
	}
}

// userCompletionIDAndCheer extracts the authenticated user id, the "{id}" path value as a
// completion id, and the decoded CheerRequest body -- shared by the two cheer routes.
func userCompletionIDAndCheer(w http.ResponseWriter, r *http.Request) (userID, completionID uuid.UUID, req CheerRequest, ok bool) {
	userID, authOK := UserIDFromContext(r.Context())
	if !authOK {
		writeJSONError(w, http.StatusUnauthorized, "authentication failed")
		return uuid.UUID{}, uuid.UUID{}, CheerRequest{}, false
	}

	completionID, err := uuid.Parse(r.PathValue("id"))
	if err != nil {
		writeJSONError(w, http.StatusBadRequest, "invalid completion id")
		return uuid.UUID{}, uuid.UUID{}, CheerRequest{}, false
	}

	if err := decodeJSONBody(w, r, maxRequestBodyBytes, &req); err != nil {
		writeJSONError(w, http.StatusBadRequest, "invalid request body")
		return uuid.UUID{}, uuid.UUID{}, CheerRequest{}, false
	}

	return userID, completionID, req, true
}

// userAndPhotoAssetID extracts the authenticated user id and the "{id}" path value as a photo
// asset id -- shared by the three export-consent routes.
func userAndPhotoAssetID(w http.ResponseWriter, r *http.Request) (userID, photoAssetID uuid.UUID, ok bool) {
	userID, authOK := UserIDFromContext(r.Context())
	if !authOK {
		writeJSONError(w, http.StatusUnauthorized, "authentication failed")
		return uuid.UUID{}, uuid.UUID{}, false
	}

	photoAssetID, err := uuid.Parse(r.PathValue("id"))
	if err != nil {
		writeJSONError(w, http.StatusBadRequest, "invalid photo id")
		return uuid.UUID{}, uuid.UUID{}, false
	}

	return userID, photoAssetID, true
}

// feedLimitFromQuery reads the "limit" query parameter. An absent or unparseable value yields 0,
// which feed.Service's own clamping treats as "use the default page size" -- never a 400, matching
// this plan's "requesting a page size above the cap yields the cap rather than an error" rule
// applied symmetrically to a malformed one.
func feedLimitFromQuery(r *http.Request) int {
	raw := r.URL.Query().Get("limit")
	if raw == "" {
		return 0
	}
	n, err := strconv.Atoi(raw)
	if err != nil {
		return 0
	}
	return n
}

// exportConsentResponse converts a feed.ExportGate to its wire shape.
func exportConsentResponse(g feed.ExportGate) ExportConsentResponse {
	ids := make([]string, 0, len(g.AwaitingSubjectIDs))
	for _, id := range g.AwaitingSubjectIDs {
		ids = append(ids, id.String())
	}
	return ExportConsentResponse{Allowed: g.Allowed, AwaitingSubjectIDs: ids}
}

// statusForFeedError maps every one of feed's exported sentinel errors to an HTTP status.
// not-a-member is 404 (never 403, which would itself confirm the group/event/completion exists,
// matching events' own T-04.1-57 precedent); unknown cheer is 400 (client-correctable input);
// consent-missing is 409 (a state conflict: nothing pending to grant); not-photo-owner is 403 per
// this plan's own explicit instruction -- a deliberate divergence from statusForEventsError's
// photo-not-owned-is-404 precedent, recorded in 04.1-12-SUMMARY.md's Threat Flags. Anything else
// is 500.
func statusForFeedError(err error) int {
	switch {
	case errors.Is(err, feed.ErrNotAMember):
		return http.StatusNotFound
	case errors.Is(err, feed.ErrUnknownCheer):
		return http.StatusBadRequest
	case errors.Is(err, feed.ErrExportConsentMissing):
		return http.StatusConflict
	case errors.Is(err, feed.ErrNotPhotoOwner):
		return http.StatusForbidden
	default:
		return http.StatusInternalServerError
	}
}

// feedErrorMessage returns a response body message for a feed error. Every sentinel below
// describes itself; anything else gets the generic internal-error message.
func feedErrorMessage(err error) string {
	switch {
	case errors.Is(err, feed.ErrNotAMember),
		errors.Is(err, feed.ErrUnknownCheer),
		errors.Is(err, feed.ErrExportConsentMissing),
		errors.Is(err, feed.ErrNotPhotoOwner):
		return err.Error()
	default:
		return "internal error"
	}
}
