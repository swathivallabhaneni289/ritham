package httpapi

import (
	"context"
	"errors"
	"net/http"
	"time"

	"github.com/google/uuid"

	"github.com/swathivallabhaneni289/ritham/RithamService/internal/groups"
)

// groupsService is the minimal capability the groups handlers need from internal/groups.Service --
// a structural interface so groups_handler_test.go can substitute a stub with no database,
// mirroring internal/httpapi/friends_handler.go's friendsService precedent from this same phase.
// *groups.Service satisfies this with no explicit declaration required.
type groupsService interface {
	Create(ctx context.Context, organizerUserID uuid.UUID, name string, policy groups.RemovalPolicy) (groups.Group, error)
	Invite(ctx context.Context, inviterUserID, groupID, inviteeUserID uuid.UUID) (groups.Invitation, error)
	Join(ctx context.Context, userID, groupID uuid.UUID) error
	ListForUser(ctx context.Context, userID uuid.UUID) ([]groups.Group, error)
	Get(ctx context.Context, userID, groupID uuid.UUID) (groups.GroupDetail, error)
	Members(ctx context.Context, userID, groupID uuid.UUID) ([]groups.Member, error)
	Leave(ctx context.Context, userID, groupID uuid.UUID, disposition groups.LeaveDisposition) error
	RemoveMember(ctx context.Context, actorUserID, groupID, targetUserID uuid.UUID) error
	SetRemovalPolicy(ctx context.Context, actorUserID, groupID uuid.UUID, policy groups.RemovalPolicy) error
}

// Wire types for the groups feature. Declared here, alongside the handlers that produce/consume
// them, rather than in contract.go -- contract.go stays scoped to the pre-existing locked
// workout-plan boundary, following friends_handler.go's own precedent from this same phase.
//
// No request type below has a field naming the acting user -- every acting user id comes from
// RequireSession's context, never the request body (T-04.1-35).

// CreateGroupRequest is the entire request body for POST /v1/groups. RemovalPolicy is optional;
// an empty string defers to groups.Service.Create's own default (PolicyAnyMember).
type CreateGroupRequest struct {
	Name          string `json:"name"`
	RemovalPolicy string `json:"removalPolicy"`
}

// GroupResponse describes one groups row, from the caller's own point of view.
type GroupResponse struct {
	ID              string `json:"id"`
	Name            string `json:"name"`
	OrganizerUserID string `json:"organizerUserId"`
	RemovalPolicy   string `json:"removalPolicy"`
	CreatedAt       string `json:"createdAt"`
}

// GroupsListResponse is returned by GET /v1/groups.
type GroupsListResponse struct {
	Groups []GroupResponse `json:"groups"`
}

// GroupDetailResponse is returned by GET /v1/groups/{id} -- a GroupResponse plus the group's
// current member count, safe to expose to the group's own members (see groups.GroupDetail's doc
// comment).
type GroupDetailResponse struct {
	GroupResponse
	MemberCount int `json:"memberCount"`
}

// InviteToGroupRequest is the entire request body for POST /v1/groups/{id}/invitations.
type InviteToGroupRequest struct {
	InviteeUserID string `json:"inviteeUserId"`
}

// InvitationResponse describes one group_invitations row.
type InvitationResponse struct {
	GroupID       string `json:"groupId"`
	InviteeUserID string `json:"inviteeUserId"`
	InviterUserID string `json:"inviterUserId"`
	State         string `json:"state"`
	CreatedAt     string `json:"createdAt"`
}

// MemberResponse describes one member of a group's roster.
type MemberResponse struct {
	UserID      string `json:"userId"`
	DisplayName string `json:"displayName"`
	JoinedAt    string `json:"joinedAt"`
}

// GroupMembersResponse is returned by GET /v1/groups/{id}/members.
type GroupMembersResponse struct {
	Members []MemberResponse `json:"members"`
}

// LeaveGroupRequest is the entire request body for POST /v1/groups/{id}/leave. Disposition must
// be exactly one of the two values in knownLeaveDispositions -- the explicit, required choice
// docs/group-events.md §4 asks for, never defaulted either way.
type LeaveGroupRequest struct {
	Disposition string `json:"disposition"`
}

// SetRemovalPolicyRequest is the entire request body for PUT /v1/groups/{id}/removal-policy.
type SetRemovalPolicyRequest struct {
	RemovalPolicy string `json:"removalPolicy"`
}

// knownRemovalPolicies is the closed set of removal-policy values accepted on the wire -- exactly
// the two groups.RemovalPolicy constants, no others.
var knownRemovalPolicies = map[string]groups.RemovalPolicy{
	string(groups.PolicyAnyMember):     groups.PolicyAnyMember,
	string(groups.PolicyOrganizerOnly): groups.PolicyOrganizerOnly,
}

