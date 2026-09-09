import Foundation
import Testing
@testable import RithamCore

@Suite("SocialModelTests")
struct SocialModelTests {

    /// Encodes `value` wrapped in a single-element array (avoiding top-level-fragment decode
    /// friction for the simple raw-value enums in this file) and decodes it back, returning
    /// whether the round trip is unchanged.
    private func roundTrips<T: Codable & Equatable>(_ value: T) throws -> Bool {
        let data = try JSONEncoder().encode([value])
        let decoded = try JSONDecoder().decode([T].self, from: data)
        return decoded == [value]
    }

    // MARK: - GroupVisibilityScope

    @Test("GroupVisibilityScope has exactly two cases: onlyMe and group")
    func visibilityScopeHasExactlyTwoCases() {
        #expect(GroupVisibilityScope.allCases.count == 2)
        #expect(GroupVisibilityScope.allCases.contains(.onlyMe))
        #expect(GroupVisibilityScope.allCases.contains(.group))
    }

    @Test("GroupVisibilityScope(rawValue: \"household\") is nil -- the reserved rung cannot be selected by any persisted string or decoded payload")
    func visibilityScopeHouseholdRawValueDoesNotResolve() {
        #expect(GroupVisibilityScope(rawValue: "household") == nil)
    }

    @Test("GroupVisibilityScope round-trips through JSONEncoder/JSONDecoder unchanged")
    func visibilityScopeRoundTrips() throws {
        #expect(try roundTrips(GroupVisibilityScope.onlyMe))
        #expect(try roundTrips(GroupVisibilityScope.group))
    }

    // MARK: - SocialIdentity

    @Test("SocialUserID and SocialUser round-trip through JSONEncoder/JSONDecoder unchanged")
    func socialIdentityRoundTrips() throws {
        let id = SocialUserID(value: "user-abc-123")
        #expect(try roundTrips(id))

        let user = SocialUser(id: id, displayName: "Priya")
        #expect(try roundTrips(user))
    }

    // MARK: - FriendGraph

    @Test("FriendConnectionPath has exactly three cases -- the closed loop of connection paths")
    func friendConnectionPathHasExactlyThreeCases() {
        #expect(FriendConnectionPath.allCases.count == 3)
        #expect(FriendConnectionPath.allCases.contains(.contactMatch))
        #expect(FriendConnectionPath.allCases.contains(.inviteLink))
        #expect(FriendConnectionPath.allCases.contains(.directShare))
    }

    @Test("FriendRequest and Friendship round-trip through JSONEncoder/JSONDecoder unchanged")
    func friendRequestAndFriendshipRoundTrip() throws {
        let fromID = SocialUserID(value: "user-a")
        let toID = SocialUserID(value: "user-b")
        let request = FriendRequest(
            id: UUID(),
            fromUserID: fromID,
            toUserID: toID,
            state: .pending,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            path: .inviteLink
        )
        #expect(try roundTrips(request))

        let friendship = Friendship(
            otherUser: SocialUser(id: toID, displayName: "Sam"),
            establishedAt: Date(timeIntervalSince1970: 1_700_000_500)
        )
        #expect(try roundTrips(friendship))
    }

