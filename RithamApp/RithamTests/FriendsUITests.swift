import Foundation
import Testing
@testable import Ritham

// Phase 4.1 Plan 09's friend-circle surface. Task 1 covers FriendsClient's exact wire contract
// and FriendsModel/ContactMatchDigest's behaviors, with no real network access, against a
// file-scoped stubbed `URLProtocol` (plan 04.1-05's SocialIdentityTests pattern). Tasks 2/3
// extend this same file with source-level structural assertions in the style
// `Phase4CoverageTests` already uses.

/// A fresh, file-scoped `URLProtocol` stub -- deliberately NOT `SocialIdentityTests`'s
/// `SocialStubURLProtocol` or `RecommendationsTests`'s `StubURLProtocol`. Both of those files'
/// own header comments document the cross-suite shared-static-state race a third suite touching
/// the same stub type would reintroduce. `.serialized` on the suite below is what keeps this
/// file's own tests from interleaving with each other.
final class FriendsStubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    static func reset() {
        requestHandler = nil
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = FriendsStubURLProtocol.requestHandler else {
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
    config.protocolClasses = [FriendsStubURLProtocol.self]
    return URLSession(configuration: config)
}

private func jsonResponse(_ url: URL, status: Int = 200, body: String) -> (HTTPURLResponse, Data) {
    let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
    return (response, body.data(using: .utf8)!)
}

@MainActor
@Suite("FriendsUITests", .serialized)
struct FriendsUITests {

    init() {
        FriendsStubURLProtocol.reset()
        SessionStore().clear()
    }

    private func makeClient(handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)) -> FriendsClient {
        FriendsStubURLProtocol.requestHandler = handler
        let sessionStore = SessionStore()
        sessionStore.store(token: "test-token", expiresAt: Date().addingTimeInterval(3600), userID: "user-1", displayName: "Alex")
        let apiClient = SocialAPIClient(baseURL: URL(string: "http://127.0.0.1:8080")!, session: makeStubbedSession(), sessionStore: sessionStore)
        return FriendsClient(apiClient: apiClient)
    }

    // MARK: - Wire contract: exact key sets (D2's own acceptance criterion)

    @Test("SendFriendRequestRequest encodes exactly the two keys the Go contract declares")
    func sendFriendRequestRequestEncodesExactKeys() throws {
        let request = SendFriendRequestRequest(toUserId: "user-2", connectionPath: "direct_share")
        let keys = try encodedKeys(request)
        #expect(keys == ["toUserId", "connectionPath"])
    }

    @Test("RedeemInviteRequest encodes exactly the one key the Go contract declares")
    func redeemInviteRequestEncodesExactKeys() throws {
        let request = RedeemInviteRequest(token: "abc")
        let keys = try encodedKeys(request)
        #expect(keys == ["token"])
    }

    @Test("SetContactMatchOptInRequest encodes exactly the two keys the Go contract declares")
    func setContactMatchOptInRequestEncodesExactKeys() throws {
        let request = SetContactMatchOptInRequest(optedIn: true, identifierDigests: [Data([1, 2, 3])])
        let keys = try encodedKeys(request)
        #expect(keys == ["optedIn", "identifierDigests"])
    }

    @Test("MatchContactsRequest encodes exactly the one key the Go contract declares")
    func matchContactsRequestEncodesExactKeys() throws {
        let request = MatchContactsRequest(candidateDigests: [Data([4, 5, 6])])
        let keys = try encodedKeys(request)
        #expect(keys == ["candidateDigests"])
    }

