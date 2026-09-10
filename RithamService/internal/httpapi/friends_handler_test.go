package httpapi

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/swathivallabhaneni289/ritham/RithamService/internal/friends"
)

// stubFriendsService lets the friends handler tests exercise every response-shaping branch with
// no database, mirroring photo_handler_test.go's stubPhotoIngester precedent from this same
// phase. Each *Func field defaults to nil; a handler test that reaches an unset field will panic
// with a nil-pointer dereference, which is itself a useful signal that a test called further into
// the stub than intended (e.g. the unauthenticated-request tests below, where no *Func should
// ever be invoked).
type stubFriendsService struct {
	sendRequestFunc     func(ctx context.Context, fromUserID, toUserID uuid.UUID, path friends.ConnectionPath) (friends.Request, error)
	acceptFunc          func(ctx context.Context, userID, requestID uuid.UUID) (friends.Friendship, error)
	declineFunc         func(ctx context.Context, userID, requestID uuid.UUID) error
	incomingFunc        func(ctx context.Context, userID uuid.UUID) ([]friends.Request, error)
	listFunc            func(ctx context.Context, userID uuid.UUID) ([]friends.Friend, error)
	unfriendFunc        func(ctx context.Context, userID, otherUserID uuid.UUID) error
	createInviteFunc    func(ctx context.Context, userID uuid.UUID) (friends.Invite, error)
	redeemInviteFunc    func(ctx context.Context, redeemerUserID uuid.UUID, token string) (friends.Request, error)
	setContactMatchFunc func(ctx context.Context, userID uuid.UUID, optedIn bool, identifierDigests [][]byte) error
	matchContactsFunc   func(ctx context.Context, userID uuid.UUID, candidateDigests [][]byte) ([]friends.Friend, error)
}

func (s *stubFriendsService) SendRequest(ctx context.Context, fromUserID, toUserID uuid.UUID, path friends.ConnectionPath) (friends.Request, error) {
	return s.sendRequestFunc(ctx, fromUserID, toUserID, path)
}

func (s *stubFriendsService) Accept(ctx context.Context, userID, requestID uuid.UUID) (friends.Friendship, error) {
	return s.acceptFunc(ctx, userID, requestID)
}

func (s *stubFriendsService) Decline(ctx context.Context, userID, requestID uuid.UUID) error {
	return s.declineFunc(ctx, userID, requestID)
}

func (s *stubFriendsService) Incoming(ctx context.Context, userID uuid.UUID) ([]friends.Request, error) {
	return s.incomingFunc(ctx, userID)
}

func (s *stubFriendsService) List(ctx context.Context, userID uuid.UUID) ([]friends.Friend, error) {
	return s.listFunc(ctx, userID)
}

func (s *stubFriendsService) Unfriend(ctx context.Context, userID, otherUserID uuid.UUID) error {
	return s.unfriendFunc(ctx, userID, otherUserID)
}

func (s *stubFriendsService) CreateInvite(ctx context.Context, userID uuid.UUID) (friends.Invite, error) {
	return s.createInviteFunc(ctx, userID)
}

func (s *stubFriendsService) RedeemInvite(ctx context.Context, redeemerUserID uuid.UUID, token string) (friends.Request, error) {
	return s.redeemInviteFunc(ctx, redeemerUserID, token)
}

func (s *stubFriendsService) SetContactMatchOptIn(ctx context.Context, userID uuid.UUID, optedIn bool, identifierDigests [][]byte) error {
	return s.setContactMatchFunc(ctx, userID, optedIn, identifierDigests)
}

func (s *stubFriendsService) MatchContacts(ctx context.Context, userID uuid.UUID, candidateDigests [][]byte) ([]friends.Friend, error) {
	return s.matchContactsFunc(ctx, userID, candidateDigests)
}

// friendsRouteCase names one of the ten friends routes together with the handler that serves it,
// for the unauthenticated-returns-401 table test below.
type friendsRouteCase struct {
	name    string
	method  string
	path    string
	handler func(svc friendsService) http.HandlerFunc
}

