package httpapi

import (
	"bytes"
	"context"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/google/uuid"

	"github.com/swathivallabhaneni289/ritham/RithamService/internal/groups"
)

// stubGroupsService lets the groups handler tests exercise every response-shaping branch with no
// database, mirroring friends_handler_test.go's stubFriendsService precedent from this same
// phase. Each *Func field defaults to nil; a handler test that reaches an unset field will panic
// with a nil-pointer dereference, which is itself a useful signal that a test called further into
// the stub than intended (e.g. the unauthenticated-request tests below, where no *Func should
// ever be invoked).
type stubGroupsService struct {
	createFunc           func(ctx context.Context, organizerUserID uuid.UUID, name string, policy groups.RemovalPolicy) (groups.Group, error)
	inviteFunc           func(ctx context.Context, inviterUserID, groupID, inviteeUserID uuid.UUID) (groups.Invitation, error)
	joinFunc             func(ctx context.Context, userID, groupID uuid.UUID) error
	listForUserFunc      func(ctx context.Context, userID uuid.UUID) ([]groups.Group, error)
	getFunc              func(ctx context.Context, userID, groupID uuid.UUID) (groups.GroupDetail, error)
	membersFunc          func(ctx context.Context, userID, groupID uuid.UUID) ([]groups.Member, error)
	leaveFunc            func(ctx context.Context, userID, groupID uuid.UUID, disposition groups.LeaveDisposition) error
	removeMemberFunc     func(ctx context.Context, actorUserID, groupID, targetUserID uuid.UUID) error
	setRemovalPolicyFunc func(ctx context.Context, actorUserID, groupID uuid.UUID, policy groups.RemovalPolicy) error
}

func (s *stubGroupsService) Create(ctx context.Context, organizerUserID uuid.UUID, name string, policy groups.RemovalPolicy) (groups.Group, error) {
	return s.createFunc(ctx, organizerUserID, name, policy)
}

func (s *stubGroupsService) Invite(ctx context.Context, inviterUserID, groupID, inviteeUserID uuid.UUID) (groups.Invitation, error) {
	return s.inviteFunc(ctx, inviterUserID, groupID, inviteeUserID)
}

func (s *stubGroupsService) Join(ctx context.Context, userID, groupID uuid.UUID) error {
	return s.joinFunc(ctx, userID, groupID)
}

func (s *stubGroupsService) ListForUser(ctx context.Context, userID uuid.UUID) ([]groups.Group, error) {
	return s.listForUserFunc(ctx, userID)
}

func (s *stubGroupsService) Get(ctx context.Context, userID, groupID uuid.UUID) (groups.GroupDetail, error) {
	return s.getFunc(ctx, userID, groupID)
}

func (s *stubGroupsService) Members(ctx context.Context, userID, groupID uuid.UUID) ([]groups.Member, error) {
	return s.membersFunc(ctx, userID, groupID)
}

func (s *stubGroupsService) Leave(ctx context.Context, userID, groupID uuid.UUID, disposition groups.LeaveDisposition) error {
	return s.leaveFunc(ctx, userID, groupID, disposition)
}

func (s *stubGroupsService) RemoveMember(ctx context.Context, actorUserID, groupID, targetUserID uuid.UUID) error {
	return s.removeMemberFunc(ctx, actorUserID, groupID, targetUserID)
}

func (s *stubGroupsService) SetRemovalPolicy(ctx context.Context, actorUserID, groupID uuid.UUID, policy groups.RemovalPolicy) error {
	return s.setRemovalPolicyFunc(ctx, actorUserID, groupID, policy)
}

// groupsRouteCase names one of the nine group routes together with the handler that serves it,
// for the unauthenticated-returns-401 table test below.
type groupsRouteCase struct {
	name    string
	method  string
	path    string
	handler func(svc groupsService) http.HandlerFunc
}

