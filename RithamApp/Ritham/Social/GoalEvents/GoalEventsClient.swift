import Foundation

// Wire types for the Goal-Events surfaces a person interacts with before anyone has completed
// anything: creation, listing, detail, and the pre-event RSVP headcount (GROUPEVENTS-02). Every
// field mirrors RithamService/internal/httpapi/events_handler.go's JSON tags character for
// character, matching GroupsClient.swift's/FriendsClient.swift's own precedent from this same
// phase.
//
// The completion routes (POST/GET /v1/events/{id}/completions) are deliberately NOT declared
// here -- they are not this plan's concern (04.1-13-PLAN.md's own action text). Their absence is
// structural, not an oversight: it is what makes "this file carries no completion figure" true by
// construction rather than by a filter that could be got wrong, matching
// PrivateCompletionDetail's own "declared apart, so the separation is checkable at a glance"
// precedent (RithamCore/Sources/RithamCore/Social/GoalEventModels.swift).
//
// No request type below declares a field naming the acting user -- every mutating route reads the
// caller's identity from RequireSession's bearer-derived context server-side, never from the
// request body (T-04.1-35, matching every other social client in this phase).

/// Entire request body for `POST /v1/groups/{id}/events`. `startsOn`/`endsOn` are calendar dates
/// only (`"yyyy-MM-dd"`, matching `events_handler.go`'s own `dateLayout` constant) -- never
/// RFC3339, unlike every `createdAt` field in this phase's other wire types.
///
/// `targetValue` is declared with no `omitempty` on the Go side, so a `nil` `TargetValue` still
/// marshals as an explicit JSON `null`, keeping this request body at exactly six keys on every
/// call. Swift's synthesized `Encodable` conformance instead calls `encodeIfPresent` for every
/// `Optional` stored property, which OMITS the key entirely when `nil` -- a real mismatch from the
/// Go contract, not a hypothetical one. `encode(to:)` below is written by hand for this reason,
/// using `encode(_:forKey:)` (never `encodeIfPresent`) for `targetValue` so a genuinely optional
/// target still round-trips as an explicit `null`, distinguishable on the wire from a `0.0` value
/// a "zero target" would send.
struct CreateEventRequest: Encodable, Equatable {
    let name: String
    let activityType: String
    let targetKind: String
    let targetValue: Double?
    let startsOn: String
    let endsOn: String

    enum CodingKeys: String, CodingKey {
        case name
        case activityType
        case targetKind
        case targetValue
        case startsOn
        case endsOn
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(activityType, forKey: .activityType)
        try container.encode(targetKind, forKey: .targetKind)
        try container.encode(targetValue, forKey: .targetValue)
        try container.encode(startsOn, forKey: .startsOn)
        try container.encode(endsOn, forKey: .endsOn)
    }
}

/// Describes one `goal_events` row, from the caller's own point of view. Returned by create, list,
/// and get. `targetValue` carries `omitempty` on the Go side (unlike the request above), so it is
/// simply absent from the wire, not `null`, when there is no target -- Swift's synthesized
/// `Decodable` conformance already handles a missing key for an `Optional` property correctly, so
/// this type needs no custom `init(from:)`.
struct EventResponse: Decodable, Equatable, Identifiable {
    let id: String
    let groupId: String
    let name: String
    let activityType: String
    let targetKind: String
    let targetValue: Double?
    let startsOn: String
    let endsOn: String
    let organizerUserId: String
    let createdAt: String
}

/// Returned by `GET /v1/groups/{id}/events`.
struct EventsListResponse: Decodable, Equatable {
    let events: [EventResponse]
}

/// Returned by every RSVP route (respond/withdraw/state) -- a count and the viewer's own
/// membership in it, mirroring `events.RSVPState`'s own deliberate absence of a per-person roster
/// (`docs/group-events.md` §2). No field here, and no field anywhere else in this file, ever
/// carries a completion figure.
struct RSVPStateResponse: Decodable, Equatable {
    let count: Int
    let viewerIsIn: Bool
}

/// A request body with no fields, encoded as an empty JSON object. Mirrors `GroupsClient.swift`'s
/// own `EmptyBody` precedent: every route this file sends it to authenticates purely off the
/// bearer header and path parameters, never a decoded request body.
private struct EmptyBody: Encodable {}

/// The six Goal-Event/RSVP operations this plan's screens need -- a thin wrapper over
/// `SocialAPIClient`, matching `GroupsClient`/`FriendsClient`'s per-domain-client-over-shared-
/// client shape. No networking of its own.
struct GoalEventsClient {
    let apiClient: SocialAPIClient

    init(apiClient: SocialAPIClient) {
        self.apiClient = apiClient
    }

    /// `POST /v1/groups/{id}/events`, behind `RequireSession`. The caller becomes the created
    /// event's organizer server-side -- never a field this request states directly.
    func create(
        groupID: String,
        name: String,
        activityType: String,
        targetKind: String,
        targetValue: Double?,
        startsOn: String,
        endsOn: String
    ) async throws -> EventResponse {
        try await apiClient.send(
            "POST", "v1/groups/\(groupID)/events",
            body: CreateEventRequest(
                name: name,
                activityType: activityType,
                targetKind: targetKind,
                targetValue: targetValue,
                startsOn: startsOn,
                endsOn: endsOn
            )
        )
    }

    /// `GET /v1/groups/{id}/events`, behind `RequireSession`.
    func list(groupID: String) async throws -> [EventResponse] {
        let response: EventsListResponse = try await apiClient.get("v1/groups/\(groupID)/events")
        return response.events
    }

    /// `GET /v1/events/{id}`, behind `RequireSession`.
    func get(eventID: String) async throws -> EventResponse {
        try await apiClient.get("v1/events/\(eventID)")
    }

    /// `POST /v1/events/{id}/rsvp`, behind `RequireSession`. Idempotent server-side: responding
    /// twice leaves a count of one.
    func rsvp(eventID: String) async throws -> RSVPStateResponse {
        try await apiClient.send("POST", "v1/events/\(eventID)/rsvp", body: EmptyBody())
    }

    /// `DELETE /v1/events/{id}/rsvp`, behind `RequireSession`. A no-op server-side when no RSVP
    /// exists -- never an error.
    func withdrawRSVP(eventID: String) async throws -> RSVPStateResponse {
        try await apiClient.send("DELETE", "v1/events/\(eventID)/rsvp", body: EmptyBody())
    }

    /// `GET /v1/events/{id}/rsvp`, behind `RequireSession`. Served entirely off `event_rsvps`
    /// server-side -- never touches or implies anything about completions.
    func rsvpState(eventID: String) async throws -> RSVPStateResponse {
        try await apiClient.get("v1/events/\(eventID)/rsvp")
    }
}
