import CoreLocation
import Foundation
import ImageIO
import Testing
import UIKit
import UniformTypeIdentifiers
import RithamCore
@testable import Ritham

// Phase 4.1 Plan 14's completion-logging draft, wire contract, client, and model (Task 1), photo
// attach (Task 2), and the completion screen itself (Task 3). Nested inside `KeychainTouchingSuites`
// (`KeychainTouchingSuites.swift`) because `CompletionClient` -> `SocialAPIClient` -> `SessionStore`
// writes to the real, process-shared Keychain -- it must be ordered relative to every other
// Keychain-touching suite, not only internally, matching `GoalEventsUITests`'s own identical
// precedent from this same phase.
//
// Run this suite with `-only-testing:RithamTests/KeychainTouchingSuites/CompletionLoggingTests`
// (the nested identifier), never the bare `-only-testing:RithamTests/CompletionLoggingTests` --
// the bare form matches zero tests once this suite is nested and exits 0, a silent false pass
// (04.1-07-SUMMARY.md's own documented precedent for this exact hazard).

/// A fresh, file-scoped `URLProtocol` stub -- deliberately its own type, not `GoalEventsStubURLProtocol`
/// or any other suite's stub, matching every stub type's own header comment on the cross-suite
/// shared-static-state race a second suite touching the same stub type would reintroduce.
final class CompletionStubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    static func reset() {
        requestHandler = nil
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = CompletionStubURLProtocol.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private func makeStubbedSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [CompletionStubURLProtocol.self]
    return URLSession(configuration: config)
}

private func jsonResponse(_ url: URL, status: Int = 200, body: String) -> (HTTPURLResponse, Data) {
    let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
    return (response, body.data(using: .utf8)!)
}

/// A call-counting `LocationFixProviding` stub -- returns a fixed fix (or `nil`) and records how
/// many times `currentFix()` was called, so `CompletionLoggingModel`'s "exactly once per attach"
/// behavior is provable, not just conventioned. An `actor`, not a plain class, matching
/// `PrivacyZoneTests.swift`'s own spy-resolver precedent -- isolates the call count so it is safe
/// to read from `async` test code without a data race, matching `LocationFixProviding`'s own
/// `Sendable` requirement. Named with a `Completion`-specific prefix (not the bare `SpyLocationFixProvider`
/// name) so it cannot collide with any other suite's own spy type in the same target.
actor CompletionSpyLocationFixProvider: LocationFixProviding {
    private(set) var callCount = 0
    private let fix: CLLocationCoordinate2D?

    init(fix: CLLocationCoordinate2D?) {
        self.fix = fix
    }

    func currentFix() async -> CLLocationCoordinate2D? {
        callCount += 1
        return fix
    }
}

/// A `CLLocationManager` subclass that never touches real location hardware -- both authorization
/// and location requests are no-ops -- so `SystemLocationFixProvider`'s own continuation-handling
/// logic (WR-02) can be exercised deterministically, without depending on the Simulator's absent
/// location hardware or on any authorization prompt.
private final class NoOpCLLocationManager: CLLocationManager {
    override func requestWhenInUseAuthorization() {}
    override func requestLocation() {}
}

/// A call-counting `PlaceNameResolving` stub, matching `PrivacyZoneTests.swift`'s own
/// `SpyPlaceNameResolver` in shape (an `actor`, same two members) but declared under its own,
/// `Completion`-prefixed name in this plan's own file, so this type never collides with that
/// file's `private` spy of the same base name at the target level.
actor CompletionSpyPlaceNameResolver: PlaceNameResolving {
    private(set) var callCount = 0
    private let name: String?

    init(name: String? = nil) {
        self.name = name
    }

    func placeName(for coordinate: CLLocationCoordinate2D) async -> String? {
        callCount += 1
        return name
    }
}

extension KeychainTouchingSuites {

@MainActor
@Suite("CompletionLoggingTests", .serialized)
struct CompletionLoggingTests {

    init() {
        CompletionStubURLProtocol.reset()
    }

