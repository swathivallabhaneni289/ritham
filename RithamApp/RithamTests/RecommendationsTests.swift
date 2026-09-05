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

// Task 2: the triggered walk-or-light-lift pre-assessment.
@MainActor
@Suite("PreAssessmentTests")
struct PreAssessmentTests {

    private func makeStore() throws -> HealthDataStore {
        let container = try RithamModelContainer.make(inMemory: true)
        return HealthDataStore(context: ModelContext(container))
    }

    @Test("registers as the pre-assessment step")
    func registersAsPreAssessmentStep() {
        #expect(PreAssessmentView.step == .preAssessment)
    }

    @Test("a walk that reaches the qualifying duration derives a measured baseline")
    func walkReachingQualifyingDurationDerivesBaseline() {
        var now = Date(timeIntervalSince1970: 0)
        let model = PreAssessmentModel(now: { now })
        model.selectMode(.walk)
        model.start()
        now = now.addingTimeInterval(CalibrationThreshold.qualifyingWalkDuration)

        #expect(model.isComplete)
        let baseline = CalibrationBaseline.derive(from: model.progress, establishedAt: now)
        #expect(baseline?.source == .measured)
    }

    @Test("a walk that falls short of the qualifying duration does not derive a baseline")
    func walkFallingShortDoesNotDeriveBaseline() {
        var now = Date(timeIntervalSince1970: 0)
        let model = PreAssessmentModel(now: { now })
        model.selectMode(.walk)
        model.start()
        now = now.addingTimeInterval(CalibrationThreshold.qualifyingWalkDuration - 60)

        #expect(model.isComplete == false)
        let baseline = CalibrationBaseline.derive(from: model.progress, establishedAt: now)
        #expect(baseline == nil)
    }

    @Test("a lift that reaches both the working-set and distinct-exercise thresholds derives a measured baseline")
    func liftReachingBothThresholdsDerivesBaseline() {
        let model = PreAssessmentModel()
        model.selectMode(.lift)
        model.start()
        model.recordWorkingSet(exercise: "Squat", loadKg: 40)
        model.recordWorkingSet(exercise: "Squat", loadKg: 40)
        model.recordWorkingSet(exercise: "Bench press", loadKg: 30)

        #expect(model.isComplete)
        let baseline = CalibrationBaseline.derive(from: model.progress, establishedAt: Date())
        #expect(baseline?.source == .measured)
    }

    @Test("a lift short of either threshold does not derive a baseline")
    func liftShortOfThresholdDoesNotDeriveBaseline() {
        let model = PreAssessmentModel()
        model.selectMode(.lift)
        model.start()
        model.recordWorkingSet(exercise: "Squat", loadKg: 40)

        #expect(model.isComplete == false)
        let baseline = CalibrationBaseline.derive(from: model.progress, establishedAt: Date())
        #expect(baseline == nil)
    }

    @Test("completing the assessment marks the pre-assessment complete and stores the derived baseline")
    func completingMarksCompleteAndStoresBaseline() throws {
        let store = try makeStore()
        var now = Date(timeIntervalSince1970: 0)
        let model = PreAssessmentModel(now: { now })
        model.selectMode(.walk)
        model.start()
        now = now.addingTimeInterval(CalibrationThreshold.qualifyingWalkDuration)

        let didComplete = model.complete(store: store)

        #expect(didComplete)
        #expect(try store.loadHasCompletedPreAssessment())
        #expect(try store.loadCalibrationBaseline()?.source == .measured)
    }

    @Test("completing the assessment adds no cardio session and no lift session to training history")
    func completingAddsNoTrainingHistory() throws {
        let store = try makeStore()
        var now = Date(timeIntervalSince1970: 0)
        let model = PreAssessmentModel(now: { now })
        model.selectMode(.walk)
        model.start()
        now = now.addingTimeInterval(CalibrationThreshold.qualifyingWalkDuration)

        _ = model.complete(store: store)

        #expect(try store.loadCardioSessions().count == 0)
        #expect(try store.loadLiftSessions().count == 0)
    }

    @Test("skipping stores no measured baseline, marks the pre-assessment complete, and leaves the provisional baseline in place")
    func skippingLeavesProvisionalBaselineInPlace() throws {
        let store = try makeStore()
        let model = PreAssessmentModel()

        model.skip(store: store)

        #expect(try store.loadHasCompletedPreAssessment())
        #expect(try store.loadCalibrationBaseline()?.source == .provisional)
    }
}

// Task 3: the Recommendations surface and registrar rewrite.
// `.serialized`: `sendsStoredFrequencyAndDerivedExperienceBucket` shares `StubURLProtocol`'s
// static state with `WorkoutPlanClientTests`, the same race class documented there.
@MainActor
@Suite("RecommendationsScreenTests", .serialized)
struct RecommendationsScreenTests {

    init() {
        StubURLProtocol.reset()
    }

    private func makeStore() throws -> HealthDataStore {
        let container = try RithamModelContainer.make(inMemory: true)
        return HealthDataStore(context: ModelContext(container))
    }

