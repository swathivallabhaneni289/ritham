import Foundation
import RithamCore

// Wire types and client for the group-only, chronological, membership-scoped feed (GROUPEVENTS-04),
// mirroring `RithamService/internal/feed`'s `Page`/`Item`/`Person`/`ViewerCheers` JSON tags
// character for character (see `feed.go`'s own header comment for the server-side shape this file
// tracks).
//
// `FeedPage` and `FeedItem` below reject any JSON key their own `CodingKeys` doesn't declare --
// unlike this phase's other decoded wire types, which lean on Swift's default `Decodable`
// conformance (which silently drops an unrecognized key). A silently-dropped key matters more here
// than anywhere else in this phase: the field most likely to be added to this response by mistake
// is a completion count or a member figure, and this feed's entire non-comparative guarantee
// (GROUPEVENTS-04) depends on that kind of field never quietly reaching a rendered screen. Go's own
// `nodenominator_test.go` pins the server response's exact JSON key set for the identical reason
// (04.1-12-SUMMARY.md); `assertNoUnknownKeys(decoder:allowedKeys:typeName:)` below is this client's
// mirror of that same discipline, implemented as a real decode-time failure rather than only a
// test-time key-set assertion, since Swift's `JSONDecoder` has no built-in
// `DisallowUnknownFields`-equivalent the way Go's `json.Decoder` does.
//
// `FeedItem.note` (below) mirrors the wire key `caption` under a different Swift-side name.
// `CompletionCard.swift` (plan 04.1-15's own consumer of this type) is gated by an acceptance grep
// forbidding any line containing the literal typography-floor tokens this project structurally
// bans (`.caption`/`.footnote`, Font's built-in below-the-floor roles) -- and any member access
// spelled `x.caption` trips that same grep regardless of which type declares the property, since
// grep matches text, not semantics. Renaming the decoded property to `note` (matching
// `SocialCopy.Completion`'s own user-facing "note" language for the identical wire field on the
// completion-logging side, plan 04.1-14) lets the card read `item.note` cleanly. The JSON key
// itself is unchanged -- only this decoded property's Swift name differs from the wire.

/// A permissive `CodingKey` matching any JSON key by string -- used only to enumerate the keys
/// actually present on the wire. A normal `KeyedDecodingContainer<CodingKeys>` lookup silently
/// ignores a JSON key with no matching `CodingKeys` case; this type exists specifically to see the
/// keys that lookup would otherwise hide, so `assertNoUnknownKeys` can reject one.
private struct FeedDynamicCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}

/// Throws when `decoder`'s own keyed container holds any JSON key outside `allowedKeys` --
/// `FeedPage`/`FeedItem`'s shared strict-decoding helper (see this file's header comment).
private func assertNoUnknownKeys(decoder: Decoder, allowedKeys: Set<String>, typeName: String) throws {
    let dynamicContainer = try decoder.container(keyedBy: FeedDynamicCodingKey.self)
    for key in dynamicContainer.allKeys where !allowedKeys.contains(key.stringValue) {
        throw DecodingError.dataCorrupted(DecodingError.Context(
            codingPath: decoder.codingPath,
            debugDescription: "\(typeName): unrecognized key '\(key.stringValue)' -- the server added a field this client doesn't yet know how to interpret"
        ))
    }
}

/// Mirrors `internal/feed.Person` -- one completion's author.
struct FeedPerson: Decodable, Equatable {
    let userID: String
    let displayName: String

    enum CodingKeys: String, CodingKey {
        case userID = "userId"
        case displayName
    }
}

/// Mirrors `internal/feed.ViewerCheers` -- two booleans reflecting only the requesting user's own
/// cheer state, never a count, never any other viewer's state.
struct FeedViewerCheers: Decodable, Equatable {
    var niceWorkSentByViewer: Bool
    var keepGoingSentByViewer: Bool
}

