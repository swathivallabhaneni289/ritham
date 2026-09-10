import Foundation

/// A pure-domain mirror of one established friend, derived from `FriendResponse` -- kept
/// separate from the wire type per this project's existing "pure domain vs. wire types are
/// separate layers" split (`SocialIdentity.swift`'s own header comment). `establishedAt` is
/// carried for completeness but MUST NOT be rendered by any friend row: T-04.1-55 and this
/// plan's own must_haves truth require a friend row to carry nothing comparable, and a
/// join/establishment date is exactly the kind of value that invites a "who's been friends
/// longer" reading.
struct Friendship: Identifiable, Equatable {
    let id: String
    let displayName: String
    let establishedAt: Date
}

/// A pure-domain mirror of one incoming `friend_requests` row, derived from
/// `FriendRequestResponse`.
struct FriendRequest: Identifiable, Equatable {
    let id: String
    let fromUserID: String
    let fromDisplayName: String
    let toUserID: String
    let connectionPath: String
    let createdAt: Date
}

/// A freshly created, plaintext-once invite token, derived from `CreateInviteResponse`.
struct InviteToken: Equatable {
    let token: String
    let expiresAt: Date
}

/// Drives the friends list, incoming requests, and the contact-match opt-in at the model level,
/// following `CardioHistoryModel`'s `@Observable`-load-from-source shape
/// (`RithamApp/Ritham/Cardio/Views/CardioHistoryView.swift`), substituting a network client for
/// the local store.
///
/// `state`'s `.failed` case is load-bearing: an unreachable service must read as an error, never
/// as an empty result. `friends`/`incoming` are left completely untouched on any `load()`
/// failure -- both are populated together from one `async let` pair, so a throw on either half
/// leaves the previous, already-assigned values in place rather than partially updating. An
/// empty friends array is exactly the kind of benign-looking wrong answer this project has
/// already ruled out for `WorkoutPlanClient` (T-04.1-26/T-04.1-54).
@MainActor
@Observable
final class FriendsModel {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(SocialAPIError)
    }

    private(set) var friends: [Friendship] = []
    private(set) var incoming: [FriendRequest] = []
    private(set) var state: LoadState = .idle
    private(set) var contactMatchOptedIn = false

    private let client: FriendsClient

    private static let dateFormatter = ISO8601DateFormatter()

    init(client: FriendsClient = FriendsClient(apiClient: SocialAPIClient(sessionStore: SessionStore()))) {
        self.client = client
    }

    /// Loads the friends list and incoming requests together. A throw from either call leaves
    /// both `friends` and `incoming` exactly as they were before this call -- the assignment
    /// below only runs once both halves have succeeded.
    func load() async {
        state = .loading
        do {
            async let friendsTask = client.list()
            async let incomingTask = client.incomingRequests()
            let (friendResponses, requestResponses) = try await (friendsTask, incomingTask)
            friends = friendResponses.compactMap(Self.friendship)
            incoming = requestResponses.compactMap(Self.friendRequest)
            state = .loaded
        } catch {
            state = .failed(Self.socialError(error))
        }
    }

    /// Accepts `request`, then reloads -- the reload is what removes the accepted request from
    /// `incoming` and adds the now-established friend to `friends`, rather than this method
    /// mutating either array itself, matching this plan's own "removes it from the incoming
    /// array and adds the person to the friends array after the reload" behavior literally.
    func accept(_ request: FriendRequest) async {
        do {
            _ = try await client.accept(requestID: request.id)
            await load()
        } catch {
            state = .failed(Self.socialError(error))
        }
    }

    /// Declines `request`. Removed from `incoming` locally on success -- declining never changes
    /// `friends`, so a full reload is not needed to keep this model's state correct.
    func decline(_ request: FriendRequest) async {
        do {
            try await client.decline(requestID: request.id)
            incoming.removeAll { $0.id == request.id }
        } catch {
            state = .failed(Self.socialError(error))
        }
    }

    /// Unfriends `friend`. Not in this plan's own stated method list for `FriendsModel`, but
    /// added because Task 2's own action text ("Rows offer unfriend behind a confirmation") is
    /// otherwise unbuildable -- `FriendsClient.unfriend(userID:)` already exists (Task 1), this is
    /// the model-level wrapper `FriendsListView` calls (Rule 2). Removed from `friends` locally on
    /// success, matching `decline(_:)`'s own no-reload-needed reasoning.
    func unfriend(_ friend: Friendship) async {
        do {
            try await client.unfriend(userID: friend.id)
            friends.removeAll { $0.id == friend.id }
        } catch {
            state = .failed(Self.socialError(error))
        }
    }

    /// Sets the contact-match opt-in flag. `digests` is submitted only when `optedIn` is `true`
    /// -- turning the opt-in off always submits an empty digest array over the wire, regardless
    /// of what was passed in, matching this plan's own behavior list literally and
    /// `SetContactMatchOptInRequest`'s own doc comment on what `identifierDigests` is (and is
    /// not) for.
    func setContactMatchOptIn(_ optedIn: Bool, digests: [Data] = []) async {
        do {
            try await client.setContactMatchOptIn(optedIn, digests: optedIn ? digests : [])
            contactMatchOptedIn = optedIn
        } catch {
            state = .failed(Self.socialError(error))
        }
    }

    /// Creates an invite. Returns `nil` on any failure (moving `state` to `.failed`) or when the
    /// server's `expiresAt` string fails to parse -- never a token this screen could present
    /// without a reliable expiry to show alongside it.
    func createInvite() async -> InviteToken? {
        do {
            let response = try await client.createInvite()
            guard let expiresAt = Self.dateFormatter.date(from: response.expiresAt) else { return nil }
            return InviteToken(token: response.token, expiresAt: expiresAt)
        } catch {
            state = .failed(Self.socialError(error))
            return nil
        }
    }

    /// Redeems `token`, then reloads -- a successful redemption creates a new pending
    /// `friend_requests` row addressed to this device (the issuer -> redeemer direction
    /// `RithamService/internal/friends/invites.go`'s `RedeemInvite` always creates), which the
    /// reload surfaces in `incoming`.
    func redeem(token: String) async {
        do {
            _ = try await client.redeemInvite(token: token)
            await load()
        } catch {
            state = .failed(Self.socialError(error))
        }
    }

    // MARK: - Wire -> domain conversion

    private static func friendship(_ response: FriendResponse) -> Friendship? {
        guard let establishedAt = dateFormatter.date(from: response.establishedAt) else { return nil }
        return Friendship(id: response.userId, displayName: response.displayName, establishedAt: establishedAt)
    }

    private static func friendRequest(_ response: FriendRequestResponse) -> FriendRequest? {
        guard let createdAt = dateFormatter.date(from: response.createdAt) else { return nil }
        return FriendRequest(
            id: response.id,
            fromUserID: response.fromUserId,
            fromDisplayName: response.fromDisplayName,
            toUserID: response.toUserId,
            connectionPath: response.connectionPath,
            createdAt: createdAt
        )
    }

    private static func socialError(_ error: Error) -> SocialAPIError {
        (error as? SocialAPIError) ?? .transport
    }
}
