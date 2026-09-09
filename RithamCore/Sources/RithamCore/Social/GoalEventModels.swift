import Foundation

/// GROUPEVENTS-02: the organizer's optional target, per `docs/group-events.md` Section 2 -- "A
/// target -- distance or duration -- optional." The target lives on the event; the group isn't
/// racing toward a shared number, each member individually completes the same agreed activity.
/// No case here expresses a pooled/shared total.
public enum GoalEventTarget: Sendable, Equatable, Codable {
    case none
    case distance(metres: Double)
    case duration(seconds: Int)
}

/// A shared, non-timed commitment -- not a race, not a challenge. `activityType` reuses
/// `RithamCore.ActivityType` directly; the PRD's "ride" is display language for the existing
/// `.cycle` case, never a second activity vocabulary.
public struct GoalEvent: Sendable, Equatable, Codable {
    public var id: UUID
    public var groupID: UUID
    public var name: String
    public var activityType: ActivityType
    public var target: GoalEventTarget
    public var startsOn: Date
    public var endsOn: Date
    public var organizerUserID: SocialUserID

    public init(
        id: UUID,
        groupID: UUID,
        name: String,
        activityType: ActivityType,
        target: GoalEventTarget,
        startsOn: Date,
        endsOn: Date,
        organizerUserID: SocialUserID
    ) {
        self.id = id
        self.groupID = groupID
        self.name = name
        self.activityType = activityType
        self.target = target
        self.startsOn = startsOn
        self.endsOn = endsOn
        self.organizerUserID = organizerUserID
    }
}

/// RSVP is individual ("I'm in"), shown pre-event only as a headcount -- a low-stakes
/// pre-commitment signal on a screen separate from the post-event completion feed.
public struct GoalEventRSVP: Sendable, Equatable, Codable {
    public var eventID: UUID
    public var userID: SocialUserID
    public var respondedAt: Date

    public init(eventID: UUID, userID: SocialUserID, respondedAt: Date) {
        self.eventID = eventID
        self.userID = userID
        self.respondedAt = respondedAt
    }
}

/// GROUPEVENTS-02: logging a completion is binary -- "done." No field here expresses position,
/// ordering, score, pooled total, or how many members completed; the only ordering input is
/// `postedAt`, chronological (`docs/group-events.md` Section 2: "Completions render in the feed
/// in the order they were posted, never sorted fastest-to-slowest"). `ownTimeSeconds` is optional,
/// off by default, the user's own choice each time -- never inferred, never required.
public struct GoalEventCompletion: Sendable, Equatable, Codable {
    public var id: UUID
    public var eventID: UUID
    public var user: SocialUser
    public var completedAt: Date
    public var ownTimeSeconds: Int?
    public var photoAssetID: String?
    public var placeName: String?
    public var caption: String?
    public var postedAt: Date

    public init(
        id: UUID,
        eventID: UUID,
        user: SocialUser,
        completedAt: Date,
        ownTimeSeconds: Int? = nil,
        photoAssetID: String? = nil,
        placeName: String? = nil,
        caption: String? = nil,
        postedAt: Date
    ) {
        self.id = id
        self.eventID = eventID
        self.user = user
        self.completedAt = completedAt
        self.ownTimeSeconds = ownTimeSeconds
        self.photoAssetID = photoAssetID
        self.placeName = placeName
        self.caption = caption
        self.postedAt = postedAt
    }
}

/// GROUPEVENTS-02/03: a completion's private, personal-log-only measurement -- distance,
/// duration, and whether a route was recorded. `docs/group-events.md` Section 2: this data "never
/// travels to the group feed, the certificate, or any export, by construction, not by a filter
/// someone could get wrong." This type is never referenced by any network request type in this
/// phase -- it is declared in its own file, apart from every group-visible type above, precisely
/// so that structural separation is checkable at a glance rather than relying on a filter inside
/// one shared struct (see this plan's threat model, T-04.1-06; plan 04.1-10's reflection-based
/// shape lock on the completion wire contract is the enforcing gate).
public struct PrivateCompletionDetail: Sendable, Equatable, Codable {
    public var completionID: UUID
    public var distanceMetres: Double?
    public var durationSeconds: Int?
    public var routeRecorded: Bool

    public init(
        completionID: UUID,
        distanceMetres: Double? = nil,
        durationSeconds: Int? = nil,
        routeRecorded: Bool
    ) {
        self.completionID = completionID
        self.distanceMetres = distanceMetres
        self.durationSeconds = durationSeconds
        self.routeRecorded = routeRecorded
    }
}