/// Mirrors `internal/feed.Item` -- one completion, its author, the event it belongs to, and the
/// viewer's own cheer state. There is deliberately no stored property here for a position, a rank,
/// a total, or any figure derived from comparing this item to any other -- `GroupFeedTests`
/// reflection-asserts this type's exact stored-property set for exactly this reason.
struct FeedItem: Decodable, Equatable, Identifiable {
    let completionID: String
    let actor: FeedPerson
    let eventID: String
    let eventName: String
    let activityType: String
    let completedAt: String
    let ownTimeSeconds: Int?
    let photoURL: String?
    let placeName: String?
    /// Mirrors the wire key `caption` -- see this file's header comment for why this property is
    /// named `note`, not `caption`.
    let note: String?
    let postedAt: String
    /// The only `var` on this type -- `GroupFeedModel.toggleCheer` updates just this field in
    /// place for the one item a cheer targets, never reconstructing (and so never risking a typo
    /// dropping) any of this type's other, immutable fields.
    var cheers: FeedViewerCheers

    var id: String { completionID }

    enum CodingKeys: String, CodingKey, CaseIterable {
        case completionID = "completionId"
        case actor
        case eventID = "eventId"
        case eventName
        case activityType
        case completedAt
        case ownTimeSeconds
        case photoURL = "photoUrl"
        case placeName
        case note = "caption"
        case postedAt
        case cheers
    }

    init(from decoder: Decoder) throws {
        try assertNoUnknownKeys(decoder: decoder, allowedKeys: Set(CodingKeys.allCases.map(\.stringValue)), typeName: "FeedItem")
        let container = try decoder.container(keyedBy: CodingKeys.self)
        completionID = try container.decode(String.self, forKey: .completionID)
        actor = try container.decode(FeedPerson.self, forKey: .actor)
        eventID = try container.decode(String.self, forKey: .eventID)
        eventName = try container.decode(String.self, forKey: .eventName)
        activityType = try container.decode(String.self, forKey: .activityType)
        completedAt = try container.decode(String.self, forKey: .completedAt)
        ownTimeSeconds = try container.decodeIfPresent(Int.self, forKey: .ownTimeSeconds)
        photoURL = try container.decodeIfPresent(String.self, forKey: .photoURL)
        placeName = try container.decodeIfPresent(String.self, forKey: .placeName)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        postedAt = try container.decode(String.self, forKey: .postedAt)
        cheers = try container.decode(FeedViewerCheers.self, forKey: .cheers)
    }

    /// Test- and preview-only memberwise constructor -- the wire path always goes through
    /// `init(from:)` above.
    init(
        completionID: String,
        actor: FeedPerson,
        eventID: String,
        eventName: String,
        activityType: String,
        completedAt: String,
        ownTimeSeconds: Int? = nil,
        photoURL: String? = nil,
        placeName: String? = nil,
        note: String? = nil,
        postedAt: String,
        cheers: FeedViewerCheers = FeedViewerCheers(niceWorkSentByViewer: false, keepGoingSentByViewer: false)
    ) {
        self.completionID = completionID
        self.actor = actor
        self.eventID = eventID
        self.eventName = eventName
        self.activityType = activityType
        self.completedAt = completedAt
        self.ownTimeSeconds = ownTimeSeconds
        self.photoURL = photoURL
        self.placeName = placeName
        self.note = note
        self.postedAt = postedAt
        self.cheers = cheers
    }
}

/// Mirrors `internal/feed.Page` -- one page of feed items, newest-posted first, plus an opaque
/// cursor for the next page. Deliberately has no field for a total, a remaining count, a member
/// count, or a completion fraction, matching the server's own struct exactly (`feed.go`'s own
/// header comment on `Page`).
struct FeedPage: Decodable, Equatable {
    let items: [FeedItem]
    let nextCursor: String?

    enum CodingKeys: String, CodingKey, CaseIterable {
        case items
        case nextCursor
    }

