import Foundation
import Testing
@testable import Ritham

// Phase 4.1 Plan 05's shared social networking foundation: `SocialAPIClient`'s bearer-injection
// and error-vocabulary behavior, `SessionStore`'s Keychain round trip, and `AppleSignInRequest`'s
// exact wire shape, exercised with no real network access (Task 1). Task 3 extends this same file
// with a source-level dashboard assertion, in the style `Phase4CoverageTests` already uses.

/// A fresh, file-scoped `URLProtocol` stub -- deliberately NOT `RecommendationsTests.swift`'s
/// `StubURLProtocol`. That type's own header comment documents the exact cross-suite shared-static
/// -state race a third suite touching it would reintroduce (the same `StepRegistry` race class
/// `STATE.md`'s Blockers/Concerns section already documents at length), and two identically named
/// `final class StubURLProtocol` declarations would collide in one module regardless. `.serialized`
/// on the suite below is what keeps this file's own tests from interleaving with each other.
final class SocialStubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    static func reset() {
        requestHandler = nil
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = SocialStubURLProtocol.requestHandler else {
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
    config.protocolClasses = [SocialStubURLProtocol.self]
    return URLSession(configuration: config)
}

// Nested inside `KeychainTouchingSuites` (`KeychainTouchingSuites.swift`, plan 04.1-11 -- Rule 3
// blocking fix): this suite writes to the real, process-shared Keychain via `SessionStore`
// (`init()`'s `SessionStore().clear()` and several tests' own `sessionStore.store(...)`), which
// raced against this suite's own bearer-header assertion during plan 04.1-11's full-target
// verification (`requestCarriesBearerHeaderWhenTokenStored()` failed nondeterministically in the
// full-target run while passing every scoped run). Must be ordered relative to every other
// Keychain-touching suite, not only internally -- see that file's header comment for the full
// mechanism.
extension KeychainTouchingSuites {

@MainActor
@Suite("SocialIdentityTests", .serialized)
struct SocialIdentityTests {

    init() {
        SocialStubURLProtocol.reset()
        SessionStore().clear()
    }

    // MARK: - Data minimization: AppleSignInRequest's exact key set

    @Test("encoding an AppleSignInRequest produces exactly the three keys the Go contract declares")
    func encodingProducesExactlyThreeKeys() throws {
        let request = AppleSignInRequest(identityToken: "raw-jwt", nonce: "digest-hex", displayName: "")
        let data = try JSONEncoder().encode(request)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        let keys = Set(object.map { Array($0.keys) } ?? [])
        #expect(keys.count == 3)
        #expect(keys == ["identityToken", "nonce", "displayName"])
    }

    // MARK: - Bearer injection

    @Test("a request made while a session token is stored carries an Authorization bearer header")
    func requestCarriesBearerHeaderWhenTokenStored() async throws {
        let sessionStore = SessionStore()
        sessionStore.store(token: "abc123", expiresAt: Date().addingTimeInterval(3600), userID: "user-1", displayName: "Alex")
        defer { sessionStore.clear() }

        nonisolated(unsafe) var capturedAuthHeader: String?
        SocialStubURLProtocol.requestHandler = { request in
            capturedAuthHeader = request.value(forHTTPHeaderField: "Authorization")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, "{\"userId\":\"user-1\",\"displayName\":\"Alex\"}".data(using: .utf8)!)
        }
        let client = SocialAPIClient(baseURL: URL(string: "http://127.0.0.1:8080")!, session: makeStubbedSession(), sessionStore: sessionStore)

        let _: MeResponse = try await client.get("v1/identity/me")

        #expect(capturedAuthHeader == "Bearer abc123")
    }

    @Test("a request made with no stored token carries no Authorization header")
    func requestCarriesNoAuthorizationHeaderWithoutToken() async throws {
        let sessionStore = SessionStore()
        sessionStore.clear()

        nonisolated(unsafe) var capturedAuthHeader: String?
        SocialStubURLProtocol.requestHandler = { request in
            capturedAuthHeader = request.value(forHTTPHeaderField: "Authorization")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, "{\"userId\":\"user-1\",\"displayName\":\"Alex\"}".data(using: .utf8)!)
        }
        let client = SocialAPIClient(baseURL: URL(string: "http://127.0.0.1:8080")!, session: makeStubbedSession(), sessionStore: sessionStore)

        let _: MeResponse = try await client.get("v1/identity/me")

        #expect(capturedAuthHeader == nil)
    }