func friendsRouteCases() []friendsRouteCase {
	return []friendsRouteCase{
		{"send request", http.MethodPost, "/v1/friends/requests", handleSendFriendRequest},
		{"accept", http.MethodPost, "/v1/friends/requests/{id}/accept", handleAcceptFriendRequest},
		{"decline", http.MethodPost, "/v1/friends/requests/{id}/decline", handleDeclineFriendRequest},
		{"list friends", http.MethodGet, "/v1/friends", handleListFriends},
		{"incoming requests", http.MethodGet, "/v1/friends/requests", handleIncomingFriendRequests},
		{"unfriend", http.MethodDelete, "/v1/friends/{userId}", handleUnfriend},
		{"create invite", http.MethodPost, "/v1/invites", handleCreateInvite},
		{"redeem invite", http.MethodPost, "/v1/invites/redeem", handleRedeemInvite},
		{"set contact-match opt-in", http.MethodPut, "/v1/friends/contact-match", handleSetContactMatchOptIn},
		{"contact-match query", http.MethodPost, "/v1/friends/contact-match/query", handleMatchContacts},
	}
}

func TestFriendsRoutes_UnauthenticatedReturns401(t *testing.T) {
	// An empty stub: every *Func field is nil. If any handler under test reached into the
	// service, this stub panics -- proving RequireSession stopped the request before the handler
	// body ran, per T-04.1-13.
	svc := &stubFriendsService{}
	// bearerToken(r) rejects the missing Authorization header before this stub's
	// AuthenticateBearer would ever be reached, so its zero value is never exercised.
	auth := stubAuthenticator{}

	for _, tc := range friendsRouteCases() {
		t.Run(tc.name, func(t *testing.T) {
			handler := RequireSession(auth, tc.handler(svc))
			req := httptest.NewRequest(tc.method, tc.path, nil)
			// Deliberately no Authorization header.
			rec := httptest.NewRecorder()
			handler.ServeHTTP(rec, req)

			if rec.Code != http.StatusUnauthorized {
				t.Errorf("got status %d, want 401 (no Authorization header)", rec.Code)
			}
		})
	}
}

func TestHandleSendFriendRequest_UnexpectedFieldReturns400(t *testing.T) {
	svc := &stubFriendsService{}
	auth := stubAuthenticator{userID: uuid.New()}
	handler := RequireSession(auth, handleSendFriendRequest(svc))

	body := `{"toUserId":"` + uuid.New().String() + `","connectionPath":"direct_share","actingUserId":"sneaky"}`
	req := httptest.NewRequest(http.MethodPost, "/v1/friends/requests", bytes.NewBufferString(body))
	req.Header.Set("Authorization", "Bearer test-token")
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("got status %d, want 400 for an unexpected field", rec.Code)
	}
}

func TestHandleAcceptFriendRequest_AnotherUsersRequestReturns404(t *testing.T) {
	svc := &stubFriendsService{
		acceptFunc: func(ctx context.Context, userID, requestID uuid.UUID) (friends.Friendship, error) {
			return friends.Friendship{}, friends.ErrNoSuchRequest
		},
	}
	auth := stubAuthenticator{userID: uuid.New()}
	handler := RequireSession(auth, handleAcceptFriendRequest(svc))

	requestID := uuid.New()
	req := httptest.NewRequest(http.MethodPost, "/v1/friends/requests/"+requestID.String()+"/accept", nil)
	req.SetPathValue("id", requestID.String())
	req.Header.Set("Authorization", "Bearer test-token")
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusNotFound {
		t.Fatalf("got status %d, want 404 when accepting a request addressed to someone else", rec.Code)
	}
}

func TestHandleSendFriendRequest_ValidRequestReturns200(t *testing.T) {
	fromUserID := uuid.New()
	toUserID := uuid.New()
	now := time.Date(2026, 9, 9, 12, 0, 0, 0, time.UTC)
	svc := &stubFriendsService{
		sendRequestFunc: func(ctx context.Context, from, to uuid.UUID, path friends.ConnectionPath) (friends.Request, error) {
			return friends.Request{
				ID: uuid.New(), FromUserID: from, ToUserID: to,
				State: "pending", ConnectionPath: path, CreatedAt: now,
			}, nil
		},
	}
	auth := stubAuthenticator{userID: fromUserID}
	handler := RequireSession(auth, handleSendFriendRequest(svc))

	body := `{"toUserId":"` + toUserID.String() + `","connectionPath":"direct_share"}`
	req := httptest.NewRequest(http.MethodPost, "/v1/friends/requests", bytes.NewBufferString(body))
	req.Header.Set("Authorization", "Bearer test-token")
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("got status %d, want 200; body: %s", rec.Code, rec.Body.String())
	}
	var resp FriendRequestResponse
	if err := json.Unmarshal(rec.Body.Bytes(), &resp); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if resp.ToUserID != toUserID.String() {
		t.Errorf("ToUserID = %q, want %q", resp.ToUserID, toUserID.String())
	}
}

