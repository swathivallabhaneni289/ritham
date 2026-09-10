package httpapi

import (
	"context"
	"errors"
	"net/http"
	"time"

	"github.com/google/uuid"

	"github.com/swathivallabhaneni289/ritham/RithamService/internal/events"
	"github.com/swathivallabhaneni289/ritham/RithamService/internal/groups"
)

// dateLayout is the wire format for Goal-Event StartsOn/EndsOn -- a calendar date, matching the
// underlying `date` column (no time-of-day, no timezone offset).
const dateLayout = "2006-01-02"

// eventsService is the minimal capability the events handlers need from internal/events.Service --
// a structural interface so events_handler_test.go can substitute a stub with no database,
// mirroring groupsService's and friendsService's precedent from this same phase.
// *events.Service satisfies this with no explicit declaration required.
type eventsService interface {
	Create(ctx context.Context, organizerUserID, groupID uuid.UUID, in events.NewGoalEvent) (events.GoalEvent, error)
	List(ctx context.Context, userID, groupID uuid.UUID) ([]events.GoalEvent, error)
	Get(ctx context.Context, userID, eventID uuid.UUID) (events.GoalEvent, error)
	RSVP(ctx context.Context, userID, eventID uuid.UUID) (events.RSVPState, error)
	WithdrawRSVP(ctx context.Context, userID, eventID uuid.UUID) (events.RSVPState, error)
	RSVPState(ctx context.Context, userID, eventID uuid.UUID) (events.RSVPState, error)
	LogCompletion(ctx context.Context, userID, eventID uuid.UUID, in events.NewCompletion) (events.Completion, error)
	Completions(ctx context.Context, userID, eventID uuid.UUID) ([]events.Completion, error)
}

// Wire types for the Goal-Events feature. Declared here, alongside the handlers that
// produce/consume them, following friends_handler.go's and groups_handler.go's own precedent from
// this same phase.
//
// No request type below has a field naming the acting user -- every acting user id comes from
// RequireSession's context, never the request body (T-04.1-35).

// CreateEventRequest is the entire request body for POST /v1/groups/{id}/events.
// TargetValue is nil unless TargetKind is "distance" or "duration".
type CreateEventRequest struct {
	Name         string   `json:"name"`
	ActivityType string   `json:"activityType"`
	TargetKind   string   `json:"targetKind"`
	TargetValue  *float64 `json:"targetValue"`
	StartsOn     string   `json:"startsOn"`
	EndsOn       string   `json:"endsOn"`
}

// EventResponse describes one goal_events row, from the caller's own point of view.
type EventResponse struct {
	ID              string   `json:"id"`
	GroupID         string   `json:"groupId"`
	Name            string   `json:"name"`
	ActivityType    string   `json:"activityType"`
	TargetKind      string   `json:"targetKind"`
	TargetValue     *float64 `json:"targetValue,omitempty"`
	StartsOn        string   `json:"startsOn"`
	EndsOn          string   `json:"endsOn"`
	OrganizerUserID string   `json:"organizerUserId"`
	CreatedAt       string   `json:"createdAt"`
}

// EventsListResponse is returned by GET /v1/groups/{id}/events.
type EventsListResponse struct {
	Events []EventResponse `json:"events"`
}

// RSVPStateResponse is returned by every RSVP route -- a count and the viewer's own membership in
// it, mirroring events.RSVPState's own deliberate absence of a per-person roster
// (docs/group-events.md §2).
type RSVPStateResponse struct {
	Count      int  `json:"count"`
	ViewerIsIn bool `json:"viewerIsIn"`
}

