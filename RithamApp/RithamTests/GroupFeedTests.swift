import Foundation
import Testing
import RithamCore
@testable import Ritham

// Phase 4.1 Plan 15's feed client, polling model (Task 1), completion card and cheer control
// (Task 2), and the feed/history screens (Task 3). Nested inside `KeychainTouchingSuites`
// (`KeychainTouchingSuites.swift`) because `FeedClient` -> `SocialAPIClient` -> `SessionStore`
// writes to the real, process-shared Keychain -- it must be ordered relative to every other
// Keychain-touching suite, not only internally, matching `CompletionLoggingTests`'s own identical
// precedent from this same phase.
//
// Run this suite with `-only-testing:RithamTests/KeychainTouchingSuites/GroupFeedTests` (the
// nested identifier), never the bare `-only-testing:RithamTests/GroupFeedTests` -- the bare form
// matches zero tests once this suite is nested and exits 0, a silent false pass
// (04.1-07-SUMMARY.md's/`CompletionLoggingTests.swift`'s own documented precedent for this exact
// hazard).

/// A fresh, file-scoped `URLProtocol` stub -- deliberately its own type, matching every other
/// suite's own header comment on the cross-suite shared-static-state race a second suite touching
/// the same stub type would reintroduce.
final class FeedStubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    static func reset() {
        requestHandler = nil
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = FeedStubURLProtocol.requestHandler else {
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
    config.protocolClasses = [FeedStubURLProtocol.self]
    return URLSession(configuration: config)
}

private func jsonResponse(_ url: URL, status: Int = 200, body: String) -> (HTTPURLResponse, Data) {
    let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
    return (response, body.data(using: .utf8)!)
}

private func emptyNoContentResponse(_ url: URL) -> (HTTPURLResponse, Data) {
    let response = HTTPURLResponse(url: url, statusCode: 204, httpVersion: nil, headerFields: nil)!
    return (response, Data())
}

extension KeychainTouchingSuites {

@MainActor
@Suite("GroupFeedTests", .serialized)
struct GroupFeedTests {

    init() {
        FeedStubURLProtocol.reset()
    }

    private func makeClient(handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)) -> FeedClient {
        FeedStubURLProtocol.requestHandler = handler
        let sessionStore = SessionStore()
        sessionStore.store(token: "test-token", expiresAt: Date().addingTimeInterval(3600), userID: "user-1", displayName: "Alex")
        let apiClient = SocialAPIClient(baseURL: URL(string: "http://127.0.0.1:8080")!, session: makeStubbedSession(), sessionStore: sessionStore)
        return FeedClient(apiClient: apiClient)
    }

    private func personJSON(id: String, name: String) -> String {
        #"{"userId":"\#(id)","displayName":"\#(name)"}"#
    }

    private func itemJSON(completionID: String, eventID: String = "e1", eventName: String = "Saturday 5K Walk", activityType: String = "walk", completedAt: String = "2026-09-12T10:00:00Z", ownTimeSeconds: Int? = nil, photoURL: String? = nil, placeName: String? = nil, caption: String? = nil, postedAt: String, niceWork: Bool = false, keepGoing: Bool = false, extraKey: String? = nil) -> String {
        var fields: [String] = [
            "\"completionId\":\"\(completionID)\"",
            "\"actor\":\(personJSON(id: "u-\(completionID)", name: "Person \(completionID)"))",
            "\"eventId\":\"\(eventID)\"",
            "\"eventName\":\"\(eventName)\"",
            "\"activityType\":\"\(activityType)\"",
            "\"completedAt\":\"\(completedAt)\"",
            "\"postedAt\":\"\(postedAt)\"",
            "\"cheers\":{\"niceWorkSentByViewer\":\(niceWork),\"keepGoingSentByViewer\":\(keepGoing)}"
        ]
        if let ownTimeSeconds { fields.append("\"ownTimeSeconds\":\(ownTimeSeconds)") }
        if let photoURL { fields.append("\"photoUrl\":\"\(photoURL)\"") }
        if let placeName { fields.append("\"placeName\":\"\(placeName)\"") }
        if let caption { fields.append("\"caption\":\"\(caption)\"") }
        if let extraKey { fields.append("\"\(extraKey)\":123") }
        return "{" + fields.joined(separator: ",") + "}"
    }