func TestHandleRedeemInvite_ConsumedAndUnknownInviteResponsesAreByteIdentical(t *testing.T) {
	userID := uuid.New()
	auth := stubAuthenticator{userID: userID}

	consumedSvc := &stubFriendsService{
		redeemInviteFunc: func(ctx context.Context, redeemerUserID uuid.UUID, token string) (friends.Request, error) {
			return friends.Request{}, friends.ErrInviteConsumed
		},
	}
	unknownSvc := &stubFriendsService{
		redeemInviteFunc: func(ctx context.Context, redeemerUserID uuid.UUID, token string) (friends.Request, error) {
			return friends.Request{}, friends.ErrInviteUnknown
		},
	}

	consumedHandler := RequireSession(auth, handleRedeemInvite(consumedSvc))
	unknownHandler := RequireSession(auth, handleRedeemInvite(unknownSvc))

	body := `{"token":"some-token"}`

	consumedReq := httptest.NewRequest(http.MethodPost, "/v1/invites/redeem", bytes.NewBufferString(body))
	consumedReq.Header.Set("Authorization", "Bearer test-token")
	consumedRec := httptest.NewRecorder()
	consumedHandler.ServeHTTP(consumedRec, consumedReq)

	unknownReq := httptest.NewRequest(http.MethodPost, "/v1/invites/redeem", bytes.NewBufferString(body))
	unknownReq.Header.Set("Authorization", "Bearer test-token")
	unknownRec := httptest.NewRecorder()
	unknownHandler.ServeHTTP(unknownRec, unknownReq)

	if consumedRec.Code != http.StatusNotFound {
		t.Fatalf("consumed invite: got status %d, want 404", consumedRec.Code)
	}
	if consumedRec.Code != unknownRec.Code {
		t.Fatalf("status codes differ: consumed=%d unknown=%d", consumedRec.Code, unknownRec.Code)
	}
	if !bytes.Equal(consumedRec.Body.Bytes(), unknownRec.Body.Bytes()) {
		t.Errorf("response bodies differ: consumed=%q unknown=%q -- a caller must not be able to distinguish an unknown invite from a used one (T-04.1-31)", consumedRec.Body.String(), unknownRec.Body.String())
	}
}

func TestHandleMatchContacts_OptedOutReturns409(t *testing.T) {
	svc := &stubFriendsService{
		matchContactsFunc: func(ctx context.Context, userID uuid.UUID, candidateDigests [][]byte) ([]friends.Friend, error) {
			return nil, friends.ErrContactMatchOptedOut
		},
	}
	auth := stubAuthenticator{userID: uuid.New()}
	handler := RequireSession(auth, handleMatchContacts(svc))

	req := httptest.NewRequest(http.MethodPost, "/v1/friends/contact-match/query", bytes.NewBufferString(`{"candidateDigests":[]}`))
	req.Header.Set("Authorization", "Bearer test-token")
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusConflict {
		t.Fatalf("got status %d, want 409 for an opted-out caller", rec.Code)
	}
}

func TestHandleUnfriend_SuccessReturns204(t *testing.T) {
	svc := &stubFriendsService{
		unfriendFunc: func(ctx context.Context, userID, otherUserID uuid.UUID) error {
			return nil
		},
	}
	auth := stubAuthenticator{userID: uuid.New()}
	handler := RequireSession(auth, handleUnfriend(svc))

	otherUserID := uuid.New()
	req := httptest.NewRequest(http.MethodDelete, "/v1/friends/"+otherUserID.String(), nil)
	req.SetPathValue("userId", otherUserID.String())
	req.Header.Set("Authorization", "Bearer test-token")
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusNoContent {
		t.Fatalf("got status %d, want 204", rec.Code)
	}
}
