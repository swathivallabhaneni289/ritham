import Foundation

/// Returned by both `POST /v1/photos` and `GET /v1/photos/{id}` (`04.1-14`'s eventual consumer).
/// Mirrors `RithamService/internal/httpapi/photo_handler.go`'s `PhotoUploadResponse` JSON tags.
struct PhotoUploadResponse: Decodable, Equatable {
    let photoAssetID: String
    let sharedURL: String

    enum CodingKeys: String, CodingKey {
        case photoAssetID = "photoAssetId"
        case sharedURL = "sharedUrl"
    }
}

// RED phase (Task 1, TDD): every method below unconditionally throws `.transport`, ignoring its
// input entirely -- no bearer injection, no request construction, no response handling. This fails
// `SocialIdentityTests`' bearer-header-present test (`capturedAuthHeader` stays `nil` because the
// stubbed session is never invoked) and every error-vocabulary test that expects a case other than
// `.transport`, while incidentally passing the no-token/no-header and transport-failure cases --
// TDD requires the suite to fail on real, unimplemented behavior, not that literally every
// assertion fails. GREEN commit replaces the body; the public API surface below is already final,
// reusing `WorkoutPlanClient`'s debug-versus-release base URL structure verbatim
/// (`RithamApp/Ritham/Recommendations/WorkoutPlanClient.swift`) rather than inventing a second
/// convention. The release host below is still a placeholder value because no real hosting exists
/// yet -- an unresolved deployment prerequisite carried from `04.1-RESEARCH.md`, not an oversight.
struct SocialAPIClient {
    private let session: URLSession
    private let baseURL: URL
    private let sessionStore: SessionStore

    #if DEBUG
    /// The loopback address `ritham-service` binds to by default (`PORT` unset -> `:8080`).
    /// Simulator shares the host Mac's network, so this resolves with no extra networking setup.
    static let defaultBaseURL = URL(string: "http://127.0.0.1:8080")!
    #else
    /// A placeholder only -- real hosting has not been decided yet, matching
    /// `WorkoutPlanClient.defaultBaseURL`'s own Release placeholder and its identical caveat.
    static let defaultBaseURL = URL(string: "https://api.ritham.invalid")!
    #endif

    init(baseURL: URL = SocialAPIClient.defaultBaseURL, session: URLSession = .shared, sessionStore: SessionStore) {
        self.baseURL = baseURL
        self.session = session
        self.sessionStore = sessionStore
    }

    func get<Response: Decodable>(_ path: String) async throws -> Response {
        throw SocialAPIError.transport
    }

    func send<Body: Encodable, Response: Decodable>(_ method: String, _ path: String, body: Body) async throws -> Response {
        throw SocialAPIError.transport
    }

    func send<Body: Encodable>(_ method: String, _ path: String, body: Body) async throws {
        throw SocialAPIError.transport
    }

    func upload(_ path: String, fieldName: String, filename: String, contentType: String, data: Data) async throws -> PhotoUploadResponse {
        throw SocialAPIError.transport
    }
}
