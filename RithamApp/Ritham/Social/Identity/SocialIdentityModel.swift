import Foundation
import AuthenticationServices
import CryptoKit
import Security
import RithamCore

/// The Sign in with Apple flow's own state machine, driving `IdentityClient` and persisting
/// through `SessionStore`. `SignInWithAppleView` (and, later, any social screen that needs to know
/// whether an account exists) owns one instance of this type.
@MainActor
@Observable
final class SocialIdentityModel {
    enum State: Equatable {
        case signedOut
        case signingIn
        case signedIn(SocialUser)
        case failed(SocialAPIError)
    }

    private(set) var state: State = .signedOut

    private let client: IdentityClient
    private let sessionStore: SessionStore

    /// The SHA-256 digest handed to `ASAuthorizationAppleIDRequest.nonce` by `configureRequest(_:)`,
    /// held only for the duration of one in-flight authorization so `signIn(authorization:)` can
    /// send the identical value the server expects (see this type's own `nonce()` doc comment for
    /// why the digest, not the raw nonce, is what travels to the server).
    private var pendingNonceDigest: String?

    private static let sessionExpiryFormatter = ISO8601DateFormatter()

    init(
        client: IdentityClient = IdentityClient(apiClient: SocialAPIClient(sessionStore: SessionStore())),
        sessionStore: SessionStore = SessionStore()
    ) {
        self.client = client
        self.sessionStore = sessionStore
    }

    /// Generates a random raw nonce and its SHA-256 hex digest.
    ///
    /// **Which value goes where, and why (T-04.1-23):** Apple's `ASAuthorizationAppleIDRequest
    /// .nonce` is echoed back verbatim as the returned identity token's own `nonce` claim -- Apple
    /// does not hash it a second time. `RithamService/internal/identity/apple.go`'s
    /// `VerifyIdentityToken` compares its `expectedNonce` parameter against that claim byte for
    /// byte, with no server-side hashing step either (confirmed directly against
    /// `apple_test.go`'s `TestVerifyIdentityToken_MatchingNonceSucceeds`, which mints a token whose
    /// claim equals the exact same literal passed as `expectedNonce`). So the **digest** -- not the
    /// raw value -- is what must be sent to Apple as `request.nonce` *and* to the server as
    /// `AppleSignInRequest.nonce`, for the two to end up equal and the replay check to mean
    /// anything. The raw value exists only to derive that digest and is never itself transmitted.
    nonisolated static func nonce() -> (raw: String, sha256Hex: String) {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        if status != errSecSuccess {
            // SecRandomCopyBytes failing is effectively unreachable (no CSPRNG available), but a
            // nonce must never silently degrade to a fixed/predictable value even in that
            // theoretical path.
            bytes = (0..<32).map { _ in UInt8.random(in: 0...255) }
        }
        let raw = bytes.map { String(format: "%02x", $0) }.joined()
        let digest = SHA256.hash(data: Data(raw.utf8))
        let digestHex = digest.map { String(format: "%02x", $0) }.joined()
        return (raw, digestHex)
    }

    /// Configures the Apple authorization request's scope and nonce. Called from
    /// `SignInWithAppleButton`'s `onRequest` closure.
    func configureRequest(_ request: ASAuthorizationAppleIDRequest) {
        let (_, digest) = Self.nonce()
        pendingNonceDigest = digest
        request.requestedScopes = [.fullName]
        request.nonce = digest
    }

    /// Completes a successful Apple authorization: extracts the identity token, sends it (with the
    /// matching nonce digest) to the Ritham backend, and persists the resulting session.
    func signIn(authorization: ASAuthorization) async {
        guard
            let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
            let tokenData = credential.identityToken,
            let identityToken = String(data: tokenData, encoding: .utf8),
            let nonceDigest = pendingNonceDigest
        else {
            state = .failed(.decoding)
            return
        }

        // Apple supplies `fullName` only on the very first authorization for a given app; every
        // later sign-in returns `nil`. An empty string here is the deliberate "not supplied"
        // signal `AppleSignInRequest.displayName`'s own doc comment describes -- the server seeds
        // its stored display name only when its own value is still empty, so sending "" on a
        // second sign-in never overwrites a name the user may have since changed.
        let displayName = credential.fullName
            .map { PersonNameComponentsFormatter().string(from: $0) }
            .flatMap { $0.isEmpty ? nil : $0 } ?? ""

        state = .signingIn
        do {
            let session = try await client.signInWithApple(identityToken: identityToken, nonce: nonceDigest, displayName: displayName)
            let expiresAt = Self.sessionExpiryFormatter.date(from: session.expiresAt) ?? Date().addingTimeInterval(3600)
            sessionStore.store(token: session.sessionToken, expiresAt: expiresAt, userID: session.userId, displayName: session.displayName)
            state = .signedIn(SocialUser(id: SocialUserID(value: session.userId), displayName: session.displayName))
        } catch let error as SocialAPIError {
            state = .failed(error)
        } catch {
            state = .failed(.transport)
        }
        pendingNonceDigest = nil
    }

    /// Marks the flow as failed for a reason outside `SocialAPIError`'s own vocabulary -- e.g. the
    /// Apple authorization sheet itself returning an error before this device ever reaches the
    /// Ritham backend. `.transport` is the closest existing case (no response was ever obtained),
    /// used as the default so a caller need not invent a fifth `SocialAPIError` case just for this.
    func markFailed(_ error: SocialAPIError = .transport) {
        state = .failed(error)
    }

    /// Calls the identity endpoint and syncs `state` to what the server currently believes. Called
    /// on appear, so a server-side revocation (T-04.1-27) takes effect on this device too, the
    /// moment this screen is shown again -- never trusting a locally cached "still signed in" flag.
    func refresh() async {
        guard sessionStore.isSignedIn else {
            state = .signedOut
            return
        }
        do {
            let me = try await client.me()
            state = .signedIn(SocialUser(id: SocialUserID(value: me.userId), displayName: me.displayName))
        } catch SocialAPIError.unauthenticated {
            sessionStore.clear()
            state = .signedOut
        } catch let error as SocialAPIError {
            state = .failed(error)
        } catch {
            state = .failed(.transport)
        }
    }

    /// Revokes the session server-side, then clears it locally regardless of whether the network
    /// call succeeded -- a failed revoke attempt must never leave the user stuck appearing signed
    /// in on this device (the whole point of "sign out").
    func signOut() async {
        try? await client.revoke()
        sessionStore.clear()
        state = .signedOut
    }
}
