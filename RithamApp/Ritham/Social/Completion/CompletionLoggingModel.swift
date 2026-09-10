import Foundation

/// GROUPEVENTS-02/03: drives the completion-logging screen's five-stage flow. This file names no
/// CoreLocation framework type anywhere -- the geocoder type, the location-manager type, or the
/// raw coordinate type LocationAttachment.swift's resolve function takes -- enforced by this
/// plan's own acceptance grep against this file's own filename (see `04.1-14-PLAN.md`'s Task 1
/// acceptance criteria; deliberately not spelling those three type names literally in this comment
/// either, since the grep this gate runs does not filter comments). Location is obtained only by
/// calling `LocationAttachment.resolveSharedPlaceName` (plan 04.1-07's single owned
/// capture-zone-check-geocode-discard sequence) through the `LocationFixProviding` seam declared
/// in this same directory (`LocationFixProviding.swift`) -- that seam's own file, not this one, is
/// where the raw coordinate type is spelled out. Do not "simplify" this by inlining a
/// location-manager call here: that would both break this file's own acceptance gate and
/// reintroduce exactly the ordering risk 04.1-07's own header comment warns against -- a second,
/// separately planned call site that could drift out of sync with the capture-then-zone-check
/// sequence 04.1-07 owns.
///
/// **Single-POST sequencing, decided against the actual server contract, not the PRD copy table's
/// literal event order.** `internal/events` (04.1-10) exposes exactly one write route for a
/// completion -- `POST /v1/events/{id}/completions` -- and no update route: a second completion
/// for the same `(event, user)` pair is rejected outright (`ErrAlreadyCompleted`). So the own-time
/// decision, the photo, the location, and the private-only fields are all gathered *before* the
/// one network call fires, never after. Tapping the binary "done" CTA (`logDone()`) is therefore a
/// local-only transition into `.addingTime` -- it does not touch the network -- and the actual
/// `client.log(...)` call happens only once the own-time decision is finalized, from either
/// `skipTime(eventID:)` or `addTime(seconds:eventID:)`. This does not violate "logging a
/// completion takes one action": `docs/group-events.md` §2 states logging is binary ("done"), a
/// statement about there being no measurement required, not about the request having already left
/// the device. `.logged`'s own confirmation copy ("You did it! ... Logged for...") is rendered by
/// the view only once this stage is reached, i.e. only after the server has actually confirmed the
/// write -- never optimistically before it.
///
/// A failed call leaves `stage == .failed` with `draft` completely untouched, so retrying
/// (`retry(eventID:)`) resends exactly what was already entered -- nothing a person typed, picked,
/// or opted into is ever lost to a transport error.
@MainActor
@Observable
final class CompletionLoggingModel {
    enum Stage: Equatable {
        case ready
        case logging
        case logged
        case addingTime
        case failed(SocialAPIError)
    }

    private(set) var stage: Stage = .ready
    private(set) var draft: CompletionDraft

    /// Two independent, uncoupled opt-ins (GROUPEVENTS-03) -- enabling one never enables or
    /// disables the other, in either direction. `CompletionLoggingTests` asserts both directions
    /// explicitly, since a single-direction check would miss the bundling this rule exists to
    /// prevent.
    private(set) var isPhotoSharingEnabled = false
    private(set) var isLocationSharingEnabled = false

    /// The raw outcome of the most recent location resolve call, exposed so the view can render
    /// the Privacy Zone suppression note ("This location is private and won't be shown.") only for
    /// `.suppressedByZone`, and nothing at all for a resolution failure (`.none`) -- the "never
    /// fall back to something more precise" rule (`04.1-UI-SPEC.md`'s Location attach bullet). The
    /// value this exposes is never a coordinate, a radius, or a distance figure -- `SharedLocationOutcome`
    /// itself (`LocationAttachment.swift`) has no case capable of carrying one.
    private(set) var lastLocationOutcome: SharedLocationOutcome = .none

    private let client: CompletionClient
    private let locationFixProvider: LocationFixProviding
    private let geocoder: PlaceNameResolving

