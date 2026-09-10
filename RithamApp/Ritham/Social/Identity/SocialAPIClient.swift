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

/// The shared base URL, bearer injection, and typed decoding every social feature's API client
/// builds on -- friends, groups, goal-events, feed, and certificate clients in later plans all
/// route through this one type rather than each inventing its own request plumbing.
///
/// Reuses `WorkoutPlanClient`'s debug-versus-release base URL structure verbatim
/// (`RithamApp/Ritham/Recommendations/WorkoutPlanClient.swift`) rather than inventing a second
/// convention. The release host below is still a placeholder value because no real hosting exists
/// yet -- an unresolved deployment prerequisite carried from `04.1-RESEARCH.md`, not an oversight
/// (T-04.1-25: transport security is required in production and does not exist yet either).
///
/// Every method maps outcomes onto `SocialAPIError`'s four cases rather than letting a raw
/// `URLError`/`DecodingError` escape -- an unreachable service must read as an error, never as an
/// empty or zero result (T-04.1-26).
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

    /// An explicit request timeout well below `URLSession`'s default (60s), so an unreachable
    /// loopback service during local development fails fast and reads as `.transport` promptly
    /// rather than hanging a screen's loading state for a minute.
    private static let requestTimeout: TimeInterval = 15

    init(baseURL: URL = SocialAPIClient.defaultBaseURL, session: URLSession = .shared, sessionStore: SessionStore) {
        self.baseURL = baseURL
        self.session = session
        self.sessionStore = sessionStore
    }

    /// A bearer-authenticated (when a session token is stored) GET, decoded into `Response`.
    func get<Response: Decodable>(_ path: String) async throws -> Response {
        let data = try await perform(method: "GET", path: path, bodyData: nil)
        return try decode(data)
    }

    /// A bearer-authenticated (when a session token is stored) request carrying an encoded `Body`,
    /// decoded into `Response`.
    func send<Body: Encodable, Response: Decodable>(_ method: String, _ path: String, body: Body) async throws -> Response {
        let bodyData = try encode(body)
        let data = try await perform(method: method, path: path, bodyData: bodyData)
        return try decode(data)
    }

    /// The no-content overload: same request construction, but the response body is never decoded
    /// -- for routes that reply `204 No Content` (e.g. `POST /v1/identity/revoke`).
    func send<Body: Encodable>(_ method: String, _ path: String, body: Body) async throws {
        let bodyData = try encode(body)
        _ = try await perform(method: method, path: path, bodyData: bodyData)
    }

    /// A multipart upload with exactly one form part, named `fieldName`. Declared here so plan
    /// `04.1-14`'s photo attach has one place to call, rather than a second, divergent multipart
    /// implementation -- its response type mirrors the Go photo route's two keys
    /// (`PhotoUploadResponse` above).
    func upload(_ path: String, fieldName: String, filename: String, contentType: String, data: Data) async throws -> PhotoUploadResponse {
        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()
        body.append("--\(boundary)\r\n".utf8Data)
        body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(filename)\"\r\n".utf8Data)
        body.append("Content-Type: \(contentType)\r\n\r\n".utf8Data)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".utf8Data)

        var urlRequest = URLRequest(url: baseURL.appendingPathComponent(path))
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = Self.requestTimeout
        urlRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        if let token = await sessionStore.token {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        urlRequest.httpBody = body

        let responseData = try await execute(urlRequest)
        return try decode(responseData)
    }

    // MARK: - Shared request plumbing

    /// Resolves `path` against `baseURL` with `URL(string:relativeTo:)`, never
    /// `appendingPathComponent(_:)`. `appendingPathComponent` treats its entire argument as one
    /// literal path segment and percent-encodes `?` into `%3F` -- verified directly against
    /// Foundation before this fix landed -- so a caller-built query string (plan 04.1-15's
    /// `cursor`/`limit` feed pagination params, the first query-string-bearing route in this
    /// client's lifetime) would never reach the server as a real query at all, landing instead as
    /// literal escaped text inside the URL path and 404ing against the router's exact-path match.
    /// `URL(string:relativeTo:)` correctly splits `path` into path and query components at the
    /// first unescaped `?`, and produces a byte-identical URL to the old construction for every
    /// existing plain (query-free) path this client already calls -- verified against all of this
    /// file's own real call sites before this change landed.
    private func perform(method: String, path: String, bodyData: Data?) async throws -> Data {
        guard let resolvedURL = URL(string: path, relativeTo: baseURL) else {
            throw SocialAPIError.transport
        }
        var urlRequest = URLRequest(url: resolvedURL)
        urlRequest.httpMethod = method
        urlRequest.timeoutInterval = Self.requestTimeout
        if let token = await sessionStore.token {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let bodyData {
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.httpBody = bodyData
        }
        return try await execute(urlRequest)
    }

    /// The `URLRequest` -> typed-error pipeline shared by every request path (JSON and multipart
    /// alike): a transport failure, a missing/malformed `HTTPURLResponse`, and a non-2xx status
    /// each map onto their own `SocialAPIError` case before this function returns.
    private func execute(_ urlRequest: URLRequest) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            throw SocialAPIError.transport
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SocialAPIError.transport
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                throw SocialAPIError.unauthenticated
            }
            throw SocialAPIError.httpStatus(httpResponse.statusCode)
        }
        return data
    }

    private func encode<Body: Encodable>(_ body: Body) throws -> Data {
        guard let data = try? JSONEncoder().encode(body) else {
            throw SocialAPIError.transport
        }
        return data
    }

    private func decode<Response: Decodable>(_ data: Data) throws -> Response {
        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw SocialAPIError.decoding
        }
    }
}

private extension String {
    var utf8Data: Data {
        Data(utf8)
    }
}
