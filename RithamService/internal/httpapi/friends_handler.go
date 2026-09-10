package httpapi

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"time"

	"github.com/google/uuid"

	"github.com/swathivallabhaneni289/ritham/RithamService/internal/friends"
)

// maxContactMatchBodyBytes bounds the two contact-match routes' request bodies, deliberately NOT
// the pre-existing maxRequestBodyBytes (64 KiB) -- that bound is sized for a three-field JSON body
// and would 413 a legitimate submission at friends.maxContactDigestsPerRequest (2000 digests):
// each 32-byte digest marshals as ~44 base64 characters plus JSON quoting/comma overhead, so 2000
// of them run to roughly 94 KB before this cap's own headroom. Sized well above that so a
// legitimate max-size submission is rejected by SetContactMatchOptIn/MatchContacts' own
// ErrTooManyContactDigests check (a domain 400), never by MaxBytesReader (an opaque body-decode
// 400 that would never let the intended over-cap message through) -- mirrors photo_handler.go's
// maxPhotoUploadBytes precedent for the same reason.
const maxContactMatchBodyBytes = 128 << 10 // 128 KiB

// friendsService is the minimal capability the friends handlers need from internal/friends.Service
// -- a structural interface so friends_handler_test.go can substitute a stub with no database,
// mirroring internal/httpapi/photo_handler.go's photoIngester precedent from this same phase.
// *friends.Service satisfies this with no explicit declaration required.
type friendsService interface {
	SendRequest(ctx context.Context, fromUserID, toUserID uuid.UUID, path friends.ConnectionPath) (friends.Request, error)
	Accept(ctx context.Context, userID, requestID uuid.UUID) (friends.Friendship, error)
	Decline(ctx context.Context, userID, requestID uuid.UUID) error
	Incoming(ctx context.Context, userID uuid.UUID) ([]friends.Request, error)
	List(ctx context.Context, userID uuid.UUID) ([]friends.Friend, error)
	Unfriend(ctx context.Context, userID, otherUserID uuid.UUID) error
	CreateInvite(ctx context.Context, userID uuid.UUID) (friends.Invite, error)
	RedeemInvite(ctx context.Context, redeemerUserID uuid.UUID, token string) (friends.Request, error)
	SetContactMatchOptIn(ctx context.Context, userID uuid.UUID, optedIn bool, identifierDigests [][]byte) error
	MatchContacts(ctx context.Context, userID uuid.UUID, candidateDigests [][]byte) ([]friends.Friend, error)
}

// Wire types for the friends feature. Declared here, alongside the handlers that produce/consume
// them, rather than in contract.go -- contract.go stays scoped to the pre-existing locked
// workout-plan boundary and its own reflection test (04.1-RESEARCH.md Pitfall 4), following
// photo_handler.go's PhotoUploadResponse precedent from this same phase.
//
// No request type below has a field naming the acting user -- every acting user id comes from
// RequireSession's context, never the request body (T-04.1-35).

// SendFriendRequestRequest is the entire request body for POST /v1/friends/requests.
type SendFriendRequestRequest struct {
	ToUserID       string `json:"toUserId"`
	ConnectionPath string `json:"connectionPath"`
}

// FriendRequestResponse describes one friend_requests row. FromDisplayName is populated only for
// GET /v1/friends/requests (Incoming's own JOIN) -- empty for the send/redeem responses, which
// have no consumer needing the requester's own name rendered. Not in this plan's original wire
// shape; added alongside friends.Request.FromDisplayName (Rule 3) since plan 04.1-09's own
// must_haves truth ("a friend row shows a name") has no other source for an incoming request's
// requester name.
type FriendRequestResponse struct {
	ID              string `json:"id"`
	FromUserID      string `json:"fromUserId"`
	FromDisplayName string `json:"fromDisplayName"`
	ToUserID        string `json:"toUserId"`
	State           string `json:"state"`
	ConnectionPath  string `json:"connectionPath"`
	CreatedAt       string `json:"createdAt"`
}

// IncomingRequestsResponse is returned by GET /v1/friends/requests.
type IncomingRequestsResponse struct {
	Requests []FriendRequestResponse `json:"requests"`
}

// AcceptFriendRequestResponse is returned by a successful accept -- the other party's user id and
// when the friendship was established, from the caller's own point of view.
type AcceptFriendRequestResponse struct {
	FriendUserID  string `json:"friendUserId"`
	EstablishedAt string `json:"establishedAt"`
}

// FriendResponse describes one established friend.
type FriendResponse struct {
	UserID        string `json:"userId"`
	DisplayName   string `json:"displayName"`
	EstablishedAt string `json:"establishedAt"`
}

// FriendsListResponse is returned by GET /v1/friends.
type FriendsListResponse struct {
	Friends []FriendResponse `json:"friends"`
}