    /// No request struct in `FriendsClient.swift` declares a field naming the acting user --
    /// every one of the four encoded key sets above is checked against a banned-name list that
    /// would catch an accidental "who is making this call" field, the same class of mistake
    /// `friends_handler.go`'s own header comment (T-04.1-35) forbids server-side.
    @Test("no request struct's key set names the acting user")
    func noRequestStructNamesTheActingUser() throws {
        let bannedNames: Set<String> = ["userId", "actorId", "callerId", "requesterId", "senderId", "fromUserId"]
        let allKeySets = [
            try encodedKeys(SendFriendRequestRequest(toUserId: "u", connectionPath: "direct_share")),
            try encodedKeys(RedeemInviteRequest(token: "t")),
            try encodedKeys(SetContactMatchOptInRequest(optedIn: true, identifierDigests: [])),
            try encodedKeys(MatchContactsRequest(candidateDigests: [])),
        ]
        for keys in allKeySets {
            #expect(bannedNames.isDisjoint(with: keys), "a request struct's key set \(keys) names the acting user")
        }
    }

    private func encodedKeys<Body: Encodable>(_ body: Body) throws -> Set<String> {
        let data = try JSONEncoder().encode(body)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return Set(object.map { Array($0.keys) } ?? [])
    }

    // MARK: - Transport/auth failure never reads as an empty result (T-04.1-54)

    @Test("a transport failure during load leaves the friends array unchanged and the state failed")
    func aTransportFailureDuringLoadLeavesFriendsArrayUnchangedAndStateFailed() async throws {
        FriendsStubURLProtocol.requestHandler = { _ in throw URLError(.cannotConnectToHost) }
        let sessionStore = SessionStore()
        sessionStore.store(token: "test-token", expiresAt: Date().addingTimeInterval(3600), userID: "user-1", displayName: "Alex")
        let apiClient = SocialAPIClient(baseURL: URL(string: "http://127.0.0.1:8080")!, session: makeStubbedSession(), sessionStore: sessionStore)
        let model = FriendsModel(client: FriendsClient(apiClient: apiClient))

        await model.load()

        #expect(model.friends.isEmpty)
        #expect(model.state == .failed(.transport))
    }

    @Test("a 401 during load moves the model to the unauthenticated failed state, not a generic error")
    func aFourOhOneDuringLoadMovesStateToFailedUnauthenticated() async throws {
        FriendsStubURLProtocol.requestHandler = { request in
            (HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!, Data())
        }
        let sessionStore = SessionStore()
        sessionStore.store(token: "test-token", expiresAt: Date().addingTimeInterval(3600), userID: "user-1", displayName: "Alex")
        let apiClient = SocialAPIClient(baseURL: URL(string: "http://127.0.0.1:8080")!, session: makeStubbedSession(), sessionStore: sessionStore)
        let model = FriendsModel(client: FriendsClient(apiClient: apiClient))

        await model.load()

        #expect(model.friends.isEmpty)
        #expect(model.state == .failed(.unauthenticated))
    }

    // MARK: - Accepting a request (D1's own acceptance criterion)