    private func makeClient(handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)) -> CompletionClient {
        CompletionStubURLProtocol.requestHandler = handler
        let sessionStore = SessionStore()
        sessionStore.store(token: "test-token", expiresAt: Date().addingTimeInterval(3600), userID: "user-1", displayName: "Alex")
        let apiClient = SocialAPIClient(baseURL: URL(string: "http://127.0.0.1:8080")!, session: makeStubbedSession(), sessionStore: sessionStore)
        return CompletionClient(apiClient: apiClient)
    }

    private func encodedKeys(_ request: CompletionRequest) throws -> Set<String> {
        let data = try JSONEncoder().encode(request)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return Set((object ?? [:]).keys)
    }

    // MARK: - Task 1: the outgoing request's exact key set

    @Test("a draft with nothing beyond completedAt encodes exactly one key")
    func draftWithOnlyCompletedAtEncodesOneKey() throws {
        let draft = CompletionDraft(completedAt: Date())
        let keys = try encodedKeys(draft.outgoingRequest())
        #expect(keys == ["completedAt"], "omitting every optional field must omit every optional key entirely, never send null or a zero")
    }

    @Test("supplying an own time includes exactly one additional key beyond completedAt")
    func supplyingOwnTimeAddsExactlyOneKey() throws {
        var draft = CompletionDraft(completedAt: Date())
        draft.ownTimeSeconds = 1934
        let keys = try encodedKeys(draft.outgoingRequest())
        #expect(keys == ["completedAt", "ownTimeSeconds"])
    }

    @Test("a fully populated draft's request has exactly the five keys the Go contract names, no distance, pace, or route key")
    func fullyPopulatedDraftHasExactlyFiveKeys() throws {
        let uploadResponse = try JSONDecoder().decode(
            PhotoUploadResponse.self,
            from: #"{"photoAssetId":"\#(UUID().uuidString)","sharedUrl":"https://example.com/a.jpg"}"#.data(using: .utf8)!
        )
        var draft = CompletionDraft(completedAt: Date())
        draft.ownTimeSeconds = 1200
        draft.photo = try StrippedPhotoAsset(uploadResponse: uploadResponse)
        draft.placeName = "Griffith Park"
        draft.caption = "Great morning"
        let keys = try encodedKeys(draft.outgoingRequest())
        #expect(keys == ["completedAt", "ownTimeSeconds", "photoAssetId", "placeName", "caption"], "the Go contract names exactly these five keys, and no key beyond them ever appears")
        let bannedTokens = ["distance", "pace", "route"]
        for token in bannedTokens {
            #expect(!keys.contains { $0.lowercased().contains(token) }, "outgoing request key set \(keys) contains a banned token '\(token)'")
        }
    }

    // MARK: - Task 1: private-only values have no path into the outgoing request (T-04.1-84)

    @Test("two drafts differing only in privateOnly encode byte-identically, after first proving their privateOnly values genuinely differ")
    func privateOnlyValuesNeverAffectTheEncodedBytes() throws {
        let completedAt = Date()
        var withPrivateData = CompletionDraft(completedAt: completedAt)
        withPrivateData.privateOnly = CompletionDraft.PrivateOnly(distanceMetres: 5000, durationSeconds: 1800)

        var withoutPrivateData = CompletionDraft(completedAt: completedAt)
        withoutPrivateData.privateOnly = CompletionDraft.PrivateOnly(distanceMetres: nil, durationSeconds: nil)

        // Positive control, per 04.1-04-SUMMARY.md's own documented "prove the fixture actually
        // carries what the negative test assumes" discipline: if this assertion itself failed, the
        // byte-identical assertion below would be proving nothing.
        #expect(withPrivateData.privateOnly != withoutPrivateData.privateOnly, "the two drafts must genuinely differ in privateOnly, or the byte-identical assertion below is vacuous")

        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let withPrivateBytes = try encoder.encode(withPrivateData.outgoingRequest())
        let withoutPrivateBytes = try encoder.encode(withoutPrivateData.outgoingRequest())

        #expect(withPrivateBytes == withoutPrivateBytes, "a draft's privateOnly values must have zero effect on the encoded outgoing request")
    }

    // MARK: - Task 1: location outcome -> outgoing placeName key mapping