// CreateInviteResponse is returned by POST /v1/invites. Token is the plaintext bearer value,
// returned exactly once.
type CreateInviteResponse struct {
	Token     string `json:"token"`
	ExpiresAt string `json:"expiresAt"`
}

// RedeemInviteRequest is the entire request body for POST /v1/invites/redeem.
type RedeemInviteRequest struct {
	Token string `json:"token"`
}

// SetContactMatchOptInRequest is the entire request body for PUT /v1/friends/contact-match.
// IdentifierDigests is [][]byte, which encoding/json marshals/unmarshals as an array of base64
// strings -- the wire representation of a client-hashed identifier, never a raw contact value.
type SetContactMatchOptInRequest struct {
	OptedIn           bool     `json:"optedIn"`
	IdentifierDigests [][]byte `json:"identifierDigests"`
}

// MatchContactsRequest is the entire request body for POST /v1/friends/contact-match/query.
type MatchContactsRequest struct {
	CandidateDigests [][]byte `json:"candidateDigests"`
}

// ContactMatchCandidate describes one contact-match result. No EstablishedAt field -- a match
// candidate is not yet a friend.
type ContactMatchCandidate struct {
	UserID      string `json:"userId"`
	DisplayName string `json:"displayName"`
}

// MatchContactsResponse is returned by POST /v1/friends/contact-match/query.
type MatchContactsResponse struct {
	Matches []ContactMatchCandidate `json:"matches"`
}

// knownConnectionPaths is the closed set of connection-path values POST /v1/friends/requests
// accepts -- exactly the three closed-loop paths docs/group-events.md §1 names, no others.
var knownConnectionPaths = map[string]friends.ConnectionPath{
	string(friends.PathContactMatch): friends.PathContactMatch,
	string(friends.PathDirectShare):  friends.PathDirectShare,
}

func handleSendFriendRequest(svc friendsService) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID, ok := UserIDFromContext(r.Context())
		if !ok {
			writeJSONError(w, http.StatusUnauthorized, "authentication failed")
			return
		}

		var req SendFriendRequestRequest
		if err := decodeJSONBody(w, r, maxRequestBodyBytes, &req); err != nil {
			writeJSONError(w, http.StatusBadRequest, "invalid request body")
			return
		}

		toUserID, err := uuid.Parse(req.ToUserID)
		if err != nil {
			writeJSONError(w, http.StatusBadRequest, "invalid toUserId")
			return
		}

		path, ok := knownConnectionPaths[req.ConnectionPath]
		if !ok {
			writeJSONError(w, http.StatusBadRequest, "invalid connectionPath")
			return
		}

		request, err := svc.SendRequest(r.Context(), userID, toUserID, path)
		if err != nil {
			writeJSONError(w, statusForFriendsError(err), friendsErrorMessage(err))
			return
		}

		writeJSON(w, http.StatusOK, friendRequestResponse(request))
	}
}

func handleAcceptFriendRequest(svc friendsService) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID, ok := UserIDFromContext(r.Context())
		if !ok {
			writeJSONError(w, http.StatusUnauthorized, "authentication failed")
			return
		}

		requestID, err := uuid.Parse(r.PathValue("id"))
		if err != nil {
			writeJSONError(w, http.StatusBadRequest, "invalid request id")
			return
		}

		friendship, err := svc.Accept(r.Context(), userID, requestID)
		if err != nil {
			writeJSONError(w, statusForFriendsError(err), friendsErrorMessage(err))
			return
		}

		friendUserID := friendship.UserAID
		if friendUserID == userID {
			friendUserID = friendship.UserBID
		}

		writeJSON(w, http.StatusOK, AcceptFriendRequestResponse{
			FriendUserID:  friendUserID.String(),
			EstablishedAt: friendship.EstablishedAt.UTC().Format(time.RFC3339),
		})
	}
}

func handleDeclineFriendRequest(svc friendsService) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID, ok := UserIDFromContext(r.Context())
		if !ok {
			writeJSONError(w, http.StatusUnauthorized, "authentication failed")
			return
		}

		requestID, err := uuid.Parse(r.PathValue("id"))
		if err != nil {
			writeJSONError(w, http.StatusBadRequest, "invalid request id")
			return
		}

		if err := svc.Decline(r.Context(), userID, requestID); err != nil {
			writeJSONError(w, statusForFriendsError(err), friendsErrorMessage(err))
			return
		}

		w.WriteHeader(http.StatusNoContent)
	}
}

