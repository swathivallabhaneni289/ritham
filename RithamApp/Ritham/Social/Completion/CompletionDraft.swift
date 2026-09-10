import Foundation

/// GROUPEVENTS-02: the draft a person builds while logging a Goal-Event completion, before
/// anything reaches the server. This is the structural expression of the rule that personal
/// performance data never travels to the group by construction, not by a filter someone could get
/// wrong (docs/group-events.md §2): `PrivateOnly`'s values live in their own nested type, and
/// `outgoingRequest()` below reads only this draft's five group-shared fields -- `completedAt`,
/// `ownTimeSeconds`, `photo`, `placeName`, `caption` -- never `privateOnly`. The only way a
/// compiled program can be proven to do something is to test it: `CompletionLoggingTests` builds
/// two drafts that differ ONLY in their `privateOnly` values and asserts `outgoingRequest()`'s
/// encoded bytes are byte-for-byte identical between them.
struct CompletionDraft: Equatable {
    var completedAt: Date
    var ownTimeSeconds: Int?
    var photo: StrippedPhotoAsset?
    var placeName: String?
    var caption: String?
    var privateOnly = PrivateOnly()

    /// GROUPEVENTS-02/03: a completion's private, personal-log-only measurement -- distance and
    /// duration, visible only to the person who entered them. Declared as its own nested type,
    /// apart from every group-shared field above, specifically so the separation
    /// `outgoingRequest()` depends on is checkable at a glance (read that function's own body: it
    /// never names `privateOnly`) rather than requiring a reader to trace every field access
    /// through one flat struct. Mirrors `RithamCore.PrivateCompletionDetail`'s identical
    /// "declared apart" precedent (`GoalEventModels.swift`) -- that type is the persisted,
    /// server-round-tripped shape for a stored completion; this one is the transient, in-progress
    /// draft shape this screen edits before anything is sent.
    struct PrivateOnly: Equatable {
        var distanceMetres: Double?
        var durationSeconds: Int?
    }

    /// RFC3339, matching `events_handler.go`'s `time.Parse(time.RFC3339, req.CompletedAt)`. A
    /// computed property, not a stored `static let`: `CompletionDraft` is a plain struct with no
    /// actor isolation of its own (unlike `GoalEventsModel`/`GroupsModel`/`FriendsModel`'s own
    /// `ISO8601DateFormatter` statics, each safe only because their enclosing class is
    /// `@MainActor`), so a shared stored instance would trip Swift 6 strict concurrency's
    /// not-`Sendable`-shared-mutable-state check. A computed property has no shared storage to
    /// flag, at the cost of a fresh instance per call -- negligible here.
    private static var dateTimeFormatter: ISO8601DateFormatter { ISO8601DateFormatter() }

    /// Builds the exact request this draft sends to the group, mirroring `CompletionRequest`'s
    /// five-field Go contract character for character. Reads exactly five of this draft's own
    /// stored properties -- `completedAt`, `ownTimeSeconds`, `photo`, `placeName`, `caption` -- and
    /// nothing else. `privateOnly` is never named in this function's body; a later editor adding a
    /// `privateOnly`-derived field here would be reintroducing exactly the leak GROUPEVENTS-02
    /// exists to prevent, and `CompletionLoggingTests`'s byte-identical-encoding test exists to
    /// catch that regression the moment it happens, not just to document the intent.
    func outgoingRequest() -> CompletionRequest {
        CompletionRequest(
            completedAt: Self.dateTimeFormatter.string(from: completedAt),
            ownTimeSeconds: ownTimeSeconds,
            photoAssetID: photo?.assetID.uuidString,
            placeName: placeName,
            caption: caption
        )
    }
}