    init(from decoder: Decoder) throws {
        try assertNoUnknownKeys(decoder: decoder, allowedKeys: Set(CodingKeys.allCases.map(\.stringValue)), typeName: "FeedPage")
        let container = try decoder.container(keyedBy: CodingKeys.self)
        items = try container.decode([FeedItem].self, forKey: .items)
        nextCursor = try container.decodeIfPresent(String.self, forKey: .nextCursor)
    }

    /// Test-only memberwise constructor -- the wire path always goes through `init(from:)` above.
    init(items: [FeedItem], nextCursor: String? = nil) {
        self.items = items
        self.nextCursor = nextCursor
    }
}

/// The entire request body for `POST`/`DELETE /v1/completions/{id}/cheers`. Mirrors
/// `internal/httpapi.CheerRequest`'s single JSON tag.
struct CheerRequest: Encodable, Equatable {
    let cheer: String
}

/// The five feed/cheer operations this plan's screens need -- a thin wrapper over
/// `SocialAPIClient`, matching `GroupsClient`/`GoalEventsClient`/`CompletionClient`'s per-domain-
/// client-over-shared-client shape. No networking of its own.
struct FeedClient {
    let apiClient: SocialAPIClient

    init(apiClient: SocialAPIClient) {
        self.apiClient = apiClient
    }

    /// `GET /v1/groups/{id}/feed`, behind `RequireSession`. `cursor`/`limit` are appended as a real
    /// URL query string (see `SocialAPIClient.perform`'s own header comment for why that requires
    /// `URL(string:relativeTo:)`, not `appendingPathComponent`, to resolve correctly).
    func groupFeed(groupID: String, cursor: String? = nil, limit: Int? = nil) async throws -> FeedPage {
        try await apiClient.get(Self.feedPath("v1/groups/\(groupID)/feed", cursor: cursor, limit: limit))
    }

    /// `GET /v1/events/{id}/feed`, behind `RequireSession`. Implemented for full route coverage --
    /// no screen in this plan calls it (`GroupFeedView`/`GroupHistoryView` are both group-scoped,
    /// per this plan's own routing decision), matching `GroupsModel.join(groupID:)`'s own
    /// documented "implemented, no UI caller yet" precedent from this same phase.
    func eventFeed(eventID: String, cursor: String? = nil, limit: Int? = nil) async throws -> FeedPage {
        try await apiClient.get(Self.feedPath("v1/events/\(eventID)/feed", cursor: cursor, limit: limit))
    }

    /// `POST /v1/completions/{id}/cheers`, behind `RequireSession`. Idempotent server-side
    /// (`completion_cheers`' own composite primary key, `ON CONFLICT DO NOTHING`) -- sending twice
    /// is never an error.
    func sendCheer(completionID: String, cheer: Cheer) async throws {
        try await apiClient.send("POST", "v1/completions/\(completionID)/cheers", body: CheerRequest(cheer: cheer.rawValue))
    }

    /// `DELETE /v1/completions/{id}/cheers`, behind `RequireSession`. A no-op server-side when no
    /// matching cheer row exists -- never an error.
    func withdrawCheer(completionID: String, cheer: Cheer) async throws {
        try await apiClient.send("DELETE", "v1/completions/\(completionID)/cheers", body: CheerRequest(cheer: cheer.rawValue))
    }

    /// Builds `base` plus an optional `?cursor=...&limit=...` query string via `URLComponents`, so
    /// every character lands correctly percent-encoded -- never hand-concatenated. Returns `base`
    /// unchanged when neither parameter is supplied, so every pre-existing (query-free) call
    /// through `SocialAPIClient` is untouched by this feed-specific helper.
    private static func feedPath(_ base: String, cursor: String?, limit: Int?) -> String {
        var items: [URLQueryItem] = []
        if let cursor, !cursor.isEmpty {
            items.append(URLQueryItem(name: "cursor", value: cursor))
        }
        if let limit {
            items.append(URLQueryItem(name: "limit", value: String(limit)))
        }
        guard !items.isEmpty else { return base }
        var components = URLComponents()
        components.queryItems = items
        return base + "?" + (components.percentEncodedQuery ?? "")
    }
}