func handleListFriends(svc friendsService) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID, ok := UserIDFromContext(r.Context())
		if !ok {
			writeJSONError(w, http.StatusUnauthorized, "authentication failed")
			return
		}

		friendsList, err := svc.List(r.Context(), userID)
		if err != nil {
			writeJSONError(w, http.StatusInternalServerError, "internal error")
			return
		}

		resp := FriendsListResponse{Friends: []FriendResponse{}}
		for _, f := range friendsList {
			resp.Friends = append(resp.Friends, FriendResponse{
				UserID:        f.UserID.String(),
				DisplayName:   f.DisplayName,
				EstablishedAt: f.EstablishedAt.UTC().Format(time.RFC3339),
			})
		}

		writeJSON(w, http.StatusOK, resp)
	}
}

func handleIncomingFriendRequests(svc friendsService) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID, ok := UserIDFromContext(r.Context())
		if !ok {
			writeJSONError(w, http.StatusUnauthorized, "authentication failed")
			return
		}

		requests, err := svc.Incoming(r.Context(), userID)
		if err != nil {
			writeJSONError(w, http.StatusInternalServerError, "internal error")
			return
		}

		resp := IncomingRequestsResponse{Requests: []FriendRequestResponse{}}
		for _, req := range requests {
			resp.Requests = append(resp.Requests, friendRequestResponse(req))
		}

		writeJSON(w, http.StatusOK, resp)
	}
}

func handleUnfriend(svc friendsService) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID, ok := UserIDFromContext(r.Context())
		if !ok {
			writeJSONError(w, http.StatusUnauthorized, "authentication failed")
			return
		}

		otherUserID, err := uuid.Parse(r.PathValue("userId"))
		if err != nil {
			writeJSONError(w, http.StatusBadRequest, "invalid userId")
			return
		}

		if err := svc.Unfriend(r.Context(), userID, otherUserID); err != nil {
			writeJSONError(w, statusForFriendsError(err), friendsErrorMessage(err))
			return
		}

		w.WriteHeader(http.StatusNoContent)
	}
}

func handleCreateInvite(svc friendsService) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID, ok := UserIDFromContext(r.Context())
		if !ok {
			writeJSONError(w, http.StatusUnauthorized, "authentication failed")
			return
		}

		invite, err := svc.CreateInvite(r.Context(), userID)
		if err != nil {
			writeJSONError(w, http.StatusInternalServerError, "internal error")
			return
		}

		writeJSON(w, http.StatusOK, CreateInviteResponse{
			Token:     invite.Token,
			ExpiresAt: invite.ExpiresAt.UTC().Format(time.RFC3339),
		})
	}
}

func handleRedeemInvite(svc friendsService) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID, ok := UserIDFromContext(r.Context())
		if !ok {
			writeJSONError(w, http.StatusUnauthorized, "authentication failed")
			return
		}

		var req RedeemInviteRequest
		if err := decodeJSONBody(w, r, maxRequestBodyBytes, &req); err != nil {
			writeJSONError(w, http.StatusBadRequest, "invalid request body")
			return
		}

		request, err := svc.RedeemInvite(r.Context(), userID, req.Token)
		if err != nil {
			writeJSONError(w, statusForFriendsError(err), friendsErrorMessage(err))
			return
		}

		writeJSON(w, http.StatusOK, friendRequestResponse(request))
	}
}

func handleSetContactMatchOptIn(svc friendsService) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID, ok := UserIDFromContext(r.Context())
		if !ok {
			writeJSONError(w, http.StatusUnauthorized, "authentication failed")
			return
		}

		var req SetContactMatchOptInRequest
		if err := decodeJSONBody(w, r, maxContactMatchBodyBytes, &req); err != nil {
			writeJSONError(w, http.StatusBadRequest, "invalid request body")
			return
		}

		if err := svc.SetContactMatchOptIn(r.Context(), userID, req.OptedIn, req.IdentifierDigests); err != nil {
			writeJSONError(w, statusForFriendsError(err), friendsErrorMessage(err))
			return
		}

		w.WriteHeader(http.StatusNoContent)
	}
}

func handleMatchContacts(svc friendsService) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID, ok := UserIDFromContext(r.Context())
		if !ok {
			writeJSONError(w, http.StatusUnauthorized, "authentication failed")
			return
		}

		var req MatchContactsRequest
		if err := decodeJSONBody(w, r, maxContactMatchBodyBytes, &req); err != nil {
			writeJSONError(w, http.StatusBadRequest, "invalid request body")
			return
		}

		matches, err := svc.MatchContacts(r.Context(), userID, req.CandidateDigests)
		if err != nil {
			writeJSONError(w, statusForFriendsError(err), friendsErrorMessage(err))
			return
		}

		resp := MatchContactsResponse{Matches: []ContactMatchCandidate{}}
		for _, m := range matches {
			resp.Matches = append(resp.Matches, ContactMatchCandidate{
				UserID:      m.UserID.String(),
				DisplayName: m.DisplayName,
			})
		}

		writeJSON(w, http.StatusOK, resp)
	}
}