func groupsRouteCases() []groupsRouteCase {
	return []groupsRouteCase{
		{"create group", http.MethodPost, "/v1/groups", handleCreateGroup},
		{"list groups", http.MethodGet, "/v1/groups", handleListGroups},
		{"get group", http.MethodGet, "/v1/groups/{id}", handleGetGroup},
		{"list members", http.MethodGet, "/v1/groups/{id}/members", handleListGroupMembers},
		{"invite", http.MethodPost, "/v1/groups/{id}/invitations", handleInviteToGroup},
		{"join", http.MethodPost, "/v1/groups/{id}/join", handleJoinGroup},
		{"leave", http.MethodPost, "/v1/groups/{id}/leave", handleLeaveGroup},
		{"remove member", http.MethodDelete, "/v1/groups/{id}/members/{userId}", handleRemoveGroupMember},
		{"set removal policy", http.MethodPut, "/v1/groups/{id}/removal-policy", handleSetGroupRemovalPolicy},
	}
}

func TestGroupsRoutes_UnauthenticatedReturns401(t *testing.T) {
	// An empty stub: every *Func field is nil. If any handler under test reached into the
	// service, this stub panics -- proving RequireSession stopped the request before the handler
	// body ran, per T-04.1-13.
	svc := &stubGroupsService{}
	// bearerToken(r) rejects the missing Authorization header before this stub's
	// AuthenticateBearer would ever be reached, so its zero value is never exercised.
	auth := stubAuthenticator{}

	for _, tc := range groupsRouteCases() {
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

func TestHandleCreateGroup_UnexpectedFieldReturns400(t *testing.T) {
	svc := &stubGroupsService{}
	auth := stubAuthenticator{userID: uuid.New()}
	handler := RequireSession(auth, handleCreateGroup(svc))

	body := `{"name":"Saturday Crew","removalPolicy":"anyMember","actingUserId":"sneaky"}`
	req := httptest.NewRequest(http.MethodPost, "/v1/groups", bytes.NewBufferString(body))
	req.Header.Set("Authorization", "Bearer test-token")
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("got status %d, want 400 for an unexpected field", rec.Code)
	}
}

func TestHandleGetGroup_NonMemberAndUnknownGroupReturnByteIdentical404(t *testing.T) {
	svc := &stubGroupsService{
		getFunc: func(ctx context.Context, userID, groupID uuid.UUID) (groups.GroupDetail, error) {
			// The stub mirrors groups.Service.Get's own real behavior: an identical sentinel
			// regardless of whether groupID names a real group the caller isn't in, or no group
			// at all -- the handler must not introduce a distinction the service layer doesn't
			// have (T-04.1-45).
			return groups.GroupDetail{}, groups.ErrNotAMember
		},
	}
	auth := stubAuthenticator{userID: uuid.New()}
	handler := RequireSession(auth, handleGetGroup(svc))

	realGroupID := uuid.New()
	req1 := httptest.NewRequest(http.MethodGet, "/v1/groups/"+realGroupID.String(), nil)
	req1.SetPathValue("id", realGroupID.String())
	req1.Header.Set("Authorization", "Bearer test-token")
	rec1 := httptest.NewRecorder()
	handler.ServeHTTP(rec1, req1)

	unknownGroupID := uuid.New()
	req2 := httptest.NewRequest(http.MethodGet, "/v1/groups/"+unknownGroupID.String(), nil)
	req2.SetPathValue("id", unknownGroupID.String())
	req2.Header.Set("Authorization", "Bearer test-token")
	rec2 := httptest.NewRecorder()
	handler.ServeHTTP(rec2, req2)

	if rec1.Code != http.StatusNotFound || rec2.Code != http.StatusNotFound {
		t.Fatalf("got statuses %d and %d, want both 404", rec1.Code, rec2.Code)
	}
	if rec1.Code != rec2.Code || rec1.Body.String() != rec2.Body.String() {
		t.Errorf("a real non-member group and an unknown group must respond byte-identically: %q (%d) vs %q (%d)",
			rec1.Body.String(), rec1.Code, rec2.Body.String(), rec2.Code)
	}
}

func TestHandleLeaveGroup_AcceptsExactlyTheTwoDocumentedDispositions(t *testing.T) {
	for _, disposition := range []string{"keepPosts", "removePosts"} {
		t.Run(disposition, func(t *testing.T) {
			called := false
			svc := &stubGroupsService{
				leaveFunc: func(ctx context.Context, userID, groupID uuid.UUID, gotDisposition groups.LeaveDisposition) error {
					called = true
					if string(gotDisposition) != disposition {
						t.Errorf("Leave called with disposition %q, want %q", gotDisposition, disposition)
					}
					return nil
				},
			}
			auth := stubAuthenticator{userID: uuid.New()}
			handler := RequireSession(auth, handleLeaveGroup(svc))

			groupID := uuid.New()
			body := `{"disposition":"` + disposition + `"}`
			req := httptest.NewRequest(http.MethodPost, "/v1/groups/"+groupID.String()+"/leave", bytes.NewBufferString(body))
			req.SetPathValue("id", groupID.String())
			req.Header.Set("Authorization", "Bearer test-token")
			rec := httptest.NewRecorder()
			handler.ServeHTTP(rec, req)

			if rec.Code != http.StatusNoContent {
				t.Fatalf("got status %d, want 204 for disposition %q", rec.Code, disposition)
			}
			if !called {
				t.Errorf("Leave was never called for a known disposition %q", disposition)
			}
		})
	}
}

func TestHandleLeaveGroup_RejectsAThirdDispositionValue(t *testing.T) {
	svc := &stubGroupsService{}
	auth := stubAuthenticator{userID: uuid.New()}
	handler := RequireSession(auth, handleLeaveGroup(svc))

	groupID := uuid.New()
	body := `{"disposition":"deleteEverything"}`
	req := httptest.NewRequest(http.MethodPost, "/v1/groups/"+groupID.String()+"/leave", bytes.NewBufferString(body))
	req.SetPathValue("id", groupID.String())
	req.Header.Set("Authorization", "Bearer test-token")
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("got status %d, want 400 for an unrecognized disposition (leaveFunc must never be reached)", rec.Code)
	}
}

