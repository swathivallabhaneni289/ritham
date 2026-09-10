import CoreLocation
import Foundation
import Testing
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
}

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