// friendRequestResponse converts a friends.Request to its wire shape -- shared by every handler
// that returns one (send, redeem-invite, and the incoming-requests list) so the shape can never
// drift between call sites.
func friendRequestResponse(req friends.Request) FriendRequestResponse {
	return FriendRequestResponse{
		ID:              req.ID.String(),
		FromUserID:      req.FromUserID.String(),
		FromDisplayName: req.FromDisplayName,
		ToUserID:        req.ToUserID.String(),
		State:           req.State,
		ConnectionPath:  string(req.ConnectionPath),
		CreatedAt:       req.CreatedAt.UTC().Format(time.RFC3339),
	}
}

// decodeJSONBody reads and decodes r's body into dst, capped at maxBytes and rejecting any
// unknown field -- the same MaxBytesReader + DisallowUnknownFields discipline every other decode
// helper in this package uses, generalized so each of this file's ten handlers does not repeat it.
func decodeJSONBody(w http.ResponseWriter, r *http.Request, maxBytes int64, dst any) error {
	r.Body = http.MaxBytesReader(w, r.Body, maxBytes)
	decoder := json.NewDecoder(r.Body)
	decoder.DisallowUnknownFields()
	return decoder.Decode(dst)
}

// writeJSON marshals body and writes it with status, mirroring every other handler's inline
// encode step in this package but without repeating the marshal-error branch in each one.
func writeJSON(w http.ResponseWriter, status int, body any) {
	encoded, err := json.Marshal(body)
	if err != nil {
		writeJSONError(w, http.StatusInternalServerError, "failed to encode response")
		return
	}
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	w.Write(encoded)
}

// friendsInviteNotFoundMessage is returned for all three of unknown/consumed/expired invite
// failures -- byte-identical, so a caller cannot distinguish "this token never existed" from
// "this token existed and was already used" (T-04.1-31).
const friendsInviteNotFoundMessage = "invite not found or already used"

// statusForFriendsError maps every one of friends' exported sentinel errors to an HTTP status,
// mirroring statusForIdentityError/statusForPhotoError's pattern. self-request, already-friends,
// and over-cap map to 400 (client-correctable input errors); unknown/consumed/expired invites all
// map to 404 with one shared message (T-04.1-31); a not-found request maps to 404;
// already-existing-request and not-friends map to 409 (a state conflict, not a missing resource);
// opted-out maps to 409 (Task 3's own literal mapping); anything else maps to 500.
//
// ErrRequestExists, ErrNotFriends, and ErrInviteSelfRedeem are not named in this plan's own
// statusForFriendsError description -- omitted here would fall through to 500 for a legitimate
// client-side condition, which is a Rule 1 bug, not a permissible gap (Rule 2 deviation).
func statusForFriendsError(err error) int {
	switch {
	case errors.Is(err, friends.ErrSelfRequest),
		errors.Is(err, friends.ErrInviteSelfRedeem),
		errors.Is(err, friends.ErrTooManyContactDigests):
		return http.StatusBadRequest
	case errors.Is(err, friends.ErrInviteUnknown),
		errors.Is(err, friends.ErrInviteConsumed),
		errors.Is(err, friends.ErrInviteExpired),
		errors.Is(err, friends.ErrNoSuchRequest):
		return http.StatusNotFound
	case errors.Is(err, friends.ErrAlreadyFriends),
		errors.Is(err, friends.ErrRequestExists),
		errors.Is(err, friends.ErrNotFriends),
		errors.Is(err, friends.ErrContactMatchOptedOut):
		return http.StatusConflict
	default:
		return http.StatusInternalServerError
	}
}

// friendsErrorMessage returns a response body message for a friends error. The three invite
// failure modes share one literal, byte-identical message; every other sentinel describes itself,
// since none of the others carry the same probing risk (T-04.1-31 is specific to invite tokens).
func friendsErrorMessage(err error) string {
	switch {
	case errors.Is(err, friends.ErrInviteUnknown),
		errors.Is(err, friends.ErrInviteConsumed),
		errors.Is(err, friends.ErrInviteExpired):
		return friendsInviteNotFoundMessage
	case errors.Is(err, friends.ErrSelfRequest),
		errors.Is(err, friends.ErrInviteSelfRedeem),
		errors.Is(err, friends.ErrTooManyContactDigests),
		errors.Is(err, friends.ErrAlreadyFriends),
		errors.Is(err, friends.ErrRequestExists),
		errors.Is(err, friends.ErrNotFriends),
		errors.Is(err, friends.ErrContactMatchOptedOut),
		errors.Is(err, friends.ErrNoSuchRequest):
		return err.Error()
	default:
		return "internal error"
	}
}
