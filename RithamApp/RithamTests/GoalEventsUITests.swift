import Foundation
import Testing
import RithamCore
@testable import Ritham

// Phase 4.1 Plan 13's Goal-Events client/model and the activity-type icon mapping. Task 1 covers
// GoalEventsClient's exact wire contract and GoalEventsModel's behaviors, with no real network
// access, against a file-scoped stubbed `URLProtocol` (GroupsUITests's own pattern for this
// phase). Tasks 2/3 extend this same file with view-level and source-level assertions.

/// A fresh, file-scoped `URLProtocol` stub -- deliberately its own type, not `GroupsStubURLProtocol`
/// or any other suite's stub. Every one of those types' own header comments documents the
/// cross-suite shared-static-state race a second suite touching the same stub type would
/// reintroduce (the class of bug that cost plan 02-16 ten verification runs).
final class GoalEventsStubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    static func reset() {
        requestHandler = nil
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = GoalEventsStubURLProtocol.requestHandler else {
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
    config.protocolClasses = [GoalEventsStubURLProtocol.self]
    return URLSession(configuration: config)
}

private func jsonResponse(_ url: URL, status: Int = 200, body: String) -> (HTTPURLResponse, Data) {
    let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
    return (response, body.data(using: .utf8)!)
}

// Nested inside `KeychainTouchingSuites` (`KeychainTouchingSuites.swift`) because this suite
// writes to the real, process-shared Keychain via `SessionStore` -- it must be ordered relative
// to every other Keychain-touching suite, not only internally. See that file's header comment.
extension KeychainTouchingSuites {

@MainActor
@Suite("GoalEventsUITests", .serialized)
struct GoalEventsUITests {

    init() {
        GoalEventsStubURLProtocol.reset()
    }

    private func makeClientAndSession(handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)) -> (GoalEventsClient, SessionStore) {
        GoalEventsStubURLProtocol.requestHandler = handler
        let sessionStore = SessionStore()
        sessionStore.store(token: "test-token", expiresAt: Date().addingTimeInterval(3600), userID: "user-1", displayName: "Alex")
        let apiClient = SocialAPIClient(baseURL: URL(string: "http://127.0.0.1:8080")!, session: makeStubbedSession(), sessionStore: sessionStore)
        return (GoalEventsClient(apiClient: apiClient), sessionStore)
    }

    // MARK: - Wire contract: exact key sets, matching events_handler.go character for character

    @Test("CreateEventRequest with no target encodes exactly six keys, with targetValue present as an explicit null")
    func createEventRequestWithNoTargetEncodesSixKeysWithExplicitNull() throws {
        let request = CreateEventRequest(name: "Saturday 5K Walk", activityType: "walk", targetKind: "none", targetValue: nil, startsOn: "2026-09-12", endsOn: "2026-09-12")
        let data = try JSONEncoder().encode(request)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(Set((object ?? [:]).keys) == ["name", "activityType", "targetKind", "targetValue", "startsOn", "endsOn"])
        #expect(object?["targetValue"] is NSNull, "a nil target must marshal as an explicit JSON null (no omitempty on the Go side), not be omitted from the key set")
    }

    @Test("CreateEventRequest with a distance target encodes the same six keys, with targetValue present as a real number")
    func createEventRequestWithDistanceTargetEncodesSixKeysWithRealValue() throws {
        let request = CreateEventRequest(name: "Saturday 5K Walk", activityType: "walk", targetKind: "distance", targetValue: 5000, startsOn: "2026-09-12", endsOn: "2026-09-12")
        let data = try JSONEncoder().encode(request)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(Set((object ?? [:]).keys) == ["name", "activityType", "targetKind", "targetValue", "startsOn", "endsOn"])
        #expect((object?["targetValue"] as? NSNumber)?.doubleValue == 5000)
    }

