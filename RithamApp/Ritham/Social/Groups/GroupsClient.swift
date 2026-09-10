import Foundation

// Wire types for the small, closed, invite-only groups feature (GROUPEVENTS-01, HOUSEHOLD-02).
// Every field mirrors RithamService/internal/httpapi/groups_handler.go's JSON tags character for
// character -- groups_handler.go declares its own wire types locally (not contract.go), matching
// friends_handler.go's own precedent from this same phase (see FriendsClient.swift's header
// comment).
//
// No request type below declares a field naming the acting user: every mutating route reads the
// caller's identity from RequireSession's bearer-derived context server-side, never from the
// request body (T-04.1-35, matching every other social client in this phase).
//
// `groups_handler.go` exposes exactly nine authenticated routes (04.1-08-SUMMARY.md). This file
// mirrors all nine. It deliberately has NO `declineInvitation` method and no method to list a
// user's own pending invitations -- see this directory's `GroupsModel.swift` header comment for
// why, and this plan's own SUMMARY.md's Known Stubs section for the full account of the gap.

/// Entire request body for `POST /v1/groups`. `removalPolicy` is optional on the wire -- an empty
/// string defers to the server's own default (`PolicyAnyMember`).
struct CreateGroupRequest: Encodable, Equatable {
    let name: String
    let removalPolicy: String

    enum CodingKeys: String, CodingKey {
        case name
        case removalPolicy
    }
}

/// Describes one `groups` row, from the caller's own point of view. Returned by create and list.
struct GroupResponse: Decodable, Equatable, Identifiable {
    let id: String
    let name: String
    let organizerUserId: String
    let removalPolicy: String
    let createdAt: String
}

/// Returned by `GET /v1/groups`.
struct GroupsListResponse: Decodable, Equatable {
    let groups: [GroupResponse]
}

/// Returned by `GET /v1/groups/{id}`. Mirrors `GroupDetailResponse`'s Go shape: an embedded
/// `GroupResponse` with no JSON tag of its own promotes its fields to this same flat level, so
/// this struct declares every `GroupResponse` field again rather than nesting -- a literal
/// field-for-field mirror of what `encoding/json` actually puts on the wire, not of Go's
/// embedding syntax.
struct GroupDetailResponse: Decodable, Equatable {
    let id: String
    let name: String
    let organizerUserId: String
    let removalPolicy: String
    let createdAt: String
    let memberCount: Int
}

/// Entire request body for `POST /v1/groups/{id}/invitations`.
struct InviteToGroupRequest: Encodable, Equatable {
    let inviteeUserId: String

    enum CodingKeys: String, CodingKey {
        case inviteeUserId
    }
}

/// Describes one `group_invitations` row -- returned to the inviter by a successful invite.
struct InvitationResponse: Decodable, Equatable {
    let groupId: String
    let inviteeUserId: String
    let inviterUserId: String
    let state: String
    let createdAt: String
}

/// Describes one member of a group's roster.
struct MemberResponse: Decodable, Equatable, Identifiable {
    let userId: String
    let displayName: String
    let joinedAt: String

    var id: String { userId }
}

/// Returned by `GET /v1/groups/{id}/members`.
struct GroupMembersResponse: Decodable, Equatable {
    let members: [MemberResponse]
}

/// Entire request body for `POST /v1/groups/{id}/leave`. `disposition` is the leave request's
/// only body field -- the explicit, required keep/remove-past-posts choice
/// (`docs/group-events.md` §4), never defaulted either way.
struct LeaveGroupRequest: Encodable, Equatable {
    let disposition: String

    enum CodingKeys: String, CodingKey {
        case disposition
    }
}

/// Entire request body for `PUT /v1/groups/{id}/removal-policy`.
struct SetRemovalPolicyRequest: Encodable, Equatable {
    let removalPolicy: String

    enum CodingKeys: String, CodingKey {
        case removalPolicy
    }
}