    @Test("a suppressed-by-zone location outcome produces a request with no placeName key")
    func suppressedByZoneProducesNoPlaceNameKey() async throws {
        let model = CompletionLoggingModel(
            client: makeClient { _ in throw URLError(.badServerResponse) },
            locationFixProvider: CompletionSpyLocationFixProvider(fix: CLLocationCoordinate2D(latitude: 34.1, longitude: -118.3)),
            geocoder: CompletionSpyPlaceNameResolver(name: "Should never be used")
        )
        let zone = PrivacyZone(label: "Home", centre: CLLocationCoordinate2D(latitude: 34.1, longitude: -118.3), radiusMetres: 150, effect: .suppress)

        await model.setLocationSharingEnabled(true, zones: [zone])

        let keys = try encodedKeys(model.draft.outgoingRequest())
        #expect(!keys.contains("placeName"))
        #expect(model.lastLocationOutcome == .suppressedByZone)
    }

    @Test("an unavailable/failed location outcome produces a request with no placeName key")
    func unavailableLocationProducesNoPlaceNameKey() async throws {
        let model = CompletionLoggingModel(
            client: makeClient { _ in throw URLError(.badServerResponse) },
            locationFixProvider: CompletionSpyLocationFixProvider(fix: nil),
            geocoder: CompletionSpyPlaceNameResolver(name: "Should never be used")
        )

        await model.setLocationSharingEnabled(true, zones: [])

        let keys = try encodedKeys(model.draft.outgoingRequest())
        #expect(!keys.contains("placeName"))
        #expect(model.lastLocationOutcome == .none)
    }

    @Test("a resolved place name produces exactly that string and nothing derived from a position")
    func resolvedPlaceNameProducesExactlyThatString() async throws {
        let model = CompletionLoggingModel(
            client: makeClient { _ in throw URLError(.badServerResponse) },
            locationFixProvider: CompletionSpyLocationFixProvider(fix: CLLocationCoordinate2D(latitude: 34.1, longitude: -118.3)),
            geocoder: CompletionSpyPlaceNameResolver(name: "Griffith Park")
        )

        await model.setLocationSharingEnabled(true, zones: [])

        #expect(model.draft.placeName == "Griffith Park")
        let keys = try encodedKeys(model.draft.outgoingRequest())
        #expect(keys.contains("placeName"))
    }

    // MARK: - Task 1: the model calls the resolve function's geocoder exactly once per attach, never on a zone match

    @Test("enabling location sharing calls currentFix() exactly once, and the geocoder zero times when a zone suppresses the fix")
    func locationResolveCallCountsOnZoneMatch() async throws {
        let fixProvider = CompletionSpyLocationFixProvider(fix: CLLocationCoordinate2D(latitude: 34.1, longitude: -118.3))
        let geocoder = CompletionSpyPlaceNameResolver(name: "Should never be called")
        let model = CompletionLoggingModel(client: makeClient { _ in throw URLError(.badServerResponse) }, locationFixProvider: fixProvider, geocoder: geocoder)
        let zone = PrivacyZone(label: "Home", centre: CLLocationCoordinate2D(latitude: 34.1, longitude: -118.3), radiusMetres: 150, effect: .suppress)

        await model.setLocationSharingEnabled(true, zones: [zone])

        #expect(await fixProvider.callCount == 1)
        #expect(await geocoder.callCount == 0)
    }

    @Test("enabling location sharing with no matching zone calls the geocoder exactly once")
    func locationResolveCallCountsWithNoZoneMatch() async throws {
        let fixProvider = CompletionSpyLocationFixProvider(fix: CLLocationCoordinate2D(latitude: 34.1, longitude: -118.3))
        let geocoder = CompletionSpyPlaceNameResolver(name: "Griffith Park")
        let model = CompletionLoggingModel(client: makeClient { _ in throw URLError(.badServerResponse) }, locationFixProvider: fixProvider, geocoder: geocoder)

        await model.setLocationSharingEnabled(true, zones: [])

        #expect(await fixProvider.callCount == 1)
        #expect(await geocoder.callCount == 1)
    }

    // MARK: - Task 1: photo and location opt-ins are independent in both directions (GROUPEVENTS-03)