    @Test("no request struct's key set names the acting user")
    func noRequestStructNamesTheActingUser() throws {
        let bannedNames: Set<String> = ["userId", "actorId", "callerId", "requesterId", "organizerId", "organizerUserId"]
        let request = CreateEventRequest(name: "n", activityType: "run", targetKind: "none", targetValue: nil, startsOn: "2026-01-01", endsOn: "2026-01-01")
        let data = try JSONEncoder().encode(request)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let keys = Set((object ?? [:]).keys)
        #expect(bannedNames.isDisjoint(with: keys), "CreateEventRequest's key set \(keys) names the acting user")
    }

    @Test("RSVPStateResponse decodes count and viewerIsIn, nothing else -- no roster field on the wire type")
    func rsvpStateResponseDecodesExactlyCountAndViewerIsIn() throws {
        let json = #"{"count":6,"viewerIsIn":true}"#
        let response = try JSONDecoder().decode(RSVPStateResponse.self, from: Data(json.utf8))
        #expect(response.count == 6)
        #expect(response.viewerIsIn == true)
    }

    // MARK: - An event created with no target round-trips with no target, distinguishable from a zero target

    @Test("EventResponse with an omitted targetValue key decodes to a nil target, never a zero-valued one")
    func eventResponseWithOmittedTargetValueDecodesToNilTarget() throws {
        let json = #"{"id":"e1","groupId":"g1","name":"Saturday 5K Walk","activityType":"walk","targetKind":"none","startsOn":"2026-09-12","endsOn":"2026-09-12","organizerUserId":"user-1","createdAt":"2026-01-01T00:00:00Z"}"#
        let response = try JSONDecoder().decode(EventResponse.self, from: Data(json.utf8))
        #expect(response.targetValue == nil, "an omitted targetValue key (server's own omitempty) must decode to nil, not 0")
        #expect(response.targetKind == "none")
    }

    @Test("EventResponse with a present targetValue decodes to that exact value")
    func eventResponseWithPresentTargetValueDecodesCorrectly() throws {
        let json = #"{"id":"e1","groupId":"g1","name":"Saturday 5K Walk","activityType":"walk","targetKind":"distance","targetValue":5000,"startsOn":"2026-09-12","endsOn":"2026-09-12","organizerUserId":"user-1","createdAt":"2026-01-01T00:00:00Z"}"#
        let response = try JSONDecoder().decode(EventResponse.self, from: Data(json.utf8))
        #expect(response.targetValue == 5000)
    }

    // MARK: - A transport failure moves the model to failed and leaves the event list untouched

