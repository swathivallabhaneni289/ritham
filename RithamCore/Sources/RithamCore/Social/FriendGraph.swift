import Foundation

/// HOUSEHOLD-02/GROUPEVENTS-01: the three closed-loop paths a friendship can form through, per
/// `docs/group-events.md` Section 1 -- exactly these three, no fourth. There is no public profile
/// search and no contact-scan without explicit, per-side opt-in anywhere in this domain.
public enum FriendConnectionPath: String, CaseIterable, Sendable, Codable {
    case contactMatch
    case inviteLink
    case directShare
}

/// Friending is mutual and request-based, never a one-directional follow -- both people must
/// accept before any `Friendship` exists.
public enum FriendRequestState: String, CaseIterable, Sendable, Codable {
    case pending
    case accepted
    case declined
}

public struct FriendRequest: Sendable, Equatable, Codable {
    public var id: UUID
    public var fromUserID: SocialUserID
    public var toUserID: SocialUserID
    public var state: FriendRequestState
    public var createdAt: Date
    public var path: FriendConnectionPath

    public init(
        id: UUID,
        fromUserID: SocialUserID,
        toUserID: SocialUserID,
        state: FriendRequestState,
        createdAt: Date,
        path: FriendConnectionPath
    ) {
        self.id = id
        self.fromUserID = fromUserID
        self.toUserID = toUserID
        self.state = state
        self.createdAt = createdAt
        self.path = path
    }
}

public struct Friendship: Sendable, Equatable, Codable {
    public var otherUser: SocialUser
    public var establishedAt: Date

    public init(otherUser: SocialUser, establishedAt: Date) {
        self.otherUser = otherUser
        self.establishedAt = establishedAt
    }
}

/// Per-invite, expiring invite link/QR token. `docs/group-events.md` Section 1: "generated
/// per-invite, expiring after a set window or first use... a permanent, forwardable invite link
/// is public discoverability wearing a different hat." Ritham avoids that problem at the source:
/// links die.
public struct InviteToken: Sendable, Equatable, Codable {
    public var token: String
    public var expiresAt: Date
    public var consumedAt: Date?

    public init(token: String, expiresAt: Date, consumedAt: Date? = nil) {
        self.token = token
        self.expiresAt = expiresAt
        self.consumedAt = consumedAt
    }

    /// `false` once consumed (first use) or past `expiresAt`; `true` otherwise.
    public func isRedeemable(at date: Date) -> Bool {
        consumedAt == nil && date < expiresAt
    }
}