    @Test("enabling photo sharing does not enable location sharing")
    func enablingPhotoSharingDoesNotEnableLocationSharing() {
        let model = CompletionLoggingModel(client: makeClient { _ in throw URLError(.badServerResponse) })
        let response = try! JSONDecoder().decode(PhotoUploadResponse.self, from: #"{"photoAssetId":"\#(UUID().uuidString)","sharedUrl":"https://example.com/a.jpg"}"#.data(using: .utf8)!)
        let asset = try! StrippedPhotoAsset(uploadResponse: response)

        model.attachPhoto(asset)

        #expect(model.isPhotoSharingEnabled == true)
        #expect(model.isLocationSharingEnabled == false, "attaching a photo must never enable location sharing")
    }

    @Test("enabling location sharing does not enable photo sharing")
    func enablingLocationSharingDoesNotEnablePhotoSharing() async {
        let model = CompletionLoggingModel(
            client: makeClient { _ in throw URLError(.badServerResponse) },
            locationFixProvider: CompletionSpyLocationFixProvider(fix: nil),
            geocoder: CompletionSpyPlaceNameResolver(name: nil)
        )

        await model.setLocationSharingEnabled(true, zones: [])

        #expect(model.isLocationSharingEnabled == true)
        #expect(model.isPhotoSharingEnabled == false, "enabling location sharing must never enable photo sharing")
    }

    // MARK: - Task 1: a failed log leaves the model in .failed with the draft intact

    @Test("a failed log moves to .failed and leaves the draft's own-time value intact for a retry")
    func failedLogLeavesDraftIntact() async throws {
        let eventID = UUID()
        let model = CompletionLoggingModel(client: makeClient { _ in throw URLError(.cannotConnectToHost) })

        await model.addTime(seconds: 754, eventID: eventID)

        guard case .failed(let error) = model.stage else {
            Issue.record("expected .failed, got \(model.stage)")
            return
        }
        #expect(error == .transport)
        #expect(model.draft.ownTimeSeconds == 754, "a failed submission must not discard what the person already entered")
    }

    @Test("retry(eventID:) resubmits the exact same draft the failed attempt held")
    func retryResubmitsTheSameDraft() async throws {
        let eventID = UUID()
        nonisolated(unsafe) var attempt = 0
        nonisolated(unsafe) var receivedOwnTime: Int?
        let model = CompletionLoggingModel(client: makeClient { request in
            attempt += 1
            if attempt == 1 {
                throw URLError(.cannotConnectToHost)
            }
            if let object = try? JSONSerialization.jsonObject(with: request.httpBodyOrStream()) as? [String: Any] {
                receivedOwnTime = object["ownTimeSeconds"] as? Int
            }
            return jsonResponse(request.url!, body: #"{"id":"c1","eventId":"\#(eventID.uuidString)","userId":"user-1","displayName":"Alex","completedAt":"2026-09-12T10:00:00Z","ownTimeSeconds":600,"postedAt":"2026-09-12T10:00:01Z"}"#)
        })

        await model.addTime(seconds: 600, eventID: eventID)
        #expect(model.stage == .failed(.transport))

        await model.retry(eventID: eventID)

        #expect(model.stage == .logged)
        #expect(receivedOwnTime == 600, "retry must resubmit the same own-time value the failed attempt already held, not a fresh/blank draft")
    }

    // MARK: - Task 1: skipping and adding a time both reach the network through the same path

    @Test("skipTime submits with no ownTimeSeconds key, and moves to .logged on success")
    func skipTimeSubmitsWithNoOwnTimeKey() async throws {
        let eventID = UUID()
        nonisolated(unsafe) var sentKeys: Set<String> = []
        let model = CompletionLoggingModel(client: makeClient { request in
            if let object = try? JSONSerialization.jsonObject(with: request.httpBodyOrStream()) as? [String: Any] {
                sentKeys = Set(object.keys)
            }
            return jsonResponse(request.url!, body: #"{"id":"c1","eventId":"\#(eventID.uuidString)","userId":"user-1","displayName":"Alex","completedAt":"2026-09-12T10:00:00Z","postedAt":"2026-09-12T10:00:01Z"}"#)
        })

        await model.skipTime(eventID: eventID)

        #expect(model.stage == .logged)
        #expect(!sentKeys.contains("ownTimeSeconds"))
    }

    // MARK: - Task 1: logDone() is local-only -- it must not touch the network

    @Test("logDone() moves to .addingTime without firing any network request")
    func logDoneIsLocalOnly() {
        nonisolated(unsafe) var requestFired = false
        let model = CompletionLoggingModel(client: makeClient { request in
            requestFired = true
            throw URLError(.badServerResponse)
        })

        model.logDone()

        #expect(model.stage == .addingTime)
        #expect(requestFired == false, "logDone() must be a purely local stage transition -- internal/events has no update route, so the network call must wait until the own-time decision is finalized")
    }

    // MARK: - Task 1: no CoreLocation type is named in CompletionLoggingModel.swift

    @Test("CompletionLoggingModel.swift names no CLGeocoder, CLLocationManager, or CLLocationCoordinate2D")
    func modelFileNamesNoCoreLocationType() throws {
        let fileURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Ritham/Social/Completion/CompletionLoggingModel.swift")
        let source = try String(contentsOf: fileURL, encoding: .utf8)
        for banned in ["CLGeocoder", "CLLocationManager", "CLLocationCoordinate2D"] {
            #expect(!source.contains(banned), "CompletionLoggingModel.swift names the CoreLocation type '\(banned)' -- it must reach location only through LocationFixProviding")
        }
    }

    // MARK: - Task 2: every transcoded output carries the JPEG magic header

    @Test("a HEIC-container picked item is transcoded to JPEG before upload")
    func heicInputTranscodesToJPEGMagicHeader() throws {
        let heicData = try #require(CompletionTestFixtures.syntheticImageData(utType: .heic), "this host could not encode a synthetic HEIC fixture -- ImageIO HEIC encoding must be available to exercise this behavior")
        let jpegData = try PhotoAttachment.encodableJPEG(from: heicData)
        #expect(Array(jpegData.prefix(3)) == [0xFF, 0xD8, 0xFF], "transcoded output must carry the JPEG magic header")
    }

    @Test("an already-JPEG picked item is still normalized through the same re-encode path")
    func alreadyJPEGInputIsStillNormalized() throws {
        let jpegInput = try #require(CompletionTestFixtures.syntheticImageData(utType: .jpeg))
        let jpegOutput = try PhotoAttachment.encodableJPEG(from: jpegInput)
        #expect(Array(jpegOutput.prefix(3)) == [0xFF, 0xD8, 0xFF], "an already-JPEG input must still come out through the same normalize path -- exactly one format ever leaves the device")
    }

    @Test("a PNG-container picked item is transcoded to JPEG before upload")
    func pngInputTranscodesToJPEGMagicHeader() throws {
        let pngData = try #require(CompletionTestFixtures.syntheticImageData(utType: .png))
        let jpegData = try PhotoAttachment.encodableJPEG(from: pngData)
        #expect(Array(jpegData.prefix(3)) == [0xFF, 0xD8, 0xFF])
    }

    @Test("unreadable bytes raise PhotoAttachmentError.unreadable rather than uploading anything")
    func unreadableBytesRaiseSentinel() {
        let garbage = Data([0x00, 0x01, 0x02, 0x03, 0x04])
        #expect {
            try PhotoAttachment.encodableJPEG(from: garbage)
        } throws: { error in
            (error as? PhotoAttachmentError) == .unreadable
        }
    }

    // MARK: - Task 2: the opaque asset value and its upload

    @Test("a successful upload yields the opaque asset carrying the server's asset id and shared URL")
    func successfulUploadYieldsOpaqueAsset() async throws {
        let assetID = UUID()
        let client = makeStubbedSocialAPIClient { request in
            jsonResponse(request.url!, body: #"{"photoAssetId":"\#(assetID.uuidString)","sharedUrl":"https://example.com/shared/a.jpg"}"#)
        }
        let asset = try await PhotoAttachment.upload(Data([0xFF, 0xD8, 0xFF]), via: client)
        #expect(asset.assetID == assetID)
        #expect(asset.sharedURL == URL(string: "https://example.com/shared/a.jpg"))
    }

    @Test("a failed upload throws, so the caller never has an asset to attach to the draft")
    func failedUploadThrowsAndAttachesNothing() async throws {
        let client = makeStubbedSocialAPIClient { _ in throw URLError(.cannotConnectToHost) }
        let model = CompletionLoggingModel(client: makeClient { _ in throw URLError(.badServerResponse) })

        await #expect(throws: (any Error).self) {
            _ = try await PhotoAttachment.upload(Data([0xFF, 0xD8, 0xFF]), via: client)
        }

        #expect(model.draft.photo == nil, "a failed upload must leave no photo attached to the draft -- attachPhoto(_:) is only ever called with a value this function actually returned")
    }

    // MARK: - Task 2: the opaque asset's only accessible initializer takes a PhotoUploadResponse

    @Test("StrippedPhotoAsset's only accessible initializer takes a PhotoUploadResponse -- pinned at compile time")
    func strippedPhotoAssetOnlyInitializerTakesUploadResponse() {
        let _: (PhotoUploadResponse) throws -> StrippedPhotoAsset = StrippedPhotoAsset.init
    }

    @Test("StrippedPhotoAsset.swift declares no initializer taking a URL, Data, or PhotosPickerItem")
    func strippedPhotoAssetSourceDeclaresNoDisallowedInitializer() throws {
        let fileURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Ritham/Social/Completion/StrippedPhotoAsset.swift")
        let source = try String(contentsOf: fileURL, encoding: .utf8)
        // `self.init(...)` is a delegating *call*, not a declaration -- excluded here so this
        // check only scans actual `init(` declaration signatures.
        let initLines = source
            .components(separatedBy: .newlines)
            .filter { $0.contains("init(") && !$0.contains("self.init(") }
        #expect(!initLines.isEmpty, "the scanned file must declare at least one initializer, or this check is vacuous")
        for line in initLines {
            let isAllowed = line.contains("assetID: UUID, sharedURL: URL") || line.contains("uploadResponse: PhotoUploadResponse")
            #expect(isAllowed, "StrippedPhotoAsset.swift declares an unexpected initializer: \(line)")
        }
        for disallowed in ["init(fileURL", "init(url:", "init(data:", "init(item:", "PhotosPickerItem)"] {
            #expect(!source.contains(disallowed), "StrippedPhotoAsset.swift must not declare an initializer taking \(disallowed)")
        }
    }

    @Test("grep -c 'private init' on StrippedPhotoAsset.swift is at least 1")
    func strippedPhotoAssetHasAPrivateInit() throws {
        let fileURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Ritham/Social/Completion/StrippedPhotoAsset.swift")
        let source = try String(contentsOf: fileURL, encoding: .utf8)
        let count = source.components(separatedBy: "private init").count - 1
        #expect(count >= 1)
    }

    // MARK: - Task 3: two distinct chip controls for the two attach opt-ins

    private func completionLoggingViewSource() throws -> String {
        let fileURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Ritham/Social/Completion/CompletionLoggingView.swift")
        return try String(contentsOf: fileURL, encoding: .utf8)
    }

    @Test("CompletionLoggingView references two distinct ChoiceQuestionView chip controls, one per attach opt-in")
    func viewReferencesTwoDistinctChipControls() throws {
        let source = try completionLoggingViewSource()
        let chipControlCount = source.components(separatedBy: "ChoiceQuestionView(").count - 1
        #expect(chipControlCount >= 2, "expected at least two ChoiceQuestionView chip controls -- one for photo attach, one for location attach")
        #expect(source.contains("SocialCopy.Completion.photoPrompt"), "the photo attach chip must be present")
        #expect(source.contains("SocialCopy.Completion.locationPrompt"), "the location attach chip must be present, and distinct from the photo chip")
    }

    @Test("CompletionLoggingView.swift contains zero platform switch constructions")
    func viewContainsNoToggleConstruction() throws {
        let source = try completionLoggingViewSource()
        #expect(!source.contains("Toggle"), "CompletionLoggingView.swift must use the two-option chip control, never SwiftUI's native switch")
    }

    @Test("CompletionLoggingView.swift renders at least two SecondaryCTAButtons, matching the equal-prominence pair")
    func viewRendersAtLeastTwoSecondaryCTAButtons() throws {
        let source = try completionLoggingViewSource()
        let count = source.components(separatedBy: "SecondaryCTAButton").count - 1
        #expect(count >= 2)
    }

    @Test("CompletionLoggingView.swift never types the caption field or footnote role")
    func viewNeverTypesCaptionOrFootnote() throws {
        let source = try completionLoggingViewSource()
        #expect(!source.contains(".caption"))
        #expect(!source.contains(".footnote"))
    }

    // MARK: - WR-02: SystemLocationFixProvider does not leak or misattribute an overlapping continuation

    @Test("SystemLocationFixProvider resumes a superseded prior currentFix() call with nil, rather than leaking its continuation or misattributing the next fix to it")
    func systemLocationFixProviderResumesSupersededCallWithNil() async throws {
        let provider = SystemLocationFixProvider(makeLocationManager: { NoOpCLLocationManager() })

        // Two overlapping calls, reproducing CompletionLoggingView's quick toggle-off/toggle-on
        // reachability path (WR-02's Issue section): the first call is still in flight (no
        // delegate callback has fired yet) when the second one starts.
        let firstTask = Task { await provider.currentFix() }
        await Task.yield()
        let secondTask = Task { await provider.currentFix() }
        await Task.yield()

        // The superseded first call must resolve to nil promptly -- never hang (a leaked
        // continuation) and never receive a real fix meant for the second call.
        let firstResult = await firstTask.value
        #expect(firstResult == nil, "a superseded prior currentFix() call must resolve to nil, not leak its continuation or hang forever")

        // The still-active second call is unaffected, and receives exactly the fix its own
        // manager's delegate callback reports.
        let coordinate = CLLocationCoordinate2D(latitude: 12.5, longitude: 45.5)
        provider.locationManager(NoOpCLLocationManager(), didUpdateLocations: [CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)])

        let secondResult = try #require(await secondTask.value)
        #expect(secondResult.latitude == coordinate.latitude)
        #expect(secondResult.longitude == coordinate.longitude)
    }
}

}

