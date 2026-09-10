import Foundation

// Wire types for the friend-graph feature (HOUSEHOLD-02, GROUPEVENTS-01). Every field mirrors
// RithamService/internal/httpapi/friends_handler.go's JSON tags character for character --
// friends_handler.go declares its own wire types locally (not contract.go), so this file follows
// that same file, not contract.go's locked reflection-test boundary.
//
// No request type below declares a field naming the acting user: every mutating route reads the
// caller's identity from RequireSession's bearer-derived context server-side, never from the
// request body (T-04.1-35, matching AppleSignInRequest's own "identity travels in the bearer
// header only" rule). `toUserId` on `SendFriendRequestRequest` names the *target* of the request,
// not the actor issuing it -- the actor is never a field on any struct in this file.

/// Entire request body for `POST /v1/friends/requests`. `connectionPath` is one of the two
/// client-initiated closed-loop paths the server's `knownConnectionPaths` map accepts --
/// `FriendConnectionPath` below is the closed Swift vocabulary for those two values. The third
/// server-side path value, `invite_link`, is never sent by this client: it is stamped by
/// `RedeemInvite` itself when an invite is redeemed, never chosen by a caller of this request.
struct SendFriendRequestRequest: Encodable, Equatable {
    let toUserId: String
    let connectionPath: String

    enum CodingKeys: String, CodingKey {
        case toUserId
        case connectionPath
    }
}

/// Describes one `friend_requests` row -- returned by send, redeem-invite, and the incoming list,
/// so its shape can never drift between those three call sites (mirrors
/// `friendRequestResponse(_:)`'s single Go-side conversion function for the identical reason).
struct FriendRequestResponse: Decodable, Equatable, Identifiable {
    let id: String
    let fromUserId: String
    let toUserId: String
    let state: String
    let connectionPath: String
    let createdAt: String
}

/// Returned by `GET /v1/friends/requests`.
struct IncomingRequestsResponse: Decodable, Equatable {
    let requests: [FriendRequestResponse]
}

/// Returned by a successful `POST /v1/friends/requests/{id}/accept` -- the other party's user id
/// and when the friendship was established, from the caller's own point of view (the Go handler
/// resolves which side of the stored pair is "the other person" before responding).
struct AcceptFriendRequestResponse: Decodable, Equatable {
    let friendUserId: String
    let establishedAt: String
}

/// Describes one established friend.
struct FriendResponse: Decodable, Equatable, Identifiable {
    let userId: String
    let displayName: String
    let establishedAt: String

    var id: String { userId }
}

/// Returned by `GET /v1/friends`.
struct FriendsListResponse: Decodable, Equatable {
    let friends: [FriendResponse]
}

/// Returned by `POST /v1/invites`. `token` is the plaintext bearer value, returned exactly once
/// -- only its digest is stored server-side, matching `SessionResponse.sessionToken`'s identical
/// "shown once" contract.
struct CreateInviteResponse: Decodable, Equatable {
    let token: String
    let expiresAt: String
}

/// Entire request body for `POST /v1/invites/redeem`.
struct RedeemInviteRequest: Encodable, Equatable {
    let token: String

    enum CodingKeys: String, CodingKey {
        case token
    }
}

/// Entire request body for `PUT /v1/friends/contact-match`. `identifierDigests` is `[Data]`,
/// which `JSONEncoder` marshals as an array of base64 strings -- the wire representation of
/// `[][]byte` on the Go side, matching how `encoding/json` marshals a byte slice. Every value in
/// this array must already be a client-hashed digest (`ContactMatchDigest.digests(for:salt:)`)
/// -- never a raw contact identifier, and never another person's identifier (see this struct's
/// own consumer, `FriendsModel.setContactMatchOptIn(_:digests:)`, for the load-bearing
/// distinction between "my own identifiers" and "my address book," which this field is only
/// correct for the former).
struct SetContactMatchOptInRequest: Encodable, Equatable {
    let optedIn: Bool
    let identifierDigests: [Data]

    enum CodingKeys: String, CodingKey {
        case optedIn
        case identifierDigests
    }
}

/// Entire request body for `POST /v1/friends/contact-match/query`. `candidateDigests` are
/// client-hashed digests of the caller's own device contacts (the opposite direction from
/// `SetContactMatchOptInRequest.identifierDigests` -- see that struct's own comment).
struct MatchContactsRequest: Encodable, Equatable {
    let candidateDigests: [Data]

    enum CodingKeys: String, CodingKey {
        case candidateDigests
    }
}

/// One contact-match result. No `establishedAt` field -- a match candidate is not yet a friend.
struct ContactMatchCandidate: Decodable, Equatable, Identifiable {
    let userId: String
    let displayName: String