    private func makeStubbedClient(handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?) -> WorkoutPlanClient {
        StubURLProtocol.requestHandler = handler
        return WorkoutPlanClient(session: makeStubbedSession(), baseURL: URL(string: "http://127.0.0.1:8080")!)
    }

    private func successResponseBody(sessions: String = "[]") -> Data {
        """
        {"plan":{"frequencyPerWeek":3,"sessions":\(sessions),"guidanceNote":"General guidance only."}}
        """.data(using: .utf8)!
    }

    @Test("registers as the recommendations step")
    func registersAsRecommendationsStep() {
        #expect(RecommendationsView.step == .recommendations)
    }

    @Test("with the pre-assessment flag false, requesting a plan opens the pre-assessment step and issues no network request")
    func requestingPlanWithoutPreAssessmentOpensPreAssessment() async throws {
        let store = try makeStore()
        let client = makeStubbedClient(handler: nil)
        let model = RecommendationsModel(store: store, client: client)
        let flow = OnboardingFlow(path: [.home, .recommendations])

        await model.requestPlan(flow: flow)

        #expect(flow.path.last == .preAssessment)
        #expect(StubURLProtocol.requestCount == 0)
        #expect(model.state == .idle)
    }

    @Test("after the pre-assessment is complete, requesting a plan calls the client and renders the plan")
    func requestingPlanAfterPreAssessmentFetchesPlan() async throws {
        let store = try makeStore()
        try store.markPreAssessmentCompleted()
        let client = makeStubbedClient { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = """
            {"plan":{"frequencyPerWeek":3,"sessions":[{"dayIndex":1,"focus":"full-body foundations","exercises":[{"name":"Goblet squat","sets":2,"repRange":"12-15"}]}],"guidanceNote":"General guidance only."}}
            """.data(using: .utf8)!
            return (response, body)
        }
        let model = RecommendationsModel(store: store, client: client)
        let flow = OnboardingFlow(path: [.home, .recommendations])

        await model.requestPlan(flow: flow)

        guard case .plan(let plan) = model.state else {
            Issue.record("expected a plan state, got \(model.state)")
            return
        }
        #expect(plan.sessions.count == 1)
        #expect(flow.path.last == .recommendations)
    }

    @Test("a transport error renders the error state and not a zero-session plan")
    func transportErrorRendersErrorState() async throws {
        let store = try makeStore()
        try store.markPreAssessmentCompleted()
        let client = makeStubbedClient { _ in throw URLError(.cannotConnectToHost) }
        let model = RecommendationsModel(store: store, client: client)
        let flow = OnboardingFlow(path: [.home, .recommendations])

        await model.requestPlan(flow: flow)

        guard case .error = model.state else {
            Issue.record("expected an error state, got \(model.state)")
            return
        }
    }

    @Test("under a blocking workout gate the model renders a generic referral plan with no numeric prescriptions, with no network call")
    func blockingGateRendersReferralPlanWithNoNetworkCall() async throws {
        let store = try makeStore()
        try store.markPreAssessmentCompleted()
        try store.updateProfile(UserProfileDraft(age: 30))
        let now = Date()
        let result = GateResolutionResult(
            matchedTags: [.heartDiseaseRecentEventOrSymptomatic],
            gates: DomainGates(workout: .requiredBlocking, nutrition: .requiredBlocking),
            interstitial: .none,
            requiresIndependentAllergenVerification: false
        )
        try store.saveScreeningResult(result, answers: ScreeningAnswers(), now: now)

        let client = makeStubbedClient(handler: nil)
        let model = RecommendationsModel(store: store, client: client)
        let flow = OnboardingFlow(path: [.home, .recommendations])

        await model.requestPlan(flow: flow, now: now)

        guard case .plan(let plan) = model.state else {
            Issue.record("expected a referral plan state, got \(model.state)")
            return
        }
        #expect(plan.sessions.isEmpty)
        #expect(plan.frequencyPerWeek == 0)
        #expect(StubURLProtocol.requestCount == 0)
    }

    @Test("the request sends the stored weekly frequency and derived experience bucket, not screen-typed values")
    func sendsStoredFrequencyAndDerivedExperienceBucket() async throws {
        let store = try makeStore()
        try store.markPreAssessmentCompleted()
        try store.saveWeeklyFrequency(7)
        try store.saveCalibrationBaseline(CalibrationBaseline(
            paceZone: PaceZone(500, 400),
            safeStartingWeightKg: 20,
            source: .measured,
            establishedAt: Date()
        ))

        nonisolated(unsafe) var capturedRequest: WorkoutPlanRequest?
        let client = makeStubbedClient { request in
            capturedRequest = try? JSONDecoder().decode(WorkoutPlanRequest.self, from: request.httpBody ?? Data())
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, self.successResponseBody())
        }
        let model = RecommendationsModel(store: store, client: client)
        let flow = OnboardingFlow(path: [.home, .recommendations])

        await model.requestPlan(flow: flow)

        #expect(capturedRequest?.frequencyPerWeek == 7)
        #expect(capturedRequest?.experienceLevel == "intermediate")
    }
}
