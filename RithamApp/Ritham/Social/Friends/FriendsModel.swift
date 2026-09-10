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
/// failure -- an empty friends array is exactly the kind of benign-looking wrong answer this
/// project has already ruled out for `WorkoutPlanClient` (T-04.1-26/T-04.1-54).
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

    init(client: FriendsClient = FriendsClient(apiClient: SocialAPIClient(sessionStore: SessionStore()))) {
        self.client = client
    }

    /// RED (Task 1, stub): always reports success with no data and never calls `client`, so the
    /// transport-failure/unauthenticated-failure tests fail meaningfully before the real
    /// implementation lands in the GREEN commit.
    func load() async {
        state = .loaded
    }

    /// RED (Task 1, stub): a no-op.
    func accept(_ request: FriendRequest) async {}

    /// RED (Task 1, stub): a no-op.
    func decline(_ request: FriendRequest) async {}

    /// RED (Task 1, stub): always submits whatever `digests` was passed, regardless of
    /// `optedIn` -- deliberately wrong so the "turning the opt-in off submits no digests" test
    /// fails meaningfully before the real implementation lands in the GREEN commit.
    func setContactMatchOptIn(_ optedIn: Bool, digests: [Data] = []) async {
        try? await client.setContactMatchOptIn(optedIn, digests: digests)
        contactMatchOptedIn = optedIn
    }

    /// RED (Task 1, stub): always returns `nil`.
    func createInvite() async -> InviteToken? { nil }

    /// RED (Task 1, stub): a no-op.
    func redeem(token: String) async {}
}