// CompletionRequest is the entire request body for POST /v1/events/{id}/completions
// (GROUPEVENTS-02) -- the most important type in this phase's wire surface. It has exactly five
// fields:
//
//   - completedAt: an RFC3339 timestamp naming when the caller finished. Required.
//   - ownTimeSeconds: optional, off by default, the caller's own choice each time -- never
//     inferred, never required (docs/group-events.md §2's "adding your own time is entirely
//     your choice").
//   - photoAssetId: an optional reference to a photo asset this user already uploaded and owns
//     (POST /v1/photos) -- ownership is verified server-side before this completion is stored;
//     a reference to an asset the caller doesn't own is rejected outright.
//   - placeName: an optional, free-text, already-generalized place name -- never a pin, never
//     coordinates (§3's "named place, never a pin" default).
//   - caption: an optional free-text caption.
//
// This struct has no field for a personal distance, pace, or route, and never will -- GROUPEVENTS-02
// keeps that data in the user's own private log by construction, not by a filter that could be
// got wrong. The field count and JSON tag names below are asserted by reflection in
// events_handler_test.go, so widening this boundary later fails a test gate rather than shipping
// silently.
//
// <!-- planner-discipline-allow: distance|pace|route -->
type CompletionRequest struct {
	CompletedAt    string  `json:"completedAt"`
	OwnTimeSeconds *int    `json:"ownTimeSeconds"`
	PhotoAssetID   *string `json:"photoAssetId"`
	PlaceName      *string `json:"placeName"`
	Caption        *string `json:"caption"`
}

// CompletionResponse describes one event_completions row, joined with its author's identity.
// Every optional field uses `omitempty`: a completion logged without an own time has no
// "ownTimeSeconds" key on the wire at all (not a null value), so the with-time and without-time
// responses differ by exactly the presence of that one key -- never by any other field, and never
// by a position, total, or completed-count field, since Completion itself carries none.
type CompletionResponse struct {
	ID             string  `json:"id"`
	EventID        string  `json:"eventId"`
	UserID         string  `json:"userId"`
	DisplayName    string  `json:"displayName"`
	CompletedAt    string  `json:"completedAt"`
	OwnTimeSeconds *int    `json:"ownTimeSeconds,omitempty"`
	PhotoAssetID   *string `json:"photoAssetId,omitempty"`
	PlaceName      *string `json:"placeName,omitempty"`
	Caption        *string `json:"caption,omitempty"`
	PostedAt       string  `json:"postedAt"`
}

// CompletionsListResponse is returned by GET /v1/events/{id}/completions -- in post order only
// (see events.Service.Completions), never re-sortable, never carrying a headcount denominator
// alongside it (docs/group-events.md §2's non-completion rule).
type CompletionsListResponse struct {
	Completions []CompletionResponse `json:"completions"`
}

// knownTargetKinds is the closed set of target-kind values accepted on the wire -- exactly the
// three events.TargetKind* constants, no others.
var knownTargetKinds = map[string]bool{
	events.TargetKindNone:     true,
	events.TargetKindDistance: true,
	events.TargetKindDuration: true,
}

func handleCreateEvent(svc eventsService) http.HandlerFunc {
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

		var req CreateEventRequest
		if err := decodeJSONBody(w, r, maxRequestBodyBytes, &req); err != nil {
			writeJSONError(w, http.StatusBadRequest, "invalid request body")
			return
		}

		if !knownTargetKinds[req.TargetKind] {
			writeJSONError(w, http.StatusBadRequest, "invalid targetKind")
			return
		}

		startsOn, err := time.Parse(dateLayout, req.StartsOn)
		if err != nil {
			writeJSONError(w, http.StatusBadRequest, "invalid startsOn")
			return
		}
		endsOn, err := time.Parse(dateLayout, req.EndsOn)
		if err != nil {
			writeJSONError(w, http.StatusBadRequest, "invalid endsOn")
			return
		}

		e, err := svc.Create(r.Context(), userID, groupID, events.NewGoalEvent{
			Name:         req.Name,
			ActivityType: req.ActivityType,
			TargetKind:   req.TargetKind,
			TargetValue:  req.TargetValue,
			StartsOn:     startsOn,
			EndsOn:       endsOn,
		})
		if err != nil {
			writeJSONError(w, statusForEventsError(err), eventsErrorMessage(err))
			return
		}

		writeJSON(w, http.StatusOK, eventResponse(e))
	}
}

func handleListEvents(svc eventsService) http.HandlerFunc {
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

		list, err := svc.List(r.Context(), userID, groupID)
		if err != nil {
			writeJSONError(w, statusForEventsError(err), eventsErrorMessage(err))
			return
		}

		resp := EventsListResponse{Events: []EventResponse{}}
		for _, e := range list {
			resp.Events = append(resp.Events, eventResponse(e))
		}
		writeJSON(w, http.StatusOK, resp)
	}
}