/// A request body with no fields, encoded as an empty JSON object. Mirrors
/// `FriendsClient.swift`'s own `EmptyBody` precedent: `join`/`removeMember` authenticate purely
/// off the bearer header and path parameters, and the Go handler never calls `decodeJSONBody` on
/// either request at all.
private struct EmptyBody: Encodable {}

/// The nine group operations `groups_handler.go` exposes -- a thin wrapper over
/// `SocialAPIClient`, matching `FriendsClient`/`IdentityClient`'s per-domain-client-over-shared-
/// client shape. No networking of its own.
struct GroupsClient {
    let apiClient: SocialAPIClient

    init(apiClient: SocialAPIClient) {
        self.apiClient = apiClient
    }

    /// `POST /v1/groups`, behind `RequireSession`. `policy` is sent as an empty string when `nil`,
    /// letting the server apply its own default.
    func create(name: String, policy: String?) async throws -> GroupResponse {
        try await apiClient.send(
            "POST", "v1/groups",
            body: CreateGroupRequest(name: name, removalPolicy: policy ?? "")
        )
    }

    /// `GET /v1/groups`, behind `RequireSession`.
    func list() async throws -> [GroupResponse] {
        let response: GroupsListResponse = try await apiClient.get("v1/groups")
        return response.groups
    }

    /// `GET /v1/groups/{id}`, behind `RequireSession`. A non-member fetch of a real group and a
    /// fetch of an unknown id return the byte-identical 404 (T-04.1-45) -- this method surfaces
    /// both as `SocialAPIError.httpStatus(404)`, never as an empty/zero detail value.
    func detail(groupID: String) async throws -> GroupDetailResponse {
        try await apiClient.get("v1/groups/\(groupID)")
    }

    /// `GET /v1/groups/{id}/members`, behind `RequireSession`.
    func members(groupID: String) async throws -> [MemberResponse] {
        let response: GroupMembersResponse = try await apiClient.get("v1/groups/\(groupID)/members")
        return response.members
    }

    /// `POST /v1/groups/{id}/invitations`, behind `RequireSession`. The inviter must already be a
    /// member of `groupID` and a friend of `userID` -- the server enforces both; this method
    /// offers no client-side pre-check of either.
    func invite(groupID: String, userID: String) async throws -> InvitationResponse {
        try await apiClient.send(
            "POST", "v1/groups/\(groupID)/invitations",
            body: InviteToGroupRequest(inviteeUserId: userID)
        )
    }

    /// `POST /v1/groups/{id}/join`, behind `RequireSession`. Returns `204 No Content` server-side.
    func join(groupID: String) async throws {
        try await apiClient.send("POST", "v1/groups/\(groupID)/join", body: EmptyBody())
    }

    /// `POST /v1/groups/{id}/leave`, behind `RequireSession`. Returns `204 No Content` server-side.
    /// `disposition` must be exactly one of `GroupLeaveDisposition`'s two raw values.
    func leave(groupID: String, disposition: String) async throws {
        try await apiClient.send(
            "POST", "v1/groups/\(groupID)/leave",
            body: LeaveGroupRequest(disposition: disposition)
        )
    }

    /// `DELETE /v1/groups/{id}/members/{userId}`, behind `RequireSession`. Returns `204 No
    /// Content` server-side. Never self-directed -- the server rejects a target equal to the
    /// caller (leaving is the dedicated route for that).
    func removeMember(groupID: String, userID: String) async throws {
        try await apiClient.send("DELETE", "v1/groups/\(groupID)/members/\(userID)", body: EmptyBody())
    }

    /// `PUT /v1/groups/{id}/removal-policy`, behind `RequireSession`. Returns `204 No Content`
    /// server-side.
    func setRemovalPolicy(groupID: String, policy: String) async throws {
        try await apiClient.send(
            "PUT", "v1/groups/\(groupID)/removal-policy",
            body: SetRemovalPolicyRequest(removalPolicy: policy)
        )
    }
}