// knownLeaveDispositions is the closed set of leave-disposition values accepted on the wire --
// exactly the two groups.LeaveDisposition constants, no others (T-04.1-49).
var knownLeaveDispositions = map[string]groups.LeaveDisposition{
	string(groups.DispositionKeepPosts):   groups.DispositionKeepPosts,
	string(groups.DispositionRemovePosts): groups.DispositionRemovePosts,
}

func handleCreateGroup(svc groupsService) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID, ok := UserIDFromContext(r.Context())
		if !ok {
			writeJSONError(w, http.StatusUnauthorized, "authentication failed")
			return
		}

		var req CreateGroupRequest
		if err := decodeJSONBody(w, r, maxRequestBodyBytes, &req); err != nil {
			writeJSONError(w, http.StatusBadRequest, "invalid request body")
			return
		}

		policy := groups.RemovalPolicy("")
		if req.RemovalPolicy != "" {
			var known bool
			policy, known = knownRemovalPolicies[req.RemovalPolicy]
			if !known {
				writeJSONError(w, http.StatusBadRequest, "invalid removalPolicy")
				return
			}
		}

		g, err := svc.Create(r.Context(), userID, req.Name, policy)
		if err != nil {
			writeJSONError(w, statusForGroupsError(err), groupsErrorMessage(err))
			return
		}

		writeJSON(w, http.StatusOK, groupResponse(g))
	}
}

func handleListGroups(svc groupsService) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID, ok := UserIDFromContext(r.Context())
		if !ok {
			writeJSONError(w, http.StatusUnauthorized, "authentication failed")
			return
		}

		list, err := svc.ListForUser(r.Context(), userID)
		if err != nil {
			writeJSONError(w, http.StatusInternalServerError, "internal error")
			return
		}

		resp := GroupsListResponse{Groups: []GroupResponse{}}
		for _, g := range list {
			resp.Groups = append(resp.Groups, groupResponse(g))
		}

		writeJSON(w, http.StatusOK, resp)
	}
}

func handleGetGroup(svc groupsService) http.HandlerFunc {
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

		detail, err := svc.Get(r.Context(), userID, groupID)
		if err != nil {
			writeJSONError(w, statusForGroupsError(err), groupsErrorMessage(err))
			return
		}

		writeJSON(w, http.StatusOK, GroupDetailResponse{
			GroupResponse: groupResponse(detail.Group),
			MemberCount:   detail.MemberCount,
		})
	}
}

func handleListGroupMembers(svc groupsService) http.HandlerFunc {
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

		members, err := svc.Members(r.Context(), userID, groupID)
		if err != nil {
			writeJSONError(w, statusForGroupsError(err), groupsErrorMessage(err))
			return
		}

		resp := GroupMembersResponse{Members: []MemberResponse{}}
		for _, m := range members {
			resp.Members = append(resp.Members, MemberResponse{
				UserID:      m.UserID.String(),
				DisplayName: m.DisplayName,
				JoinedAt:    m.JoinedAt.UTC().Format(time.RFC3339),
			})
		}

		writeJSON(w, http.StatusOK, resp)
	}
}

func handleInviteToGroup(svc groupsService) http.HandlerFunc {
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

		var req InviteToGroupRequest
		if err := decodeJSONBody(w, r, maxRequestBodyBytes, &req); err != nil {
			writeJSONError(w, http.StatusBadRequest, "invalid request body")
			return
		}

		inviteeUserID, err := uuid.Parse(req.InviteeUserID)
		if err != nil {
			writeJSONError(w, http.StatusBadRequest, "invalid inviteeUserId")
			return
		}

		invitation, err := svc.Invite(r.Context(), userID, groupID, inviteeUserID)
		if err != nil {
			writeJSONError(w, statusForGroupsError(err), groupsErrorMessage(err))
			return
		}

		writeJSON(w, http.StatusOK, invitationResponse(invitation))
	}
}

func handleJoinGroup(svc groupsService) http.HandlerFunc {
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

		if err := svc.Join(r.Context(), userID, groupID); err != nil {
			writeJSONError(w, statusForGroupsError(err), groupsErrorMessage(err))
			return
		}

		w.WriteHeader(http.StatusNoContent)
	}
}

func handleLeaveGroup(svc groupsService) http.HandlerFunc {
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

		var req LeaveGroupRequest
		if err := decodeJSONBody(w, r, maxRequestBodyBytes, &req); err != nil {
			writeJSONError(w, http.StatusBadRequest, "invalid request body")
			return
		}

		disposition, known := knownLeaveDispositions[req.Disposition]
		if !known {
			writeJSONError(w, http.StatusBadRequest, "invalid disposition")
			return
		}

		if err := svc.Leave(r.Context(), userID, groupID, disposition); err != nil {
			writeJSONError(w, statusForGroupsError(err), groupsErrorMessage(err))
			return
		}

		w.WriteHeader(http.StatusNoContent)
	}
}