func handleGetEvent(svc eventsService) http.HandlerFunc {
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

		e, err := svc.Get(r.Context(), userID, eventID)
		if err != nil {
			writeJSONError(w, statusForEventsError(err), eventsErrorMessage(err))
			return
		}

		writeJSON(w, http.StatusOK, eventResponse(e))
	}
}

func handleRSVP(svc eventsService) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID, eventID, ok := userAndEventID(w, r)
		if !ok {
			return
		}

		state, err := svc.RSVP(r.Context(), userID, eventID)
		if err != nil {
			writeJSONError(w, statusForEventsError(err), eventsErrorMessage(err))
			return
		}

		writeJSON(w, http.StatusOK, rsvpStateResponse(state))
	}
}

func handleWithdrawRSVP(svc eventsService) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID, eventID, ok := userAndEventID(w, r)
		if !ok {
			return
		}

		state, err := svc.WithdrawRSVP(r.Context(), userID, eventID)
		if err != nil {
			writeJSONError(w, statusForEventsError(err), eventsErrorMessage(err))
			return
		}

		writeJSON(w, http.StatusOK, rsvpStateResponse(state))
	}
}

func handleGetRSVPState(svc eventsService) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID, eventID, ok := userAndEventID(w, r)
		if !ok {
			return
		}

		state, err := svc.RSVPState(r.Context(), userID, eventID)
		if err != nil {
			writeJSONError(w, statusForEventsError(err), eventsErrorMessage(err))
			return
		}

		writeJSON(w, http.StatusOK, rsvpStateResponse(state))
	}
}

func handleLogCompletion(svc eventsService) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID, eventID, ok := userAndEventID(w, r)
		if !ok {
			return
		}

		var req CompletionRequest
		if err := decodeJSONBody(w, r, maxRequestBodyBytes, &req); err != nil {
			writeJSONError(w, http.StatusBadRequest, "invalid request body")
			return
		}

		completedAt, err := time.Parse(time.RFC3339, req.CompletedAt)
		if err != nil {
			writeJSONError(w, http.StatusBadRequest, "invalid completedAt")
			return
		}

		var photoAssetID *uuid.UUID
		if req.PhotoAssetID != nil {
			parsed, err := uuid.Parse(*req.PhotoAssetID)
			if err != nil {
				writeJSONError(w, http.StatusBadRequest, "invalid photoAssetId")
				return
			}
			photoAssetID = &parsed
		}

		c, err := svc.LogCompletion(r.Context(), userID, eventID, events.NewCompletion{
			CompletedAt:    completedAt,
			OwnTimeSeconds: req.OwnTimeSeconds,
			PhotoAssetID:   photoAssetID,
			PlaceName:      req.PlaceName,
			Caption:        req.Caption,
		})
		if err != nil {
			writeJSONError(w, statusForEventsError(err), eventsErrorMessage(err))
			return
		}

		writeJSON(w, http.StatusOK, completionResponse(c))
	}
}

func handleListCompletions(svc eventsService) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID, eventID, ok := userAndEventID(w, r)
		if !ok {
			return
		}

		list, err := svc.Completions(r.Context(), userID, eventID)
		if err != nil {
			writeJSONError(w, statusForEventsError(err), eventsErrorMessage(err))
			return
		}

		resp := CompletionsListResponse{Completions: []CompletionResponse{}}
		for _, c := range list {
			resp.Completions = append(resp.Completions, completionResponse(c))
		}
		writeJSON(w, http.StatusOK, resp)
	}
}

// userAndEventID extracts the authenticated user id and the "{id}" path value as an eventID,
// writing the appropriate error response and returning ok=false on either failure -- shared by
// every route below the /v1/events/{id}/... prefix.
func userAndEventID(w http.ResponseWriter, r *http.Request) (userID, eventID uuid.UUID, ok bool) {
	userID, authOK := UserIDFromContext(r.Context())
	if !authOK {
		writeJSONError(w, http.StatusUnauthorized, "authentication failed")
		return uuid.UUID{}, uuid.UUID{}, false
	}

	eventID, err := uuid.Parse(r.PathValue("id"))
	if err != nil {
		writeJSONError(w, http.StatusBadRequest, "invalid event id")
		return uuid.UUID{}, uuid.UUID{}, false
	}

	return userID, eventID, true
}

