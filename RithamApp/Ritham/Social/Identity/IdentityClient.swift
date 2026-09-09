import Foundation

/// The entire set of values permitted to leave the device for Sign in with Apple (ACCOUNT-01).
/// Mirrors `RithamService/internal/httpapi/contract.go`'s `AppleSignInRequest` JSON tags character
/// for character -- exactly three fields, asserted by `SocialIdentityTests`
/// `encodingProducesExactlyThreeKeys`, matching `WorkoutPlanRequest`'s own reflection-test
/// discipline (`RithamApp/Ritham/Recommendations/WorkoutPlanClient.swift`).
///
///   - identityToken: the raw Apple-issued identity JWT, verified server-side against Apple's
///     published keys -- never trusted at face value by this device.
///   - nonce: the SHA-256 hex digest `SocialIdentityModel.nonce()` generates, the same digest value
///     already handed to `ASAuthorizationAppleIDRequest.nonce`. Apple echoes that exact digest back
///     as the identity token's own `nonce` claim, and the Go service's `VerifyIdentityToken`
///     compares `expectedNonce` against that claim byte for byte (`internal/identity/apple.go`) --
///     there is no server-side hashing step. Sending the raw, unhashed nonce here would never match
///     and would make T-04.1-23's replay protection silently inert; sending the digest here is the
///     value that makes the check succeed for a legitimate request and fail for a replayed one.
///   - displayName: empty when not supplied. The server seeds it only on first sign-in when its own
///     stored value is still empty (`04.1-03-SUMMARY.md`) -- never overwrites an existing name.
///
/// No device identifier, no contact data, and no location field is accepted here, matching this
/// project's existing `WorkoutPlanRequest` data-minimization discipline.
struct AppleSignInRequest: Codable, Equatable {
    let identityToken: String
    let nonce: String
    let displayName: String

    enum CodingKeys: String, CodingKey {
        case identityToken
        case nonce
        case displayName
    }
}

/// Returned by a successful `POST /v1/identity/apple`. `sessionToken` is the opaque bearer token
/// this device must present on every authenticated route thereafter -- returned exactly once, per
/// `RithamService/internal/httpapi/contract.go`'s `SessionResponse` doc comment (only its SHA-256
/// digest is stored server-side). `expiresAt` arrives as an RFC3339 string, matching Go's
/// `time.RFC3339` formatting -- parsed by the caller, not decoded as a `Date` directly.
struct SessionResponse: Codable, Equatable {
    let userId: String
    let displayName: String
    let sessionToken: String
    let expiresAt: String
}

/// Returned by `GET /v1/identity/me`: the caller's own identity and current display name, nothing
/// else. Mirrors `RithamService/internal/httpapi/contract.go`'s `MeResponse`.
struct MeResponse: Codable, Equatable {
    let userId: String
    let displayName: String
}

/// The entire request body for `PUT /v1/identity/display-name` -- exactly one field. A name over
/// the server's own length ceiling is rejected (400), never truncated
/// (`RithamService/internal/httpapi/contract.go`'s `DisplayNameRequest`).
struct DisplayNameRequest: Codable, Equatable {
    let displayName: String

    enum CodingKeys: String, CodingKey {
        case displayName
    }
}

/// A request body with no fields, encoded as an empty JSON object. `POST /v1/identity/revoke`
/// authenticates purely off the bearer header (`internal/httpapi/handler.go`'s `handleRevokeSession`
/// never calls `json.Decoder.Decode` on the body at all) so this exists only to satisfy
/// `SocialAPIClient`'s no-content `send` overload's `Body: Encodable` requirement without adding a
/// fifth public client method beyond the four this plan's artifacts list declares.
private struct EmptyBody: Encodable {}

/// The four identity operations every social screen builds on: sign in, read the current identity,
/// rename, and revoke. A thin wrapper over `SocialAPIClient` -- no networking of its own, matching
/// this project's existing per-domain-client-over-shared-client shape.
struct IdentityClient {
    let apiClient: SocialAPIClient

    init(apiClient: SocialAPIClient) {
        self.apiClient = apiClient
    }

    /// `POST /v1/identity/apple` -- unauthenticated (it is the request that establishes a
    /// session), so `SocialAPIClient` sends no bearer header regardless of any locally stored
    /// (necessarily stale, since this call is what replaces it) token.
    func signInWithApple(identityToken: String, nonce: String, displayName: String) async throws -> SessionResponse {
        try await apiClient.send(
            "POST", "v1/identity/apple",
            body: AppleSignInRequest(identityToken: identityToken, nonce: nonce, displayName: displayName)
        )
    }

    /// `GET /v1/identity/me`, behind `RequireSession` server-side.
    func me() async throws -> MeResponse {
        try await apiClient.get("v1/identity/me")
    }

    /// `PUT /v1/identity/display-name`, behind `RequireSession`. The server's own response body
    /// (an updated `MeResponse`) is decoded and discarded -- the caller already knows the name it
    /// just set; nothing here needs a second source of truth for it.
    func setDisplayName(_ name: String) async throws {
        let _: MeResponse = try await apiClient.send("PUT", "v1/identity/display-name", body: DisplayNameRequest(displayName: name))
    }

    /// `POST /v1/identity/revoke`, behind `RequireSession`. Returns `204 No Content` server-side.
    func revoke() async throws {
        try await apiClient.send("POST", "v1/identity/revoke", body: EmptyBody())
    }
}