    var id: String { userId }
}

/// Returned by `POST /v1/friends/contact-match/query`.
struct MatchContactsResponse: Decodable, Equatable {
    let matches: [ContactMatchCandidate]
}

/// The closed set of client-initiated connection paths (`docs/group-events.md` §1) -- exactly
/// the two raw values `RithamService/internal/httpapi/friends_handler.go`'s
/// `knownConnectionPaths` map accepts from `SendRequest`. `invite_link` intentionally has no case
/// here: it is set server-side only, as the audit trail for a request created by redeeming an
/// invite, never a value this client chooses and sends.
enum FriendConnectionPath: String {
    case contactMatch = "contact_match"
    case directShare = "direct_share"
}

/// A request body with no fields, encoded as an empty JSON object. Mirrors `IdentityClient.swift`'s
/// own `EmptyBody` precedent: every route this file sends it to (`accept`, `decline`, `unfriend`,
/// `createInvite`) authenticates purely off the bearer header, and the Go handler never calls
/// `decodeJSONBody` on the request at all -- this exists only to satisfy `SocialAPIClient`'s
/// `Body: Encodable` requirement without adding a second, no-body-specific overload to that
/// shared client (T-04.1-09's file-scope boundary for this plan).
private struct EmptyBody: Encodable {}

/// The ten friend-graph operations every friends screen builds on -- a thin wrapper over
/// `SocialAPIClient`, matching `IdentityClient`'s per-domain-client-over-shared-client shape. No
/// networking of its own.
struct FriendsClient {
    let apiClient: SocialAPIClient

    init(apiClient: SocialAPIClient) {
        self.apiClient = apiClient
    }

    /// `GET /v1/friends`, behind `RequireSession`.
    func list() async throws -> [FriendResponse] {
        let response: FriendsListResponse = try await apiClient.get("v1/friends")
        return response.friends
    }

    /// `GET /v1/friends/requests`, behind `RequireSession`.
    func incomingRequests() async throws -> [FriendRequestResponse] {
        let response: IncomingRequestsResponse = try await apiClient.get("v1/friends/requests")
        return response.requests
    }

    /// `POST /v1/friends/requests`, behind `RequireSession`.
    func send(toUserID: String, path: FriendConnectionPath) async throws -> FriendRequestResponse {
        try await apiClient.send(
            "POST", "v1/friends/requests",
            body: SendFriendRequestRequest(toUserId: toUserID, connectionPath: path.rawValue)
        )
    }

    /// `POST /v1/friends/requests/{id}/accept`, behind `RequireSession`.
    func accept(requestID: String) async throws -> AcceptFriendRequestResponse {
        try await apiClient.send("POST", "v1/friends/requests/\(requestID)/accept", body: EmptyBody())
    }

    /// `POST /v1/friends/requests/{id}/decline`, behind `RequireSession`. Returns `204 No Content`
    /// server-side.
    func decline(requestID: String) async throws {
        try await apiClient.send("POST", "v1/friends/requests/\(requestID)/decline", body: EmptyBody())
    }

    /// `DELETE /v1/friends/{userId}`, behind `RequireSession`. Returns `204 No Content`
    /// server-side.
    func unfriend(userID: String) async throws {
        try await apiClient.send("DELETE", "v1/friends/\(userID)", body: EmptyBody())
    }

    /// `POST /v1/invites`, behind `RequireSession`.
    func createInvite() async throws -> CreateInviteResponse {
        try await apiClient.send("POST", "v1/invites", body: EmptyBody())
    }

    /// `POST /v1/invites/redeem`, behind `RequireSession`.
    func redeemInvite(token: String) async throws -> FriendRequestResponse {
        try await apiClient.send("POST", "v1/invites/redeem", body: RedeemInviteRequest(token: token))
    }

    /// `PUT /v1/friends/contact-match`, behind `RequireSession`. Returns `204 No Content`
    /// server-side. See `SetContactMatchOptInRequest`'s own comment for what `digests` must (and
    /// must not) contain.
    func setContactMatchOptIn(_ optedIn: Bool, digests: [Data]) async throws {
        try await apiClient.send(
            "PUT", "v1/friends/contact-match",
            body: SetContactMatchOptInRequest(optedIn: optedIn, identifierDigests: digests)
        )
    }

    /// `POST /v1/friends/contact-match/query`, behind `RequireSession`.
    func matchContacts(digests: [Data]) async throws -> [ContactMatchCandidate] {
        let response: MatchContactsResponse = try await apiClient.send(
            "POST", "v1/friends/contact-match/query",
            body: MatchContactsRequest(candidateDigests: digests)
        )
        return response.matches
    }
}