// eventResponse converts an events.GoalEvent to its wire shape.
func eventResponse(e events.GoalEvent) EventResponse {
	return EventResponse{
		ID:              e.ID.String(),
		GroupID:         e.GroupID.String(),
		Name:            e.Name,
		ActivityType:    e.ActivityType,
		TargetKind:      e.TargetKind,
		TargetValue:     e.TargetValue,
		StartsOn:        e.StartsOn.UTC().Format(dateLayout),
		EndsOn:          e.EndsOn.UTC().Format(dateLayout),
		OrganizerUserID: e.OrganizerUserID.String(),
		CreatedAt:       e.CreatedAt.UTC().Format(time.RFC3339),
	}
}

// rsvpStateResponse converts an events.RSVPState to its wire shape.
func rsvpStateResponse(s events.RSVPState) RSVPStateResponse {
	return RSVPStateResponse{Count: s.Count, ViewerIsIn: s.ViewerIsIn}
}

// completionResponse converts an events.Completion to its wire shape.
func completionResponse(c events.Completion) CompletionResponse {
	resp := CompletionResponse{
		ID:             c.ID.String(),
		EventID:        c.EventID.String(),
		UserID:         c.User.UserID.String(),
		DisplayName:    c.User.DisplayName,
		CompletedAt:    c.CompletedAt.UTC().Format(time.RFC3339),
		OwnTimeSeconds: c.OwnTimeSeconds,
		PlaceName:      c.PlaceName,
		Caption:        c.Caption,
		PostedAt:       c.PostedAt.UTC().Format(time.RFC3339),
	}
	if c.PhotoAssetID != nil {
		s := c.PhotoAssetID.String()
		resp.PhotoAssetID = &s
	}
	return resp
}

// statusForEventsError maps every one of events' exported sentinel errors, plus
// groups.ErrNotAMember (the membership gate's own sentinel, surfaced unchanged by every
// events.Service method), to an HTTP status. Outside-window, name/caption/place-name-too-long,
// invalid own time, invalid target, invalid event window, and unknown activity type are all
// client-correctable input errors (400). Already-completed is a state conflict (409). Unknown
// event, non-membership, and photo-not-owned are all 404 -- never 403, which would itself confirm
// the event or group exists (T-04.1-57). Anything else is 500.
func statusForEventsError(err error) int {
	switch {
	case errors.Is(err, events.ErrOutsideEventWindow),
		errors.Is(err, events.ErrNameTooLong),
		errors.Is(err, events.ErrCaptionTooLong),
		errors.Is(err, events.ErrPlaceNameTooLong),
		errors.Is(err, events.ErrInvalidOwnTime),
		errors.Is(err, events.ErrUnknownActivityType),
		errors.Is(err, events.ErrInvalidTarget),
		errors.Is(err, events.ErrInvalidEventWindow):
		return http.StatusBadRequest
	case errors.Is(err, events.ErrAlreadyCompleted):
		return http.StatusConflict
	case errors.Is(err, events.ErrUnknownEvent),
		errors.Is(err, events.ErrPhotoNotOwned),
		errors.Is(err, groups.ErrNotAMember):
		return http.StatusNotFound
	default:
		return http.StatusInternalServerError
	}
}

// eventsErrorMessage returns a response body message for an events error. Every sentinel below
// describes itself; groups.ErrNotAMember reuses its own message (already identical whether the
// group/event exists or not, per T-04.1-45/T-04.1-57).
func eventsErrorMessage(err error) string {
	switch {
	case errors.Is(err, events.ErrOutsideEventWindow),
		errors.Is(err, events.ErrNameTooLong),
		errors.Is(err, events.ErrCaptionTooLong),
		errors.Is(err, events.ErrPlaceNameTooLong),
		errors.Is(err, events.ErrInvalidOwnTime),
		errors.Is(err, events.ErrUnknownActivityType),
		errors.Is(err, events.ErrInvalidTarget),
		errors.Is(err, events.ErrInvalidEventWindow),
		errors.Is(err, events.ErrAlreadyCompleted),
		errors.Is(err, events.ErrUnknownEvent),
		errors.Is(err, events.ErrPhotoNotOwned),
		errors.Is(err, groups.ErrNotAMember):
		return err.Error()
	default:
		return "internal error"
	}
}