    @Test("accepting a request removes it from incoming and adds the person to friends after the reload")
    func acceptingARequestRemovesItFromIncomingAndAddsToFriendsAfterReload() async throws {
        let baseURL = URL(string: "http://127.0.0.1:8080")!
        // Separate per-endpoint counters -- `load()` fires GET /v1/friends and GET
        // /v1/friends/requests concurrently via `async let`, so a single shared counter
        // incremented by only one of the two branches races: whichever request happens to run
        // first on a given round reads a counter the other branch hasn't touched yet.
        nonisolated(unsafe) var friendsCallCount = 0
        nonisolated(unsafe) var requestsCallCount = 0
        FriendsStubURLProtocol.requestHandler = { request in
            let path = request.url!.path
            if path.hasSuffix("/accept") {
                return jsonResponse(request.url!, body: #"{"friendUserId":"user-2","establishedAt":"2026-01-01T00:00:00Z"}"#)
            }
            if path == "/v1/friends" {
                friendsCallCount += 1
                if friendsCallCount == 1 {
                    return jsonResponse(request.url!, body: #"{"friends":[]}"#)
                }
                return jsonResponse(request.url!, body: #"{"friends":[{"userId":"user-2","displayName":"Priya","establishedAt":"2026-01-01T00:00:00Z"}]}"#)
            }
            if path == "/v1/friends/requests" {
                requestsCallCount += 1
                if requestsCallCount == 1 {
                    return jsonResponse(request.url!, body: #"{"requests":[{"id":"req-1","fromUserId":"user-2","toUserId":"user-1","state":"pending","connectionPath":"direct_share","createdAt":"2026-01-01T00:00:00Z"}]}"#)
                }
                return jsonResponse(request.url!, body: #"{"requests":[]}"#)
            }
            Issue.record("unexpected request to \(path)")
            return jsonResponse(request.url!, status: 500, body: "{}")
        }
        let sessionStore = SessionStore()
        sessionStore.store(token: "test-token", expiresAt: Date().addingTimeInterval(3600), userID: "user-1", displayName: "Alex")
        let apiClient = SocialAPIClient(baseURL: baseURL, session: makeStubbedSession(), sessionStore: sessionStore)
        let model = FriendsModel(client: FriendsClient(apiClient: apiClient))

        await model.load()
        #expect(model.incoming.count == 1)
        #expect(model.friends.isEmpty)

        let request = try #require(model.incoming.first)
        await model.accept(request)

        #expect(model.incoming.isEmpty)
        #expect(model.friends.map(\.id) == ["user-2"])
    }

    // MARK: - Contact digesting (T-04.1-51's on-device half)

    @Test("contact digesting produces a stable digest for the same normalized input")
    func contactDigestingProducesStableDigestForSameNormalizedInput() {
        let first = ContactMatchDigest.digests(for: ["friend@example.com"], salt: "test-salt")
        let second = ContactMatchDigest.digests(for: ["friend@example.com"], salt: "test-salt")
        #expect(first == second)
        #expect(!first[0].isEmpty)
    }

    @Test("contact digesting produces different digests for different inputs")
    func contactDigestingProducesDifferentDigestsForDifferentInputs() {
        let digests = ContactMatchDigest.digests(for: ["a@example.com", "b@example.com"], salt: "test-salt")
        #expect(digests[0] != digests[1])
    }

    @Test("contact digesting normalizes capitalization and surrounding whitespace before hashing")
    func contactDigestingNormalizesBeforeHashing() {
        let digests = ContactMatchDigest.digests(
            for: ["Friend@Example.com", "  friend@example.com  "],
            salt: "test-salt"
        )
        #expect(digests[0] == digests[1])
    }

    // MARK: - Contact-match opt-in off submits no digests (Task 1's own behavior list)

    @Test("turning the contact-match opt-in off submits no digests, even when some were passed in")
    func turningContactMatchOptInOffSubmitsNoDigests() async throws {
        nonisolated(unsafe) var capturedDigestCount: Int?
        FriendsStubURLProtocol.requestHandler = { request in
            if request.url!.path == "/v1/friends/contact-match" {
                let bodyData = request.httpBodyOrStream()
                let object = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
                capturedDigestCount = (object?["identifierDigests"] as? [Any])?.count
            }
            return (HTTPURLResponse(url: request.url!, statusCode: 204, httpVersion: nil, headerFields: nil)!, Data())
        }
        let sessionStore = SessionStore()
        sessionStore.store(token: "test-token", expiresAt: Date().addingTimeInterval(3600), userID: "user-1", displayName: "Alex")
        let apiClient = SocialAPIClient(baseURL: URL(string: "http://127.0.0.1:8080")!, session: makeStubbedSession(), sessionStore: sessionStore)
        let model = FriendsModel(client: FriendsClient(apiClient: apiClient))

        await model.setContactMatchOptIn(false, digests: [Data([1, 2, 3]), Data([4, 5, 6])])

        #expect(capturedDigestCount == 0)
    }
}

private extension URLRequest {
    /// `URLSession` converts a small JSON `httpBody` into an `httpBodyStream` before handing the
    /// request to a custom `URLProtocol` -- `httpBody` itself reads `nil` inside
    /// `startLoading()`, a well-known gotcha this helper works around by draining the stream
    /// when present, falling back to `httpBody` for any caller that never sees this conversion.
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