    @Test("InviteToken.isRedeemable is false once consumed")
    func inviteTokenNotRedeemableOnceConsumed() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let token = InviteToken(
            token: "invite-xyz",
            expiresAt: now.addingTimeInterval(3600),
            consumedAt: now.addingTimeInterval(-10)
        )
        #expect(token.isRedeemable(at: now) == false)
    }

    @Test("InviteToken.isRedeemable is false past expiresAt")
    func inviteTokenNotRedeemablePastExpiry() {
        let expiresAt = Date(timeIntervalSince1970: 1_700_000_000)
        let token = InviteToken(token: "invite-xyz", expiresAt: expiresAt, consumedAt: nil)
        #expect(token.isRedeemable(at: expiresAt.addingTimeInterval(1)) == false)
    }

    @Test("InviteToken.isRedeemable is true when unconsumed and before expiresAt")
    func inviteTokenRedeemableWhenUnconsumedAndBeforeExpiry() {
        let expiresAt = Date(timeIntervalSince1970: 1_700_000_000)
        let token = InviteToken(token: "invite-xyz", expiresAt: expiresAt, consumedAt: nil)
        #expect(token.isRedeemable(at: expiresAt.addingTimeInterval(-1)))
    }

    @Test("InviteToken round-trips through JSONEncoder/JSONDecoder unchanged")
    func inviteTokenRoundTrips() throws {
        let token = InviteToken(
            token: "invite-xyz",
            expiresAt: Date(timeIntervalSince1970: 1_700_000_000),
            consumedAt: Date(timeIntervalSince1970: 1_699_999_000)
        )
        #expect(try roundTrips(token))
    }

    // MARK: - GroupModels

    @Test("GroupSizeLimit.maximumMembers is 12")
    func groupSizeLimitIsTwelve() {
        #expect(GroupSizeLimit.maximumMembers == 12)
    }

    @Test("SocialGroup, GroupMembership, and the group enums round-trip through JSONEncoder/JSONDecoder unchanged")
    func groupModelsRoundTrip() throws {
        let organizerID = SocialUserID(value: "user-organizer")
        let group = SocialGroup(
            id: UUID(),
            name: "Saturday Crew",
            organizerUserID: organizerID,
            memberRemovalPolicy: .organizerOnly,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        #expect(try roundTrips(group))

        let membership = GroupMembership(
            groupID: group.id,
            user: SocialUser(id: organizerID, displayName: "Priya"),
            joinedAt: Date(timeIntervalSince1970: 1_700_000_100)
        )
        #expect(try roundTrips(membership))

        #expect(try roundTrips(MemberRemovalPolicy.anyMember))
        #expect(try roundTrips(MemberRemovalPolicy.organizerOnly))
        #expect(try roundTrips(GroupLeaveDisposition.keepPastPosts))
        #expect(try roundTrips(GroupLeaveDisposition.removePastPosts))
    }

    // MARK: - GoalEventModels

    @Test("GoalEvent reuses RithamCore.ActivityType directly, no second activity vocabulary")
    func goalEventReusesActivityType() {
        let event = GoalEvent(
            id: UUID(),
            groupID: UUID(),
            name: "Saturday 5K Walk",
            activityType: .walk,
            target: GoalEventTarget.none,
            startsOn: Date(timeIntervalSince1970: 1_700_000_000),
            endsOn: Date(timeIntervalSince1970: 1_700_086_400),
            organizerUserID: SocialUserID(value: "user-organizer")
        )
        #expect(event.activityType == ActivityType.walk)
    }

    @Test("GoalEvent, GoalEventRSVP, GoalEventCompletion, and PrivateCompletionDetail round-trip through JSONEncoder/JSONDecoder unchanged")
    func goalEventModelsRoundTrip() throws {
        let organizerID = SocialUserID(value: "user-organizer")
        let event = GoalEvent(
            id: UUID(),
            groupID: UUID(),
            name: "Saturday 5K Walk",
            activityType: .walk,
            target: .distance(metres: 5000),
            startsOn: Date(timeIntervalSince1970: 1_700_000_000),
            endsOn: Date(timeIntervalSince1970: 1_700_086_400),
            organizerUserID: organizerID
        )
        #expect(try roundTrips(event))

        let rsvp = GoalEventRSVP(
            eventID: event.id,
            userID: organizerID,
            respondedAt: Date(timeIntervalSince1970: 1_700_000_050)
        )
        #expect(try roundTrips(rsvp))

        let completion = GoalEventCompletion(
            id: UUID(),
            eventID: event.id,
            user: SocialUser(id: organizerID, displayName: "Priya"),
            completedAt: Date(timeIntervalSince1970: 1_700_010_000),
            ownTimeSeconds: 1934,
            photoAssetID: "asset-1",
            placeName: "Griffith Park",
            caption: "Great morning for it.",
            postedAt: Date(timeIntervalSince1970: 1_700_010_100)
        )
        #expect(try roundTrips(completion))

        let detail = PrivateCompletionDetail(
            completionID: completion.id,
            distanceMetres: 5100,
            durationSeconds: 1934,
            routeRecorded: true
        )
        #expect(try roundTrips(detail))
    }

    @Test("GoalEventTarget's three cases round-trip through JSONEncoder/JSONDecoder unchanged")
    func goalEventTargetRoundTrips() throws {
        #expect(try roundTrips(GoalEventTarget.none))
        #expect(try roundTrips(GoalEventTarget.distance(metres: 5000)))
        #expect(try roundTrips(GoalEventTarget.duration(seconds: 2700)))
    }

    // MARK: - Cheer

    @Test("Cheer has exactly two cases -- the fixed, non-ranked cheer set")
    func cheerHasExactlyTwoCases() {
        #expect(Cheer.allCases.count == 2)
        #expect(Cheer.allCases.contains(.niceWork))
        #expect(Cheer.allCases.contains(.keepGoing))
    }

    @Test("CheerReaction round-trips through JSONEncoder/JSONDecoder unchanged, carries no numeric field")
    func cheerReactionRoundTrips() throws {
        let reaction = CheerReaction(completionID: UUID(), cheer: .niceWork, sentByMe: true)
        #expect(try roundTrips(reaction))
    }
}