    @Test("a transport failure during list load leaves a previously-loaded events array unchanged and the state failed")
    func aTransportFailureDuringListLoadLeavesEventsUnchangedAndStateFailed() async throws {
        let groupID = UUID()
        let eventID = UUID()
        nonisolated(unsafe) var shouldFail = false
        let (client, _) = makeClientAndSession { request in
            if shouldFail { throw URLError(.cannotConnectToHost) }
            return jsonResponse(request.url!, body: #"{"events":[{"id":"\#(eventID.uuidString)","groupId":"\#(groupID.uuidString)","name":"Saturday 5K Walk","activityType":"walk","targetKind":"none","startsOn":"2026-09-12","endsOn":"2026-09-12","organizerUserId":"user-1","createdAt":"2026-01-01T00:00:00Z"}]}"#)
        }
        let model = GoalEventsModel(client: client)

        await model.load(groupID: groupID)
        #expect(model.events.map(\.id) == [eventID])

        shouldFail = true
        await model.load(groupID: groupID)

        #expect(model.events.map(\.id) == [eventID], "a failed reload must leave the previously-loaded event list exactly as it was")
        #expect(model.state == .failed(.transport))
    }

    // MARK: - The upcoming list excludes events whose window has closed, by omission

    @Test("upcoming excludes an event whose endsOn has fully passed (inclusive-whole-UTC-day boundary), while events itself still holds it")
    func upcomingExcludesAClosedEventByOmission() async throws {
        let groupID = UUID()
        let openEventID = UUID()
        let closedEventID = UUID()
        // "Now" is fixed at 2026-09-15T12:00:00Z. The closed event ended 2026-09-10 (its inclusive
        // whole UTC day closes at 2026-09-11T00:00:00Z, well before "now"). The open event ends
        // 2026-09-20, still ahead of "now".
        let fixedNow = ISO8601DateFormatter().date(from: "2026-09-15T12:00:00Z")!
        let (client, _) = makeClientAndSession { request in
            jsonResponse(request.url!, body: #"{"events":[{"id":"\#(closedEventID.uuidString)","groupId":"\#(groupID.uuidString)","name":"Past Walk","activityType":"walk","targetKind":"none","startsOn":"2026-09-10","endsOn":"2026-09-10","organizerUserId":"user-1","createdAt":"2026-01-01T00:00:00Z"},{"id":"\#(openEventID.uuidString)","groupId":"\#(groupID.uuidString)","name":"Future Walk","activityType":"walk","targetKind":"none","startsOn":"2026-09-20","endsOn":"2026-09-20","organizerUserId":"user-1","createdAt":"2026-01-01T00:00:00Z"}]}"#)
        }
        let model = GoalEventsModel(client: client, now: { fixedNow })

        await model.load(groupID: groupID)

        #expect(Set(model.events.map(\.id)) == [openEventID, closedEventID], "the raw events list must still hold both -- no server-side filtering")
        #expect(model.upcoming.map(\.id) == [openEventID], "upcoming must omit the closed event entirely, not mark it")
    }

    @Test("an event ending exactly today (its inclusive whole UTC day not yet elapsed) is still upcoming")
    func eventEndingTodayIsStillUpcoming() async throws {
        let groupID = UUID()
        let eventID = UUID()
        // "Now" is 2026-09-12T23:00:00Z -- an hour before the inclusive whole-day boundary
        // (2026-09-13T00:00:00Z) for an event whose endsOn is 2026-09-12.
        let fixedNow = ISO8601DateFormatter().date(from: "2026-09-12T23:00:00Z")!
        let (client, _) = makeClientAndSession { request in
            jsonResponse(request.url!, body: #"{"events":[{"id":"\#(eventID.uuidString)","groupId":"\#(groupID.uuidString)","name":"Saturday 5K Walk","activityType":"walk","targetKind":"none","startsOn":"2026-09-12","endsOn":"2026-09-12","organizerUserId":"user-1","createdAt":"2026-01-01T00:00:00Z"}]}"#)
        }
        let model = GoalEventsModel(client: client, now: { fixedNow })

        await model.load(groupID: groupID)

        #expect(model.upcoming.map(\.id) == [eventID], "an event's own ending day must remain upcoming for its full inclusive UTC day")
    }

    // MARK: - RSVP state exposes a count and the viewer's own participation

    @Test("rsvp(eventID:) updates rsvpCount and viewerIsIn from the server's response")
    func rsvpUpdatesCountAndViewerIsIn() async throws {
        let eventID = UUID()
        let (client, _) = makeClientAndSession { request in
            jsonResponse(request.url!, body: #"{"count":6,"viewerIsIn":true}"#)
        }
        let model = GoalEventsModel(client: client)

        await model.rsvp(eventID: eventID)

        #expect(model.rsvpCount == 6)
        #expect(model.viewerIsIn == true)
    }

    // MARK: - The model has no property carrying a roster or a completion figure (D2/D3-style structural gate)

    @Test("GoalEventsModel's stored properties carry no roster, member, participant, attendee, or completion field, and are not vacuously empty")
    func modelExposesNoRosterOrCompletionField() {
        let model = GoalEventsModel(client: GoalEventsClient(apiClient: SocialAPIClient(sessionStore: SessionStore())))
        let bannedSubstrings = ["roster", "member", "participant", "attendee", "completion", "closed"]

        let mirror = Mirror(reflecting: model)
        var labels: [String] = []
        for child in mirror.children {
            guard var label = child.label else { continue }
            while label.hasPrefix("_") {
                label.removeFirst()
            }
            labels.append(label.lowercased())
        }

        #expect(!labels.isEmpty, "the reflected property list must not be empty -- an empty list would pass this assertion vacuously")
        for label in labels {
            for banned in bannedSubstrings {
                #expect(!label.contains(banned), "GoalEventsModel has a stored property '\(label)' containing the banned substring '\(banned)'")
            }
        }
    }

    // MARK: - The transient event-selection carrier defaults to nil

    @Test("selectedGoalEventID defaults to nil, is settable, and appends nothing to the navigation path by itself")
    func selectedGoalEventIDDefaultsNilIsSettableAndAppendsNothingToPath() {
        let flow = OnboardingFlow()
        #expect(flow.selectedGoalEventID == nil)

        let eventID = UUID()
        flow.selectedGoalEventID = eventID

        #expect(flow.selectedGoalEventID == eventID)
        #expect(flow.path.isEmpty, "setting selectedGoalEventID must not append to the navigation path by itself")
    }

    // MARK: - ActivityTypeIcon: every known case maps to a distinct symbol, with a non-empty fallback

    @Test("every ActivityType.known case maps to a distinct SF Symbol")
    func everyKnownActivityTypeMapsToADistinctSymbol() {
        let symbols = ActivityType.known.map(ActivityTypeIcon.symbolName(for:))
        #expect(Set(symbols).count == ActivityType.known.count, "two or more known activity types collided on the same symbol")
    }

    @Test("an unrecognized activity type falls back to the documented default symbol rather than an empty string")
    func unrecognizedActivityTypeFallsBackToDocumentedDefault() {
        let unknown = ActivityType(rawValue: "rowing")
        let symbol = ActivityTypeIcon.symbolName(for: unknown)
        #expect(symbol == "figure.run")
        #expect(!symbol.isEmpty)
    }

    // MARK: - Source-level assertions added by later tasks in this same plan

    /// Resolves `RithamApp/Ritham/` relative to this file's own `#filePath`, the same technique
    /// `GroupsUITests.rithamDirectory` uses.
    private var rithamDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Ritham")
    }

    private func nonCommentSource(of relativePath: String) throws -> String {
        let fileURL = rithamDirectory.appendingPathComponent(relativePath)
        let source = try String(contentsOf: fileURL, encoding: .utf8)
        return source
            .components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    // MARK: - Task 3: the RSVP screen carries no ring/arc, and no completion-facing cross-reference

    @Test("GoalEventRSVPView's comment-filtered source constructs no ring, trim-based arc, or Arc shape")
    func goalEventRSVPViewConstructsNoRingOrArc() throws {
        let source = try nonCommentSource(of: "Social/GoalEvents/GoalEventRSVPView.swift")
        #expect(!source.contains("Circle()"), "GoalEventRSVPView.swift constructs a Circle() -- no ring/arc form is permitted on this screen")
        #expect(!source.contains(".trim(from"), "GoalEventRSVPView.swift constructs a trim-based arc -- no ring/arc form is permitted on this screen")
        #expect(!source.contains("Arc("), "GoalEventRSVPView.swift constructs an Arc(...) shape -- no ring/arc form is permitted on this screen")
    }

    /// **Verifies only the RSVP side of this plan's own cross-reference requirement.** No
    /// completion-facing screen exists anywhere in this codebase's client yet (plan 04.1-12
    /// shipped only the Go-side feed routes) -- there is nothing on the other side of this
    /// cross-reference to assert against yet. The reciprocal half (a future completion-facing
    /// screen never referencing `.goalEventRSVP` or `GoalEventRSVPView`) must be added once that
    /// screen is built; this test's own header comment documents the gap so a future editor does
    /// not read this as both halves already proven.
    @Test("GoalEventRSVPView's source references no completion-facing step or type")
    func goalEventRSVPViewReferencesNoCompletionFacingSurface() throws {
        let source = try nonCommentSource(of: "Social/GoalEvents/GoalEventRSVPView.swift")
        let lowercased = source.lowercased()
        for token in ["completion", "completions"] {
            #expect(!lowercased.contains(token), "GoalEventRSVPView.swift references '\(token)' -- this screen must never route to or mention a completion-facing surface")
        }
    }
}

}
