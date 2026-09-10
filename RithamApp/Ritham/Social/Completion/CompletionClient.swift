import Foundation

/// Mirrors `RithamService/internal/httpapi/events_handler.go`'s `CompletionRequest` JSON tags
/// character for character -- the entire request body for `POST /v1/events/{id}/completions`.
/// Exactly five fields: `completedAt` (required), and four optional fields
/// (`ownTimeSeconds`/`photoAssetId`/`placeName`/`caption`). No field here, and no field this type
/// could gain by a filter, expresses a personal distance, pace, or route -- GROUPEVENTS-02 keeps
/// that data in `CompletionDraft.PrivateOnly`, never read by `CompletionDraft.outgoingRequest()`.
/// The field count and JSON key set are asserted by `CompletionLoggingTests`, matching
/// `events_handler.go`'s own reflection-locked discipline on the Go side (04.1-10-SUMMARY.md).
///
/// Deliberately NOT hand-rolling `encode(to:)` the way `CreateEventRequest` does
/// (`GoalEventsClient.swift`): that type forces an explicit JSON `null` because its Go sibling has
/// no `omitempty` and the server always expects six keys present on every call. `CompletionRequest`
/// on the Go side also carries no `omitempty` on its own struct tags, but Go's `omitempty` only
/// changes *encoding* behavior, never *decoding* -- `decodeJSONBody` (events_handler.go, via
/// `friends_handler.go`'s shared helper) uses `json.NewDecoder(...).DisallowUnknownFields()`, which
/// rejects an unrecognized key but never requires a key's presence. A request that omits
/// `ownTimeSeconds`/`photoAssetId`/`placeName`/`caption` entirely decodes identically to one
/// sending them as explicit `null`. Swift's synthesized `Encodable` conformance already calls
/// `encodeIfPresent` for every `Optional` stored property, which is exactly the "omit the key when
/// nil" behavior GROUPEVENTS-02's own behavior list requires here -- no custom `encode(to:)`
/// needed.
struct CompletionRequest: Encodable, Equatable {
    let completedAt: String
    let ownTimeSeconds: Int?
    let photoAssetID: String?
    let placeName: String?
    let caption: String?

    enum CodingKeys: String, CodingKey {
        case completedAt
        case ownTimeSeconds
        case photoAssetID = "photoAssetId"
        case placeName
        case caption
    }
}

/// Describes one `event_completions` row, joined with its author's identity. Mirrors
/// `CompletionResponse`'s JSON tags -- `omitempty` on every optional field server-side, so a
/// completion logged without an own time has no `ownTimeSeconds` key on the wire at all, not a
/// null value.
struct CompletionResponse: Decodable, Equatable, Identifiable {
    let id: String
    let eventID: String
    let userID: String
    let displayName: String
    let completedAt: String
    let ownTimeSeconds: Int?
    let photoAssetID: String?
    let placeName: String?
    let caption: String?
    let postedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case eventID = "eventId"
        case userID = "userId"
        case displayName
        case completedAt
        case ownTimeSeconds
        case photoAssetID = "photoAssetId"
        case placeName
        case caption
        case postedAt
    }
}

/// Returned by `GET /v1/events/{id}/completions`.
struct CompletionsListResponse: Decodable, Equatable {
    let completions: [CompletionResponse]
}

/// The two completion operations this plan's screen needs -- a thin wrapper over
/// `SocialAPIClient`, matching `GoalEventsClient`/`GroupsClient`'s per-domain-client-over-shared-
/// client shape. No networking of its own.
struct CompletionClient {
    let apiClient: SocialAPIClient

    init(apiClient: SocialAPIClient) {
        self.apiClient = apiClient
    }

    /// `POST /v1/events/{id}/completions`, behind `RequireSession`. The caller's identity comes
    /// from the bearer header server-side, never from `request`.
    func log(eventID: String, _ request: CompletionRequest) async throws -> CompletionResponse {
        try await apiClient.send("POST", "v1/events/\(eventID)/completions", body: request)
    }

    /// `GET /v1/events/{id}/completions`, behind `RequireSession`. In post order only, per
    /// `events.Service.Completions` -- never re-sorted client-side (docs/group-events.md §2).
    func completions(eventID: String) async throws -> [CompletionResponse] {
        let response: CompletionsListResponse = try await apiClient.get("v1/events/\(eventID)/completions")
        return response.completions
    }
}