    private func pageJSON(items: [String], nextCursor: String? = nil, extraKey: String? = nil) -> String {
        var fields = ["\"items\":[\(items.joined(separator: ","))]"]
        if let nextCursor { fields.append("\"nextCursor\":\"\(nextCursor)\"") }
        if let extraKey { fields.append("\"\(extraKey)\":123") }
        return "{" + fields.joined(separator: ",") + "}"
    }

    // MARK: - Task 1: strict decoding rejects an unrecognized key

    @Test("FeedItem decoding throws when the JSON carries a key this type does not declare")
    func feedItemDecodingRejectsUnknownKey() throws {
        let json = itemJSON(completionID: "c1", postedAt: "2026-09-12T10:00:01Z", extraKey: "completionCount")
        #expect(throws: (any Error).self) {
            _ = try JSONDecoder().decode(FeedItem.self, from: json.data(using: .utf8)!)
        }
    }

    @Test("FeedPage decoding throws when the JSON carries a key this type does not declare")
    func feedPageDecodingRejectsUnknownKey() throws {
        let json = pageJSON(items: [], extraKey: "totalCount")
        #expect(throws: (any Error).self) {
            _ = try JSONDecoder().decode(FeedPage.self, from: json.data(using: .utf8)!)
        }
    }

    @Test("FeedItem decodes successfully when every key is one this type declares")
    func feedItemDecodesKnownKeysSuccessfully() throws {
        let json = itemJSON(completionID: "c1", postedAt: "2026-09-12T10:00:01Z")
        let item = try JSONDecoder().decode(FeedItem.self, from: json.data(using: .utf8)!)
        #expect(item.completionID == "c1")
    }

    // MARK: - Task 1: FeedItem's exact stored-property set -- no total, position, fraction, or cheer count

    @Test("FeedItem's stored properties carry no total, position, fraction, or count field, and are not vacuously empty")
    func feedItemHasNoAggregateOrRankingField() {
        let item = FeedItem(completionID: "c1", actor: FeedPerson(userID: "u1", displayName: "A"), eventID: "e1", eventName: "Event", activityType: "walk", completedAt: "2026-09-12T10:00:00Z", postedAt: "2026-09-12T10:00:01Z")
        let mirror = Mirror(reflecting: item)
        var labels: [String] = []
        for child in mirror.children {
            guard var label = child.label else { continue }
            while label.hasPrefix("_") { label.removeFirst() }
            labels.append(label.lowercased())
        }
        #expect(!labels.isEmpty, "the reflected property list must not be empty -- an empty list would pass this assertion vacuously")
        let bannedSubstrings = ["total", "position", "fraction", "count", "rank", "denominator", "percent"]
        for label in labels {
            for banned in bannedSubstrings {
                #expect(!label.contains(banned), "FeedItem has a stored property '\(label)' containing the banned substring '\(banned)'")
            }
        }
    }

    // MARK: - Task 1: the model never sorts, reverses, or re-keys -- rendered order equals received order

    @Test("loadFirstPage() assigns items in exactly the order the server returned them, for a deliberately unordered page")
    func loadFirstPageAssignsReceivedOrderVerbatim() async throws {
        // Deliberately not in id order, time order, or any other derivable order.
        let items = [
            itemJSON(completionID: "c-3", postedAt: "2026-09-12T10:00:03Z"),
            itemJSON(completionID: "c-1", postedAt: "2026-09-12T10:00:01Z"),
            itemJSON(completionID: "c-2", postedAt: "2026-09-12T10:00:02Z")
        ]
        let client = makeClient { request in
            jsonResponse(request.url!, body: self.pageJSON(items: items))
        }
        let model = GroupFeedModel(source: .group(UUID()), client: client)

        await model.loadFirstPage()

        #expect(model.items.map(\.completionID) == ["c-3", "c-1", "c-2"], "the model must never re-sort a received page")
    }

    @Test("loadNextPage() appends the next page after the existing items, in the order received")
    func loadNextPageAppendsReceivedOrderVerbatim() async throws {
        nonisolated(unsafe) var call = 0
        let client = makeClient { request in
            call += 1
            if call == 1 {
                return jsonResponse(request.url!, body: self.pageJSON(items: [self.itemJSON(completionID: "c-1", postedAt: "2026-09-12T10:00:01Z")], nextCursor: "cursor-1"))
            }
            return jsonResponse(request.url!, body: self.pageJSON(items: [
                self.itemJSON(completionID: "c-3", postedAt: "2026-09-12T09:00:03Z"),
                self.itemJSON(completionID: "c-2", postedAt: "2026-09-12T09:00:02Z")
            ]))
        }
        let model = GroupFeedModel(source: .group(UUID()), client: client)

        await model.loadFirstPage()
        await model.loadNextPage()

        #expect(model.items.map(\.completionID) == ["c-1", "c-3", "c-2"], "loadNextPage must append, never sort/reverse/re-key")
        #expect(model.nextCursor == nil, "a page whose response carries no nextCursor must exhaust pagination")
    }

    // MARK: - Task 1: refresh() replaces the first page and resets the cursor

    @Test("refresh() replaces items and cursor wholesale, never merges with what loadNextPage() had appended")
    func refreshReplacesFirstPageAndResetsCursor() async throws {
        nonisolated(unsafe) var call = 0
        let client = makeClient { request in
            call += 1
            switch call {
            case 1:
                return jsonResponse(request.url!, body: self.pageJSON(items: [self.itemJSON(completionID: "c-1", postedAt: "2026-09-12T10:00:01Z")], nextCursor: "cursor-1"))
            case 2:
                return jsonResponse(request.url!, body: self.pageJSON(items: [self.itemJSON(completionID: "c-2", postedAt: "2026-09-12T09:00:02Z")]))
            default:
                return jsonResponse(request.url!, body: self.pageJSON(items: [self.itemJSON(completionID: "c-9", postedAt: "2026-09-12T11:00:00Z")], nextCursor: "cursor-9"))
            }
        }
        let model = GroupFeedModel(source: .group(UUID()), client: client)

        await model.loadFirstPage()
        await model.loadNextPage()
        #expect(model.items.map(\.completionID) == ["c-1", "c-2"])

        await model.refresh()

        #expect(model.items.map(\.completionID) == ["c-9"], "refresh() must replace the first page wholesale, not merge with prior pages")
        #expect(model.nextCursor == "cursor-9", "refresh() must reset the cursor to whatever the fresh first page returned")
    }

    // MARK: - Task 1: a transport failure never blanks a feed a person was reading

    @Test("a failed refresh leaves previously-loaded items unchanged and moves state to failed")
    func failedRefreshLeavesItemsUnchangedAndStateFailed() async throws {
        nonisolated(unsafe) var call = 0
        let client = makeClient { request in
            call += 1
            if call == 1 {
                return jsonResponse(request.url!, body: self.pageJSON(items: [self.itemJSON(completionID: "c-1", postedAt: "2026-09-12T10:00:01Z")]))
            }
            throw URLError(.cannotConnectToHost)
        }
        let model = GroupFeedModel(source: .group(UUID()), client: client)

        await model.loadFirstPage()
        #expect(model.state == .loaded)

        await model.refresh()

        #expect(model.state == .failed(.transport))
        #expect(model.items.map(\.completionID) == ["c-1"], "a failed refresh must never clear items a person was already reading")
    }

    @Test("a first load that fails renders as .failed, never as an empty successful load")
    func firstLoadFailureIsDistinctFromAnEmptySuccessfulLoad() async throws {
        let client = makeClient { _ in throw URLError(.cannotConnectToHost) }
        let model = GroupFeedModel(source: .group(UUID()), client: client)

        await model.loadFirstPage()

        #expect(model.state == .failed(.transport))
        #expect(model.items.isEmpty, "no items were ever loaded, but the distinguishing signal is state, not emptiness")
    }

    @Test("a first load that succeeds with zero items renders as .loaded and empty, distinct from a failure")
    func firstLoadEmptySuccessIsDistinctFromFailure() async throws {
        let client = makeClient { request in
            jsonResponse(request.url!, body: self.pageJSON(items: []))
        }
        let model = GroupFeedModel(source: .group(UUID()), client: client)

        await model.loadFirstPage()

        #expect(model.state == .loaded)
        #expect(model.items.isEmpty)
    }

    // MARK: - Task 1: renderDecision never discards cards on screen for a failure (advisor review)

    @Test("renderDecision keeps rendering cards, with a failure banner alongside them, when a refresh fails after a successful load")
    func renderDecisionKeepsCardsAlongsideAFailureBanner() async throws {
        nonisolated(unsafe) var call = 0
        let client = makeClient { request in
            call += 1
            if call == 1 {
                return jsonResponse(request.url!, body: self.pageJSON(items: [self.itemJSON(completionID: "c-1", postedAt: "2026-09-12T10:00:01Z")]))
            }
            throw URLError(.cannotConnectToHost)
        }
        let model = GroupFeedModel(source: .group(UUID()), client: client)

        await model.loadFirstPage()
        #expect(model.renderDecision == .cards)

        await model.refresh()

        #expect(model.state == .failed(.transport))
        #expect(!model.items.isEmpty, "the refresh failure must not have cleared items")
        #expect(model.renderDecision == .cardsWithFailureBanner, "a naive state-only branch would render the bare failure text here and discard the cards -- this is exactly what a poll-timer failure or a failed cheer tap must never do")
    }

    @Test("RenderDecision.decide covers every (state, hasItems) combination this model can reach")
    func renderDecisionCoversEveryStateCombination() {
        #expect(GroupFeedModel.RenderDecision.decide(state: .idle, hasItems: false) == .nothing)
        #expect(GroupFeedModel.RenderDecision.decide(state: .loading, hasItems: false) == .nothing)
        #expect(GroupFeedModel.RenderDecision.decide(state: .idle, hasItems: true) == .cards)
        #expect(GroupFeedModel.RenderDecision.decide(state: .loading, hasItems: true) == .cards)
        #expect(GroupFeedModel.RenderDecision.decide(state: .loaded, hasItems: true) == .cards)
        #expect(GroupFeedModel.RenderDecision.decide(state: .loaded, hasItems: false) == .emptyMessage)
        #expect(GroupFeedModel.RenderDecision.decide(state: .failed(.transport), hasItems: true) == .cardsWithFailureBanner)
        #expect(GroupFeedModel.RenderDecision.decide(state: .failed(.transport), hasItems: false) == .failureMessage)
    }

    // MARK: - Task 1: loadNextPage() guards against a duplicate concurrent call

    @Test("two concurrent loadNextPage() calls with the same cursor append the page only once")
    func concurrentLoadNextPageCallsAppendOnlyOnce() async throws {
        nonisolated(unsafe) var nextPageCallCount = 0
        let client = makeClient { request in
            if request.url?.query?.contains("cursor=") == true {
                nextPageCallCount += 1
                return jsonResponse(request.url!, body: self.pageJSON(items: [self.itemJSON(completionID: "c-2", postedAt: "2026-09-12T09:00:02Z")]))
            }
            return jsonResponse(request.url!, body: self.pageJSON(items: [self.itemJSON(completionID: "c-1", postedAt: "2026-09-12T10:00:01Z")], nextCursor: "cursor-1"))
        }
        let model = GroupFeedModel(source: .group(UUID()), client: client)
        await model.loadFirstPage()

        // isLoadingNextPage's guard is checked synchronously (before any `await`) inside
        // loadNextPage() itself, so correctness here does not depend on network timing -- whichever
        // of these two child tasks the MainActor executor runs first completes that synchronous
        // guard-and-flag-set atomically before the other gets a turn, so the second call always
        // observes the flag already set and returns as a no-op, regardless of scheduling order.
        async let first = model.loadNextPage()
        async let second = model.loadNextPage()
        _ = await (first, second)

        #expect(nextPageCallCount == 1, "a concurrent second call must be a no-op while the first is still in flight")
        #expect(model.items.map(\.completionID) == ["c-1", "c-2"], "the next page must appear exactly once, not duplicated")
    }

    // MARK: - Task 2: completedAt/postedAt parsing tolerates a fractional-seconds timestamp

    @Test("CompletionCard.parseTimestamp accepts both a whole-second and a fractional-seconds RFC3339 timestamp")
    func parseTimestampAcceptsBothTimestampShapes() {
        #expect(CompletionCard.parseTimestamp("2026-09-12T10:00:00Z") != nil, "a whole-second timestamp (this file's own fixtures) must still parse")
        #expect(CompletionCard.parseTimestamp("2026-09-12T10:00:00.123456Z") != nil, "a real Postgres timestamptz round-tripped through Go's RFC3339Nano marshaling commonly carries fractional seconds -- a bare ISO8601DateFormatter alone rejects this shape and would silently render no date at all")
    }

    // MARK: - Task 1: toggling a cheer updates only that item's own flag

    @Test("toggleCheer updates only the target item's own cheer flag, and no other item, and no other flag on that item")
    func toggleCheerUpdatesOnlyTargetItemsOwnFlag() async throws {
        let client = makeClient { request in
            if request.httpMethod == "GET" {
                return jsonResponse(request.url!, body: self.pageJSON(items: [
                    self.itemJSON(completionID: "c-1", postedAt: "2026-09-12T10:00:01Z", niceWork: false, keepGoing: false),
                    self.itemJSON(completionID: "c-2", postedAt: "2026-09-12T10:00:02Z", niceWork: false, keepGoing: false)
                ]))
            }
            return emptyNoContentResponse(request.url!)
        }
        let model = GroupFeedModel(source: .group(UUID()), client: client)
        await model.loadFirstPage()
        let target = model.items[0]

        await model.toggleCheer(.niceWork, for: target, on: true)

        #expect(model.items[0].cheers.niceWorkSentByViewer == true)
        #expect(model.items[0].cheers.keepGoingSentByViewer == false, "the same item's other cheer flag must be untouched")
        #expect(model.items[1].cheers.niceWorkSentByViewer == false, "a different item's flag must be untouched")
        #expect(model.items[1].cheers.keepGoingSentByViewer == false)
    }

    @Test("a failed cheer toggle leaves every item's flags unchanged and moves state to failed")
    func failedCheerToggleLeavesFlagsUnchanged() async throws {
        let client = makeClient { request in
            if request.httpMethod == "GET" {
                return jsonResponse(request.url!, body: self.pageJSON(items: [self.itemJSON(completionID: "c-1", postedAt: "2026-09-12T10:00:01Z")]))
            }
            throw URLError(.cannotConnectToHost)
        }
        let model = GroupFeedModel(source: .group(UUID()), client: client)
        await model.loadFirstPage()
        let target = model.items[0]

        await model.toggleCheer(.niceWork, for: target, on: true)

        #expect(model.items[0].cheers.niceWorkSentByViewer == false, "a failed cheer send must never render as sent")
        #expect(model.state == .failed(.transport))
    }

    // MARK: - Task 1: polling shares the load path and stops cleanly

    @Test("startPolling() repeatedly calls the same load path, and stopPolling() halts further calls")
    func pollingCallsLoadPathRepeatedlyAndStopsCleanly() async throws {
        nonisolated(unsafe) var callCount = 0
        let client = makeClient { request in
            callCount += 1
            return jsonResponse(request.url!, body: self.pageJSON(items: []))
        }
        let model = GroupFeedModel(source: .group(UUID()), client: client, pollInterval: 0.05)

        model.startPolling()
        try await Task.sleep(for: .seconds(0.3))
        model.stopPolling()
        // `stopPolling()` cancels the loop's own sleep, but cannot abort a `loadFirstPage()` call
        // already in flight at the moment it's called (the loop checks cancellation only between
        // iterations) -- a short grace period here lets any such in-flight call land before this
        // test snapshots "the count once stopped," so the snapshot itself is never racing that
        // call's completion.
        try await Task.sleep(for: .seconds(0.1))

        let countAtStop = callCount
        #expect(countAtStop >= 2, "polling must have fired more than once over six intervals' worth of waiting")

        try await Task.sleep(for: .seconds(0.2))
        #expect(callCount == countAtStop, "no further load should fire once stopPolling() has been called")
    }

    @Test("calling startPolling() twice replaces the previous loop rather than running two concurrently")
    func startPollingTwiceReplacesPreviousLoop() async throws {
        nonisolated(unsafe) var callCount = 0
        let client = makeClient { request in
            callCount += 1
            return jsonResponse(request.url!, body: self.pageJSON(items: []))
        }
        let model = GroupFeedModel(source: .group(UUID()), client: client, pollInterval: 0.05)

        model.startPolling()
        try await Task.sleep(for: .seconds(0.12))
        model.startPolling()
        try await Task.sleep(for: .seconds(0.12))
        model.stopPolling()

        // Loose bound: proves polling didn't silently double its own cadence by leaving the first
        // loop running alongside a second -- an exact count would flake on a loaded machine.
        #expect(callCount <= 8, "calling startPolling() again must replace, not add to, the running poll loop")
    }

    // MARK: - Task 1: eventFeed decode path (full route coverage, no UI caller in this plan)

    @Test("FeedClient.eventFeed decodes a page identically to groupFeed")
    func eventFeedDecodesSuccessfully() async throws {
        let client = makeClient { request in
            #expect(request.url?.path.contains("/v1/events/") == true)
            return jsonResponse(request.url!, body: self.pageJSON(items: [self.itemJSON(completionID: "c-1", postedAt: "2026-09-12T10:00:01Z")]))
        }
        let page = try await client.eventFeed(eventID: "event-1")
        #expect(page.items.map(\.completionID) == ["c-1"])
    }

    // MARK: - Task 1: cursor/limit reach the server as a real URL query string

    @Test("groupFeed(cursor:) sends cursor as a real URL query parameter, not literal text in the path")
    func groupFeedSendsCursorAsRealQueryParameter() async throws {
        let client = makeClient { request in
            #expect(request.url?.query == "cursor=abc123")
            #expect(request.url?.path == "/v1/groups/group-1/feed")
            return jsonResponse(request.url!, body: self.pageJSON(items: []))
        }
        _ = try await client.groupFeed(groupID: "group-1", cursor: "abc123")
    }

    @Test("groupFeed() with no cursor or limit sends no query string at all")
    func groupFeedWithNoParamsSendsNoQueryString() async throws {
        let client = makeClient { request in
            #expect(request.url?.query == nil)
            return jsonResponse(request.url!, body: self.pageJSON(items: []))
        }
        _ = try await client.groupFeed(groupID: "group-1")
    }

    // MARK: - Task 1: no sort/reverse call exists in the model's own source

    @Test("GroupFeedModel.swift contains no .sorted or .reversed call")
    func modelFileContainsNoSortOrReverseCall() throws {
        let fileURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Ritham/Social/Feed/GroupFeedModel.swift")
        let source = try String(contentsOf: fileURL, encoding: .utf8)
        #expect(!source.contains(".sorted"))
        #expect(!source.contains(".reversed"))
    }

    // MARK: - Task 2: the completion card and cheer control -- structural source assertions

    private func rithamDirectory() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Ritham")
    }

    private func nonCommentSource(of relativePath: String) throws -> String {
        let fileURL = rithamDirectory().appendingPathComponent(relativePath)
        let source = try String(contentsOf: fileURL, encoding: .utf8)
        return source
            .components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    @Test("CompletionCard's comment-filtered source has no ordinal, medal, or accent-color reference")
    func completionCardHasNoOrdinalMedalOrAccentColor() throws {
        let source = try nonCommentSource(of: "Social/Feed/CompletionCard.swift")
        for banned in ["medal", "rosette", "number.circle", "1st", "crown", "trophy"] {
            #expect(!source.lowercased().contains(banned), "CompletionCard.swift references the banned ranking token '\(banned)'")
        }
        #expect(!source.contains("RithamColor.hot"), "CompletionCard.swift must never reference the reserved accent color")
        #expect(!source.contains("RithamColor.volt"), "CompletionCard.swift must never reference the reserved ornament color")
    }

    @Test("CompletionCard's source calls the catalog's card sentence at least twice -- both with-time and without-time overloads")
    func completionCardCallsBothSentenceOverloads() throws {
        let source = try nonCommentSource(of: "Social/Feed/CompletionCard.swift")
        let count = source.components(separatedBy: "SocialCopy.Feed.card").count - 1
        #expect(count >= 2)
    }

    @Test("CompletionCard.swift never types the caption field or footnote role")
    func completionCardNeverTypesCaptionOrFootnote() throws {
        let source = try nonCommentSource(of: "Social/Feed/CompletionCard.swift")
        #expect(!source.contains(".caption"))
        #expect(!source.contains(".footnote"))
    }

    @Test("CheerReactionRow's source never references the reserved accent color and carries no count")
    func cheerReactionRowHasNoAccentColorOrCount() throws {
        let source = try nonCommentSource(of: "Social/Feed/CheerReactionRow.swift")
        #expect(!source.contains("RithamColor.hot"))
        let lowercased = source.lowercased()
        for banned in ["count", "mostcheered", "most-cheered"] {
            #expect(!lowercased.contains(banned), "CheerReactionRow.swift references the banned token '\(banned)'")
        }
    }

    // MARK: - Task 3: the feed and history screens carry no sort control, ordinal, ring, or count

    @Test("GroupFeedView and GroupHistoryView contain no Picker or segmented control")
    func feedAndHistoryViewsContainNoPickerOrSegmentedControl() throws {
        for path in ["Social/Feed/GroupFeedView.swift", "Social/Feed/GroupHistoryView.swift"] {
            let source = try nonCommentSource(of: path)
            #expect(!source.contains("Picker("), "\(path) contains a Picker(")
            #expect(!source.lowercased().contains("segmented"), "\(path) references a segmented control")
        }
    }

    @Test("GroupFeedView and GroupHistoryView reference no RSVP step, and no collection-count expression")
    func feedAndHistoryViewsReferenceNoRSVPOrCount() throws {
        for path in ["Social/Feed/GroupFeedView.swift", "Social/Feed/GroupHistoryView.swift"] {
            let source = try nonCommentSource(of: path)
            #expect(!source.contains("goalEventRSVP"), "\(path) references .goalEventRSVP")
            #expect(!source.contains("items.count"), "\(path) references items.count")
            #expect(!source.contains(".count)"), "\(path) contains a .count) expression")
        }
    }

    @Test("GroupFeedView and GroupHistoryView construct no ring, trim-based arc, or Arc shape")
    func feedAndHistoryViewsConstructNoRingOrArc() throws {
        for path in ["Social/Feed/GroupFeedView.swift", "Social/Feed/GroupHistoryView.swift"] {
            let source = try nonCommentSource(of: path)
            #expect(!source.contains("Circle()"), "\(path) constructs a Circle()")
            #expect(!source.contains(".trim(from"), "\(path) constructs a trim-based arc")
            #expect(!source.contains("Arc("), "\(path) constructs an Arc(...) shape")
        }
    }
}

}
