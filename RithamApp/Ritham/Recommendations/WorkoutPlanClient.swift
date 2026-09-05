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
///
/// STUB (TDD RED): always fails with `.transport` and never performs the local short-circuit --
/// `WorkoutPlanClientTests` should fail meaningfully against this stub before the real
/// implementation lands.
struct WorkoutPlanClient {
    private let session: URLSession
    private let baseURL: URL

    #if DEBUG
    static let defaultBaseURL = URL(string: "http://127.0.0.1:8080")!
    #else
    static let defaultBaseURL = URL(string: "https://api.ritham.invalid")!
    #endif

    init(session: URLSession = .shared, baseURL: URL = WorkoutPlanClient.defaultBaseURL) {
        self.session = session
        self.baseURL = baseURL
    }

    func fetchPlan(
        frequencyPerWeek: Int,
        experienceLevel: ExperienceLevel,
        workoutGate: ClearanceGate
    ) async throws -> WorkoutPlan {
        throw WorkoutPlanClientError.transport
    }
}
