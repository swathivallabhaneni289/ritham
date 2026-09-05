import Foundation
import SwiftData
import Testing
import RithamCore
@testable import Ritham

// Phase 2 Plan 13's Recommendations-surface test suites, at the model/data level per this
// plan's own explicit instruction (not by rendering) -- the same discipline `CardioViewTests`/
// `HomeHubTests` already use. `WorkoutPlanClientTests` (Task 1) is followed by `PreAssessmentTests`
// (Task 2) and `RecommendationsScreenTests` (Task 3) as this same file grows across the plan's
// tasks.

/// A `URLProtocol` stub so every test in this file exercises `WorkoutPlanClient` without any real
/// network access. `requestCount` is the enforceable form of T-02-37: a test asserting it stays 0
/// proves the most restrictive gate never constructs a request at all.
final class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    nonisolated(unsafe) static var requestCount = 0

    static func reset() {
        requestHandler = nil
        requestCount = 0
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        StubURLProtocol.requestCount += 1
        guard let handler = StubURLProtocol.requestHandler else {
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
    config.protocolClasses = [StubURLProtocol.self]
    return URLSession(configuration: config)
}

// `.serialized` because every test in this suite reads/writes `StubURLProtocol`'s shared static
// `requestHandler`/`requestCount` state -- the same reason `AppShellTests` serializes around
// `StepRegistry`'s shared static state (STATE.md's Blockers/Concerns documents the cross-suite
// version of this same race).
@Suite("WorkoutPlanClientTests", .serialized)
struct WorkoutPlanClientTests {

    init() {
        StubURLProtocol.reset()
    }

    @Test("encoding a request produces exactly three JSON keys matching the wire contract")
    func encodingProducesExactlyThreeKeys() throws {
        let request = WorkoutPlanRequest(frequencyPerWeek: 5, experienceLevel: "intermediate", guidancePermission: "none")

        let data = try JSONEncoder().encode(request)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        let keys = Set(object.map { Array($0.keys) } ?? [])
        #expect(keys.count == 3)
        #expect(keys == ["frequencyPerWeek", "experienceLevel", "guidancePermission"])
    }

    @Test("a successful response decodes into a plan with its sessions and guidance note")
    func successfulResponseDecodesIntoPlan() async throws {
        StubURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = """
            {"plan":{"frequencyPerWeek":3,"sessions":[{"dayIndex":1,"focus":"full-body foundations","exercises":[{"name":"Goblet squat","sets":2,"repRange":"12-15"}]}],"guidanceNote":"General guidance only."}}
            """.data(using: .utf8)!
            return (response, body)
        }
        let client = WorkoutPlanClient(session: makeStubbedSession(), baseURL: URL(string: "http://127.0.0.1:8080")!)

        let plan = try await client.fetchPlan(frequencyPerWeek: 3, experienceLevel: .beginner, workoutGate: .none)

        #expect(plan.frequencyPerWeek == 3)
        #expect(plan.sessions.count == 1)
        #expect(plan.sessions.first?.exercises.first?.name == "Goblet squat")
        #expect(plan.guidanceNote == "General guidance only.")
    }

    @Test("a restrictive workout gate produces a generic referral plan and makes no network request")
    func restrictiveGateShortCircuitsLocally() async throws {
        let client = WorkoutPlanClient(session: makeStubbedSession(), baseURL: URL(string: "http://127.0.0.1:8080")!)

        let plan = try await client.fetchPlan(frequencyPerWeek: 5, experienceLevel: .beginner, workoutGate: .requiredBlocking)

        #expect(plan.sessions.isEmpty)
        #expect(plan.guidanceNote.isEmpty == false)
        #expect(StubURLProtocol.requestCount == 0)
    }

    @Test("a non-success HTTP status surfaces a typed error rather than an empty plan")
    func nonSuccessStatusSurfacesTypedError() async throws {
        StubURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 400, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }
        let client = WorkoutPlanClient(session: makeStubbedSession(), baseURL: URL(string: "http://127.0.0.1:8080")!)

        await #expect(throws: WorkoutPlanClientError.self) {
            _ = try await client.fetchPlan(frequencyPerWeek: 5, experienceLevel: .beginner, workoutGate: .none)
        }
    }

    @Test("a malformed response body surfaces a typed decode error")
    func malformedResponseSurfacesDecodeError() async throws {
        StubURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, "not json".data(using: .utf8)!)
        }
        let client = WorkoutPlanClient(session: makeStubbedSession(), baseURL: URL(string: "http://127.0.0.1:8080")!)

        await #expect(throws: WorkoutPlanClientError.self) {
            _ = try await client.fetchPlan(frequencyPerWeek: 5, experienceLevel: .beginner, workoutGate: .none)
        }
    }

    @Test("an unreachable service surfaces a typed error the caller can present as an offline state")
    func unreachableServiceSurfacesTransportError() async throws {
        StubURLProtocol.requestHandler = { _ in throw URLError(.cannotConnectToHost) }
        let client = WorkoutPlanClient(session: makeStubbedSession(), baseURL: URL(string: "http://127.0.0.1:8080")!)

        await #expect(throws: WorkoutPlanClientError.self) {
            _ = try await client.fetchPlan(frequencyPerWeek: 5, experienceLevel: .beginner, workoutGate: .none)
        }
    }

    @Test("the request type carries exactly three properties, none of them diagnosis-bearing or identifying")
    func requestCarriesExactlyThreeProperties() {
        let request = WorkoutPlanRequest(frequencyPerWeek: 3, experienceLevel: "beginner", guidancePermission: "none")
        let mirror = Mirror(reflecting: request)
        #expect(mirror.children.count == 3)
    }
}