/// Test-only synthetic image fixtures, generated on the fly rather than committed as binary
/// files -- every image is a single flat-color 8x8 pixel, fully synthetic and non-personal,
/// matching 04.1-04-SUMMARY.md's own documented reasoning for never committing a real captured
/// photo's bytes (even indirectly) into source control. `nil` when this host's ImageIO cannot
/// encode the requested container (e.g. no HEIC codec available), so a test using it can report a
/// clear "this host" reason via `#require` rather than crashing opaquely.
enum CompletionTestFixtures {
    static func syntheticImageData(utType: UTType) -> Data? {
        let size = CGSize(width: 8, height: 8)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        guard let cgImage = image.cgImage else { return nil }
        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(mutableData, utType.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, cgImage, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return mutableData as Data
    }
}

@MainActor
private func makeStubbedSocialAPIClient(handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)) -> SocialAPIClient {
    CompletionStubURLProtocol.requestHandler = handler
    let sessionStore = SessionStore()
    sessionStore.store(token: "test-token", expiresAt: Date().addingTimeInterval(3600), userID: "user-1", displayName: "Alex")
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [CompletionStubURLProtocol.self]
    return SocialAPIClient(baseURL: URL(string: "http://127.0.0.1:8080")!, session: URLSession(configuration: config), sessionStore: sessionStore)
}

private extension URLRequest {
    /// `URLSession` converts a small JSON `httpBody` into an `httpBodyStream` before handing the
    /// request to a custom `URLProtocol` -- `httpBody` itself reads `nil` inside `startLoading()`,
    /// a well-known gotcha this helper works around by draining the stream when present, falling
    /// back to `httpBody` for any caller that never sees this conversion. Matches
    /// `FriendsUITests.swift`'s own identical precedent for this exact hazard.
    func httpBodyOrStream() -> Data {
        if let httpBody { return httpBody }
        guard let stream = httpBodyStream else { return Data() }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let bufferSize = 4096
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: bufferSize)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data
    }
}
