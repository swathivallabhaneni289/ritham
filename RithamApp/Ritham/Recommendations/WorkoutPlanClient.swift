import Foundation
import RithamCore

// D-07's data-minimization boundary, enforced here rather than only documented: the three
// properties on `WorkoutPlanRequest` below are the complete set of values this app is ever
// permitted to send to the workout-plan service. `guidancePermission` is a three-state
// already-resolved gate result, never anything that could reveal which specific health flag
// produced it, and never a raw intake questionnaire answer of any kind. The pace/weight numbers a
// baseline session measures never leave this device either -- only the coarse `experienceLevel`
// bucket derived from them crosses the wire. No stable per-person or per-phone identifier is ever
// included, or ever will be for this endpoint's current scope. Adding a property to
// `WorkoutPlanRequest` widens LAUNCH-04's GDPR/CCPA privacy-review surface and is a decision
// requiring its own review, not an implementation detail -- see 02-RESEARCH.md's Go Backend
// Research §4 and 02-CONTEXT.md's D-07. `WorkoutPlanClientTests` enforces the three-key shape by
// encoding a request and inspecting the serialized JSON object directly, so a future edit that
// widens this boundary fails a test gate rather than passing silently.
//
// <!-- planner-discipline-allow: guidancePermission -->

/// The entire set of values permitted to leave the device for workout-plan generation (D-07).
/// Coding keys match `RithamService/internal/httpapi/contract.go`'s `WorkoutPlanRequest` JSON
/// tags character for character.
struct WorkoutPlanRequest: Codable, Equatable {
    let frequencyPerWeek: Int
    let experienceLevel: String
    let guidancePermission: String

    enum CodingKeys: String, CodingKey {
        case frequencyPerWeek
        case experienceLevel
        case guidancePermission
    }
}

/// Wraps the generated plan under a `plan` key, matching
/// `RithamService/internal/httpapi/contract.go`'s `WorkoutPlanResponse`.
struct WorkoutPlanResponse: Decodable, Equatable {
    let plan: WorkoutPlan
}

/// A full weekly workout plan, or -- under the most restrictive permission -- an empty plan
/// carrying only a referral note and no numeric field populated anywhere.
struct WorkoutPlan: Codable, Equatable {
    let frequencyPerWeek: Int
    let sessions: [WorkoutPlanSession]
    let guidanceNote: String
}

struct WorkoutPlanSession: Codable, Equatable, Identifiable {
    let dayIndex: Int
    let focus: String
    let exercises: [WorkoutPlanExercise]

    var id: Int { dayIndex }
}

struct WorkoutPlanExercise: Codable, Equatable {
    let name: String
    let sets: Int
    let repRange: String
}

/// Every failure mode this client can surface. The calling screen renders each of these as its
/// own error state with a retry action -- an unreachable local service during development must
/// read as an error, never as an empty or zero-session plan, which would be indistinguishable
/// from a legitimately blocked result (T-02-38).
enum WorkoutPlanClientError: Error, Equatable {
    /// The request never reached the service, or no response came back at all.
    case transport
    /// The service responded with a non-2xx status code.
    case httpStatus(Int)
    /// The response body did not decode into the expected shape.
    case decoding
}

/// Calls the Go workout-plan service over plain `URLSession` -- no third-party networking
/// dependency. A Debug build points at the loopback address the service binds to
/// (`RithamService/cmd/ritham-service/main.go`); a Release build points at a placeholder host
/// until real hosting and an authentication story are decided (see that file's own header
/// comment on the absent-auth gap).
struct WorkoutPlanClient {
    private let session: URLSession
    private let baseURL: URL

    #if DEBUG
    /// The loopback address `ritham-service` binds to by default (`PORT` unset -> `:8080`).
    /// Simulator shares the host Mac's network, so this resolves with no extra networking setup.
    static let defaultBaseURL = URL(string: "http://127.0.0.1:8080")!
    #else
    /// A placeholder only -- real hosting has not been decided yet. Shipping a Release build
    /// against this host is a decision that still needs to happen, not something this client
    /// should silently default around.
    static let defaultBaseURL = URL(string: "https://api.ritham.invalid")!
    #endif

    init(session: URLSession = .shared, baseURL: URL = WorkoutPlanClient.defaultBaseURL) {
        self.session = session
        self.baseURL = baseURL
    }

    /// Produces a plan for the given weekly frequency, experience bucket and already-resolved
    /// workout gate.
    ///
    /// When `workoutGate` is the most restrictive value, this returns a generic referral plan
    /// built entirely on device and constructs no request at all -- the planning-time note in
    /// 02-RESEARCH.md's Go Backend Research §4: the client already knows the answer is
    /// "generic-only" without asking the service, and skipping the call sends strictly less data
    /// in exactly the most sensitive case.
    func fetchPlan(
        frequencyPerWeek: Int,
        experienceLevel: ExperienceLevel,
        workoutGate: ClearanceGate
    ) async throws -> WorkoutPlan {
        guard workoutGate != .requiredBlocking else {
            return Self.localReferralPlan
        }

        let requestBody = WorkoutPlanRequest(
            frequencyPerWeek: frequencyPerWeek,
            experienceLevel: experienceLevel.rawValue,
            guidancePermission: Self.wireValue(for: workoutGate)
        )

        var urlRequest = URLRequest(url: baseURL.appendingPathComponent("v1/workout-plan"))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        guard let body = try? JSONEncoder().encode(requestBody) else {
            throw WorkoutPlanClientError.transport
        }
        urlRequest.httpBody = body

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            throw WorkoutPlanClientError.transport
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw WorkoutPlanClientError.transport
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw WorkoutPlanClientError.httpStatus(httpResponse.statusCode)
        }

        do {
            return try JSONDecoder().decode(WorkoutPlanResponse.self, from: data).plan
        } catch {
            throw WorkoutPlanClientError.decoding
        }
    }

    /// A generic, non-personalized plan with no numeric prescription anywhere, mirroring the
    /// service's own required-blocking shape (`RithamService/internal/plan/generate.go`).
    /// `frequencyPerWeek` is left at its zero value deliberately, the same "no numeric field
    /// populated anywhere" reading that file's own generation function applies. The guidance note
    /// reuses `WorkoutGuidanceCatalog.referralMessage` rather than a second transcription, so the
    /// on-device and server-driven referral paths can never read as two different messages.
    private static var localReferralPlan: WorkoutPlan {
        WorkoutPlan(frequencyPerWeek: 0, sessions: [], guidanceNote: WorkoutGuidanceCatalog.referralMessage)
    }

    private static func wireValue(for gate: ClearanceGate) -> String {
        switch gate {
        case .none: return "none"
        case .recommended: return "recommended"
        case .requiredBlocking: return "requiredBlocking"
        }
    }
}