func handleRemoveGroupMember(svc groupsService) http.HandlerFunc {
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

		targetUserID, err := uuid.Parse(r.PathValue("userId"))
		if err != nil {
			writeJSONError(w, http.StatusBadRequest, "invalid userId")
			return
		}

		if err := svc.RemoveMember(r.Context(), userID, groupID, targetUserID); err != nil {
			writeJSONError(w, statusForGroupsError(err), groupsErrorMessage(err))
			return
		}

		w.WriteHeader(http.StatusNoContent)
	}
}

func handleSetGroupRemovalPolicy(svc groupsService) http.HandlerFunc {
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

		var req SetRemovalPolicyRequest
		if err := decodeJSONBody(w, r, maxRequestBodyBytes, &req); err != nil {
			writeJSONError(w, http.StatusBadRequest, "invalid request body")
			return
		}

		policy, known := knownRemovalPolicies[req.RemovalPolicy]
		if !known {
			writeJSONError(w, http.StatusBadRequest, "invalid removalPolicy")
			return
		}

		if err := svc.SetRemovalPolicy(r.Context(), userID, groupID, policy); err != nil {
			writeJSONError(w, statusForGroupsError(err), groupsErrorMessage(err))
			return
		}

		w.WriteHeader(http.StatusNoContent)
	}
}

// groupResponse converts a groups.Group to its wire shape -- shared by every handler that returns
// one, so the shape can never drift between call sites.
func groupResponse(g groups.Group) GroupResponse {
	return GroupResponse{
		ID:              g.ID.String(),
		Name:            g.Name,
		OrganizerUserID: g.OrganizerUserID.String(),
		RemovalPolicy:   string(g.RemovalPolicy),
		CreatedAt:       g.CreatedAt.UTC().Format(time.RFC3339),
	}
}

// invitationResponse converts a groups.Invitation to its wire shape.
func invitationResponse(inv groups.Invitation) InvitationResponse {
	return InvitationResponse{
		GroupID:       inv.GroupID.String(),
		InviteeUserID: inv.InviteeUserID.String(),
		InviterUserID: inv.InviterUserID.String(),
		State:         inv.State,
		CreatedAt:     inv.CreatedAt.UTC().Format(time.RFC3339),
	}
}

// statusForGroupsError maps every one of groups' exported sentinel errors to an HTTP status,
// mirroring statusForFriendsError's pattern. Not-a-member and no-invitation map to 404 -- never
// 403, which would itself confirm the group exists (T-04.1-45). not-friends, already-member,
// name-too-long, and remove-self map to 400 (client-correctable input errors). group-full maps to
// 409 (a state conflict). removal-not-permitted maps to 403 -- safe to distinguish here because
// RemoveMember has already confirmed the caller is a member of this specific group before this
// sentinel can ever be reached. Anything else maps to 500.
func statusForGroupsError(err error) int {
	switch {
	case errors.Is(err, groups.ErrNotAMember),
		errors.Is(err, groups.ErrNoInvitation):
		return http.StatusNotFound
	case errors.Is(err, groups.ErrNotFriends),
		errors.Is(err, groups.ErrAlreadyMember),
		errors.Is(err, groups.ErrNameTooLong),
		errors.Is(err, groups.ErrRemoveSelf):
		return http.StatusBadRequest
	case errors.Is(err, groups.ErrGroupFull):
		return http.StatusConflict
	case errors.Is(err, groups.ErrRemovalNotPermitted):
		return http.StatusForbidden
	default:
		return http.StatusInternalServerError
	}
}

// groupsErrorMessage returns a response body message for a groups error. Every sentinel below
// describes itself -- none of them carries the same probing risk friends_handler.go's invite
// tokens do (T-04.1-31 is specific to invite tokens), and ErrNotAMember's own message is already
// identical regardless of whether the group exists (T-04.1-45 is enforced by the sentinel itself
// being the same Go error value in both cases, not by a shared message string here).
func groupsErrorMessage(err error) string {
	switch {
	case errors.Is(err, groups.ErrNotAMember),
		errors.Is(err, groups.ErrNoInvitation),
		errors.Is(err, groups.ErrNotFriends),
		errors.Is(err, groups.ErrAlreadyMember),
		errors.Is(err, groups.ErrNameTooLong),
		errors.Is(err, groups.ErrRemoveSelf),
		errors.Is(err, groups.ErrGroupFull),
		errors.Is(err, groups.ErrRemovalNotPermitted):
		return err.Error()
	default:
		return "internal error"
	}
}