    // MARK: - Error vocabulary (T-04.1-26: a failure must never read as a benign empty result)

    @Test("a 401 response surfaces as the unauthenticated case, not a generic status error")
    func status401SurfacesAsUnauthenticated() async throws {
        let client = makeClient { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        do {
            let _: MeResponse = try await client.get("v1/identity/me")
            Issue.record("expected SocialAPIError.unauthenticated")
        } catch SocialAPIError.unauthenticated {
            // expected
        } catch {
            Issue.record("expected SocialAPIError.unauthenticated, got \(error)")
        }
    }

    @Test("a non-2xx, non-401 status surfaces as the status error carrying the code")
    func nonSuccessStatusSurfacesStatusError() async throws {
        let client = makeClient { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 400, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        do {
            let _: MeResponse = try await client.get("v1/identity/me")
            Issue.record("expected SocialAPIError.httpStatus(400)")
        } catch SocialAPIError.httpStatus(400) {
            // expected
        } catch {
            Issue.record("expected SocialAPIError.httpStatus(400), got \(error)")
        }
    }

    @Test("a transport failure surfaces as the transport error, never an empty successful result")
    func transportFailureSurfacesAsTransportError() async throws {
        let client = makeClient { _ in throw URLError(.cannotConnectToHost) }

        do {
            let _: MeResponse = try await client.get("v1/identity/me")
            Issue.record("expected SocialAPIError.transport")
        } catch SocialAPIError.transport {
            // expected
        } catch {
            Issue.record("expected SocialAPIError.transport, got \(error)")
        }
    }

    @Test("undecodable response bytes surface as the decoding error")
    func undecodableResponseSurfacesAsDecodingError() async throws {
        let client = makeClient { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, "not json".data(using: .utf8)!)
        }

        do {
            let _: MeResponse = try await client.get("v1/identity/me")
            Issue.record("expected SocialAPIError.decoding")
        } catch SocialAPIError.decoding {
            // expected
        } catch {
            Issue.record("expected SocialAPIError.decoding, got \(error)")
        }
    }

    private func makeClient(handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)) -> SocialAPIClient {
        SocialStubURLProtocol.requestHandler = handler
        let sessionStore = SessionStore()
        sessionStore.clear()
        return SocialAPIClient(baseURL: URL(string: "http://127.0.0.1:8080")!, session: makeStubbedSession(), sessionStore: sessionStore)
    }

    // MARK: - SessionStore

    @Test("store then clear leaves isSignedIn false and token nil")
    func storeThenClearLeavesSignedOut() {
        let store = SessionStore()
        store.store(token: "xyz", expiresAt: Date().addingTimeInterval(3600), userID: "user-1", displayName: "Alex")
        #expect(store.isSignedIn)
        #expect(store.token == "xyz")

        store.clear()
        #expect(!store.isSignedIn)
        #expect(store.token == nil)
    }

    @Test("a token written by one SessionStore instance is readable by a freshly constructed one")
    func tokenWrittenByOneInstanceIsReadableByAnother() {
        let first = SessionStore()
        first.store(token: "round-trip-token", expiresAt: Date().addingTimeInterval(3600), userID: "user-1", displayName: "Alex")
        defer { first.clear() }

        let second = SessionStore()
        #expect(second.token == "round-trip-token")
        #expect(second.isSignedIn)
    }

    // MARK: - Task 3: dashboard entry point source assertion (Phase4CoverageTests style)

    /// Resolves `RithamApp/Ritham/` relative to this file's own `#filePath`, the same technique
    /// `Phase4CoverageTests.rithamDirectory` uses.
    private var rithamDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Ritham")
    }

    @Test("HomeHubView's comment-filtered source references the social entry point and still references every Phase 4 required section")
    func homeHubViewReferencesSocialSectionAndPhase4RequiredSections() throws {
        let fileURL = rithamDirectory.appendingPathComponent("Home/HomeHubView.swift")
        let source = try String(contentsOf: fileURL, encoding: .utf8)
        let nonCommentSource = source
            .components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")

        #expect(nonCommentSource.contains("signInWithApple"))
        for requiredSymbol in [
            "MomentumDashboardSection", "exerciseSection", "sleepSection",
            "RecommendationsQuickView", "DietPlanQuickEditView",
        ] {
            #expect(nonCommentSource.contains(requiredSymbol), "HomeHubView.swift no longer references \(requiredSymbol)")
        }
    }
}

}