    init(
        client: CompletionClient = CompletionClient(apiClient: SocialAPIClient(sessionStore: SessionStore())),
        locationFixProvider: LocationFixProviding = SystemLocationFixProvider(),
        geocoder: PlaceNameResolving = SystemGeocoder(),
        now: @escaping () -> Date = Date.init
    ) {
        self.client = client
        self.locationFixProvider = locationFixProvider
        self.geocoder = geocoder
        self.draft = CompletionDraft(completedAt: now())
    }

    /// The binary "done" declaration (GROUPEVENTS-02). Purely local: moves to `.addingTime`, where
    /// the equal-prominence add-time/skip pair lives, and touches no network. See this type's own
    /// header comment for why the actual `POST` is deferred past this call.
    func logDone() {
        stage = .addingTime
    }

    /// The skip action -- reachable with exactly the same one tap as `addTime(seconds:eventID:)`
    /// below, never a second, harder-to-find path. Submits the draft with `ownTimeSeconds` left
    /// untouched (whatever it already was, `nil` unless a previous attempt already set it).
    func skipTime(eventID: UUID) async {
        await submit(eventID: eventID)
    }

    /// Records the chosen own time, then submits -- the two branches share `submit(eventID:)` so
    /// both reach the network through the exact same code path and the exact same
    /// `CompletionDraft.outgoingRequest()` call.
    func addTime(seconds: Int, eventID: UUID) async {
        draft.ownTimeSeconds = seconds
        await submit(eventID: eventID)
    }

    /// Resubmits the draft exactly as it currently stands -- the `.failed`-stage retry path.
    func retry(eventID: UUID) async {
        await submit(eventID: eventID)
    }

    /// Enables photo sharing and attaches `asset`. Never touches `isLocationSharingEnabled` in
    /// either direction.
    func attachPhoto(_ asset: StrippedPhotoAsset) {
        isPhotoSharingEnabled = true
        draft.photo = asset
    }

    /// Disables photo sharing and clears the attached asset, if any.
    func removePhoto() {
        isPhotoSharingEnabled = false
        draft.photo = nil
    }

    /// Enabling calls `LocationAttachment.resolveSharedPlaceName` exactly once, through
    /// `locationFixProvider` -- never touches `isPhotoSharingEnabled` in either direction.
    /// Disabling clears `draft.placeName` and `lastLocationOutcome` without any further resolve
    /// call. `zones` is supplied by the caller (the view owns `PrivacyZoneStore`, this model has
    /// no SwiftData context of its own) rather than loaded here.
    func setLocationSharingEnabled(_ enabled: Bool, zones: [PrivacyZone]) async {
        isLocationSharingEnabled = enabled
        guard enabled else {
            draft.placeName = nil
            lastLocationOutcome = .none
            return
        }
        let fix = await locationFixProvider.currentFix()
        let outcome = await LocationAttachment.resolveSharedPlaceName(fix: fix, zones: zones, geocoder: geocoder)
        lastLocationOutcome = outcome
        draft.placeName = Self.placeName(from: outcome)
    }

    /// Sets or clears the optional group-visible caption. An all-whitespace or empty string is
    /// treated as "no caption," never an empty-string key on the wire.
    func attachCaption(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        draft.caption = trimmed.isEmpty ? nil : trimmed
    }

    /// Sets the private-only distance, in metres, or clears it. Never read by
    /// `CompletionDraft.outgoingRequest()` -- see that function's own header comment.
    func setPrivateDistance(metres: Double?) {
        draft.privateOnly.distanceMetres = metres
    }

    /// Sets the private-only duration, in seconds, or clears it. Never read by
    /// `CompletionDraft.outgoingRequest()` -- see that function's own header comment.
    func setPrivateDuration(seconds: Int?) {
        draft.privateOnly.durationSeconds = seconds
    }

    private func submit(eventID: UUID) async {
        stage = .logging
        do {
            _ = try await client.log(eventID: eventID.uuidString, draft.outgoingRequest())
            stage = .logged
        } catch {
            stage = .failed(Self.socialError(error))
        }
    }

    private static func placeName(from outcome: SharedLocationOutcome) -> String? {
        switch outcome {
        case .none, .suppressedByZone:
            return nil
        case .generalizedByZone(let label):
            return label
        case .place(let name):
            return name
        }
    }

    private static func socialError(_ error: Error) -> SocialAPIError {
        (error as? SocialAPIError) ?? .transport
    }
}
