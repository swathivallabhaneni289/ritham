import Foundation
import RithamCore

/// Drives Goal-Event creation, listing, and the pre-event RSVP headcount at the model level,
/// following `GroupsModel`'s `@Observable`-load-from-source shape. Converts `GoalEventsClient`'s
/// wire types into `RithamCore`'s already-existing pure-domain types (`GoalEvent`/
/// `GoalEventTarget`, plan 04.1-02) rather than declaring a second, parallel set of domain types.
///
/// **This type has no property carrying a roster or a completion figure, by construction.** Its
/// only stored properties are `events` (a plain list of Goal-Events, never a "who's in" list),
/// `rsvpCount`/`viewerIsIn` (mirroring `RSVPState`'s own deliberate two-field shape -- a count and
/// a boolean, nothing else), and `state`. `GoalEventsUITests` asserts this by reflection over this
/// type's own stored properties, not just by reading this comment.
///
/// **The upcoming filter is the whole mechanism behind silent closing** (`docs/group-events.md`
/// §2): an event past its window is simply absent from `upcoming`, the list a screen renders, by
/// omission -- there is no second, `closedEvents`-shaped collection anywhere on this type that a
/// future screen could accidentally render. When a Goal-Event's window passes, nothing changes
/// visually for anyone who did not complete it: no banner, no strikethrough, no "missed" tag. It
/// just stops appearing.
///
/// `endsOn` is an **inclusive whole UTC day**, matching `internal/events`' own `withinEventWindow`
/// convention (04.1-10-SUMMARY.md's own carried-forward note): an event ending "2026-09-12" is
/// still upcoming for the entirety of that UTC day, closing only once UTC midnight the following
/// day arrives. `now` is injected (defaulting to `Date.init`) rather than read directly, so this
/// boundary is deterministically testable without waiting for a real clock to cross it.
@MainActor
@Observable
final class GoalEventsModel {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(SocialAPIError)
    }

    private(set) var events: [GoalEvent] = []
    private(set) var rsvpCount: Int = 0
    private(set) var viewerIsIn: Bool = false
    private(set) var state: LoadState = .idle

    private let client: GoalEventsClient
    private let now: () -> Date

    /// Calendar-date-only formatter for `startsOn`/`endsOn` -- `"yyyy-MM-dd"`, POSIX locale, UTC
    /// time zone, matching `events_handler.go`'s own `dateLayout` constant exactly. Deliberately a
    /// *separate* formatter from `dateTimeFormatter` below: reusing an `ISO8601DateFormatter` for
    /// a bare calendar date (no time-of-day, no zone offset in the string) fails to parse and
    /// silently drops every event out of `compactMap`, which is exactly the kind of failure this
    /// plan's own `must_haves` truth about a closed event ("shows nothing... no banner") must never
    /// be confused with -- a parse failure is a bug, not a closed event.
    private static let dateOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()

    /// RFC3339 formatter for `createdAt` only.
    private static let dateTimeFormatter = ISO8601DateFormatter()

    init(
        client: GoalEventsClient = GoalEventsClient(apiClient: SocialAPIClient(sessionStore: SessionStore())),
        now: @escaping () -> Date = Date.init
    ) {
        self.client = client
        self.now = now
    }

    /// Goal-Events whose window has not yet closed, per this type's own header comment on the
    /// inclusive-whole-UTC-day convention. Computed, not stored: there is no second array this
    /// property reads from, and no screen composing this model can reach a closed event through
    /// any other property.
    var upcoming: [GoalEvent] {
        let reference = now()
        return events.filter { $0.endsOn.addingTimeInterval(24 * 60 * 60) > reference }
    }

    /// Loads every Goal-Event in `groupID`. A throw leaves `events` exactly as it was before this
    /// call -- matching `GroupsModel.load()`'s "assignment only runs once the source call has
    /// fully succeeded" discipline (T-04.1-26: an unreachable service must read as an error, never
    /// an empty or unchanged-looking result treated as success).
    func load(groupID: UUID) async {
        state = .loading
        do {
            let responses = try await client.list(groupID: groupID.uuidString)
            events = responses.compactMap(Self.goalEvent)
            state = .loaded
        } catch {
            state = .failed(Self.socialError(error))
        }
    }

    /// Fetches a single Goal-Event by id, without mutating `events`. Returns `nil` on any failure
    /// (moving `state` to `.failed`) or an undecodable response.
    func get(eventID: UUID) async -> GoalEvent? {
        do {
            let response = try await client.get(eventID: eventID.uuidString)
            state = .loaded
            return Self.goalEvent(response)
        } catch {
            state = .failed(Self.socialError(error))
            return nil
        }
    }

    /// Creates a Goal-Event, then reloads `groupID`'s event list so `events` reflects the new row.
    /// Returns the newly created event's domain value, or `nil` on any failure or an undecodable
    /// response.
    @discardableResult
    func create(
        groupID: UUID,
        name: String,
        activityType: ActivityType,
        target: GoalEventTarget,
        startsOn: Date,
        endsOn: Date
    ) async -> GoalEvent? {
        do {
            let (targetKind, targetValue) = Self.wireTarget(target)
            let response = try await client.create(
                groupID: groupID.uuidString,
                name: name,
                activityType: activityType.rawValue,
                targetKind: targetKind,
                targetValue: targetValue,
                startsOn: Self.dateOnlyFormatter.string(from: startsOn),
                endsOn: Self.dateOnlyFormatter.string(from: endsOn)
            )
            guard let event = Self.goalEvent(response) else { return nil }
            await load(groupID: groupID)
            return event
        } catch {
            state = .failed(Self.socialError(error))
            return nil
        }
    }

    /// Records the viewer's own "I'm in," idempotently -- responding twice leaves `rsvpCount`
    /// exactly where it was after the first response, per `RSVPState`'s own server-side guarantee.
    func rsvp(eventID: UUID) async {
        do {
            let response = try await client.rsvp(eventID: eventID.uuidString)
            rsvpCount = response.count
            viewerIsIn = response.viewerIsIn
            state = .loaded
        } catch {
            state = .failed(Self.socialError(error))
        }
    }

    /// Withdraws the viewer's own RSVP, if one exists.
    func withdrawRSVP(eventID: UUID) async {
        do {
            let response = try await client.withdrawRSVP(eventID: eventID.uuidString)
            rsvpCount = response.count
            viewerIsIn = response.viewerIsIn
            state = .loaded
        } catch {
            state = .failed(Self.socialError(error))
        }
    }

    /// Loads the current headcount and the viewer's own membership in it, without touching or
    /// implying anything about completions.
    func loadRSVPState(eventID: UUID) async {
        do {
            let response = try await client.rsvpState(eventID: eventID.uuidString)
            rsvpCount = response.count
            viewerIsIn = response.viewerIsIn
            state = .loaded
        } catch {
            state = .failed(Self.socialError(error))
        }
    }

    // MARK: - Wire <-> domain conversion

    private static func goalEvent(_ response: EventResponse) -> GoalEvent? {
        guard
            let id = UUID(uuidString: response.id),
            let groupID = UUID(uuidString: response.groupId),
            let startsOn = dateOnlyFormatter.date(from: response.startsOn),
            let endsOn = dateOnlyFormatter.date(from: response.endsOn),
            let target = domainTarget(kind: response.targetKind, value: response.targetValue)
        else { return nil }
        return GoalEvent(
            id: id,
            groupID: groupID,
            name: response.name,
            activityType: ActivityType(rawValue: response.activityType),
            target: target,
            startsOn: startsOn,
            endsOn: endsOn,
            organizerUserID: SocialUserID(value: response.organizerUserId)
        )
    }

    /// `nil` only on a genuinely malformed wire value (an unknown `targetKind`, or a
    /// distance/duration kind missing its value) -- every valid combination the server can return
    /// converts cleanly. A `.none` target's `nil` *value* (`response.targetValue`) is preserved as
    /// `GoalEventTarget.none`, never coerced into a `0`-valued distance or duration, which is
    /// exactly the "distinguishable from a zero target" property this plan's own `<behavior>` list
    /// requires.
    ///
    /// The `GoalEventTarget.none` case is spelled out fully qualified below, never as a bare
    /// `.none` -- this function's own return type is `GoalEventTarget?`, and a bare `.none` in
    /// that context resolves to `Optional<GoalEventTarget>.none` (nil) rather than
    /// `.some(GoalEventTarget.none)`, a genuine Swift disambiguation trap when an enum declares a
    /// case that shares Optional's own `none` case name. Caught by this file's own test suite
    /// during authoring: every event silently vanished from `compactMap`, exactly the "distinct
    /// from a zero target" bug this comment now documents.
    private static func domainTarget(kind: String, value: Double?) -> GoalEventTarget? {
        switch kind {
        case "none":
            return GoalEventTarget.none
        case "distance":
            guard let value else { return nil }
            return .distance(metres: value)
        case "duration":
            guard let value else { return nil }
            return .duration(seconds: Int(value))
        default:
            return nil
        }
    }

    /// The inverse of `domainTarget(kind:value:)`, for `create`'s outbound request.
    private static func wireTarget(_ target: GoalEventTarget) -> (kind: String, value: Double?) {
        switch target {
        case .none:
            return ("none", nil)
        case .distance(let metres):
            return ("distance", metres)
        case .duration(let seconds):
            return ("duration", Double(seconds))
        }
    }

    private static func socialError(_ error: Error) -> SocialAPIError {
        (error as? SocialAPIError) ?? .transport
    }
}