func TestHandleRemoveGroupMember_RemovalNotPermittedReturns403(t *testing.T) {
	svc := &stubGroupsService{
		removeMemberFunc: func(ctx context.Context, actorUserID, groupID, targetUserID uuid.UUID) error {
			return groups.ErrRemovalNotPermitted
		},
	}
	auth := stubAuthenticator{userID: uuid.New()}
	handler := RequireSession(auth, handleRemoveGroupMember(svc))

	groupID := uuid.New()
	targetUserID := uuid.New()
	req := httptest.NewRequest(http.MethodDelete, "/v1/groups/"+groupID.String()+"/members/"+targetUserID.String(), nil)
	req.SetPathValue("id", groupID.String())
	req.SetPathValue("userId", targetUserID.String())
	req.Header.Set("Authorization", "Bearer test-token")
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusForbidden {
		t.Fatalf("got status %d, want 403 for ErrRemovalNotPermitted", rec.Code)
	}
}

func TestHandleJoinGroup_GroupFullReturns409(t *testing.T) {
	svc := &stubGroupsService{
		joinFunc: func(ctx context.Context, userID, groupID uuid.UUID) error {
			return groups.ErrGroupFull
		},
	}
	auth := stubAuthenticator{userID: uuid.New()}
	handler := RequireSession(auth, handleJoinGroup(svc))

	groupID := uuid.New()
	req := httptest.NewRequest(http.MethodPost, "/v1/groups/"+groupID.String()+"/join", nil)
	req.SetPathValue("id", groupID.String())
	req.Header.Set("Authorization", "Bearer test-token")
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)

	if rec.Code != http.StatusConflict {
		t.Fatalf("got status %d, want 409 for ErrGroupFull", rec.Code)
	}
}
