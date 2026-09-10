import Foundation

/// A small, closed, invite-only group -- sent only to people already on the sender's friend list.
/// `docs/group-events.md` Section 1: no "public group anyone can join" tier exists at all; a group
/// generates no public/aggregate signal and is not listed on any profile.
public struct SocialGroup: Sendable, Equatable, Codable {
    public var id: UUID
    public var name: String
    public var organizerUserID: SocialUserID
    public var memberRemovalPolicy: MemberRemovalPolicy
    public var createdAt: Date

    public init(
        id: UUID,
        name: String,
        organizerUserID: SocialUserID,
        memberRemovalPolicy: MemberRemovalPolicy,
        createdAt: Date
    ) {
        self.id = id
        self.name = name
        self.organizerUserID = organizerUserID
        self.memberRemovalPolicy = memberRemovalPolicy
        self.createdAt = createdAt
    }
}

/// `docs/group-events.md` Section 1: "Removing a member is available to any member, or restricted
/// to the organizer, per group preference." The organizer is "a convenience role, not a title with
/// public weight" -- this policy governs one action only, never a broader admin/ownership concept.
/// If the organizer leaves, the group simply continues; there is nothing to transfer.
public enum MemberRemovalPolicy: String, CaseIterable, Sendable, Codable {
    case anyMember
    case organizerOnly
}

public struct GroupMembership: Sendable, Equatable, Codable {
    public var groupID: UUID
    public var user: SocialUser
    public var joinedAt: Date

    public init(groupID: UUID, user: SocialUser, joinedAt: Date) {
        self.groupID = groupID
        self.user = user
        self.joinedAt = joinedAt
    }
}

/// GROUPEVENTS-04: offered explicitly at the leave step, per `docs/group-events.md` Section 4 --
/// "the app should offer this explicitly at the leave step rather than leaving it as an unstated
/// default either way." A leaving member's past posts either stay in the group's history or are
/// removed along with the leave action; there is no silent default either way.
///
/// Explicit raw values (plan 04.1-11, Rule 1 fix): this type's own wire consumer,
/// `RithamService/internal/groups/membership.go`'s `LeaveDisposition`, declares its two
/// constants as `"keepPosts"`/`"removePosts"` -- the implicit case-name-derived raw values this
/// enum shipped with originally (`"keepPastPosts"`/`"removePastPosts"`) would never match either
/// entry in the server's `knownLeaveDispositions` map, and every leave call would 400. The case
/// names stay descriptive for readers of this file; only the wire-facing raw value changed.
public enum GroupLeaveDisposition: String, CaseIterable, Sendable, Codable {
    case keepPastPosts = "keepPosts"
    case removePastPosts = "removePosts"
}

/// `docs/group-events.md` Section 1 asks for a size that biases toward "the people doing this 5K
/// together," not a scaling club; a smaller closed group also reduces the aggregate-exposure
/// surface Section 3 describes. `12` resolves 04.1-CONTEXT.md's Claude's-Discretion group-size
/// item -- a single named constant so changing the number later is one edit with one test.
public enum GroupSizeLimit {
    public static let maximumMembers = 12
}
