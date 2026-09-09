import Foundation
import Security

/// Keychain-backed session token storage -- this project's first use of the Security framework
/// (no prior Keychain usage exists anywhere in the codebase; `HealthDataStore`'s file-protection
/// classes are a SwiftData/on-disk mechanism, a different layer entirely).
///
/// Only the session token itself is stored in the Keychain, under
/// `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` (T-04.1-24) -- it neither syncs to another
/// device via iCloud Keychain nor restores from a device backup, matching this token's device-scoped
/// nature by design: cross-device continuity comes from signing in again with the same Apple ID
/// (ACCOUNT-01), never from copying a token. The non-secret display name and user id live in
/// `UserDefaults` alongside it, matching the "secret vs. non-secret gets a different storage tier"
/// split this project has not needed before this plan.
///
/// Deliberately holds no in-memory cache of the token: every read goes straight to the Keychain, so
/// a token written by one instance is immediately visible to a freshly constructed one
/// (`SocialIdentityTests.tokenWrittenByOneInstanceIsReadableByAnother`) -- there is no staleness
/// window an in-memory cache would otherwise introduce between two `SessionStore` instances (e.g.
/// one held by `SocialAPIClient`, another by `SocialIdentityModel`).
@MainActor
final class SessionStore {
    private static let service = "com.ritham.app.social"
    private static let tokenAccount = "sessionToken"
    private static let userIDDefaultsKey = "com.ritham.app.social.userID"
    private static let displayNameDefaultsKey = "com.ritham.app.social.displayName"

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    /// Reads straight from the Keychain on every access -- no cached copy (see this type's own
    /// header comment for why that matters).
    var token: String? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: Self.tokenAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    var isSignedIn: Bool {
        token != nil
    }

    var currentUserID: String? {
        userDefaults.string(forKey: Self.userIDDefaultsKey)
    }

    var displayName: String? {
        userDefaults.string(forKey: Self.displayNameDefaultsKey)
    }

    /// Replaces any previously stored session wholesale -- a session token is never partially
    /// updated, only fully replaced by a new sign-in. `expiresAt` is accepted for API symmetry with
    /// the server's `SessionResponse` (callers pass the parsed expiry straight through) but is not
    /// itself persisted: this plan's `SocialIdentityModel.refresh()` re-validates the session against
    /// the server on every appearance rather than trusting a locally cached expiry, so a locally
    /// stored expiry would be redundant, never authoritative, data.
    func store(token: String, expiresAt: Date, userID: String, displayName: String) {
        writeToken(token)
        userDefaults.set(userID, forKey: Self.userIDDefaultsKey)
        userDefaults.set(displayName, forKey: Self.displayNameDefaultsKey)
    }

    /// Removes the session from the device entirely: the Keychain item and both `UserDefaults`
    /// values. Never a partial clear.
    func clear() {
        deleteToken()
        userDefaults.removeObject(forKey: Self.userIDDefaultsKey)
        userDefaults.removeObject(forKey: Self.displayNameDefaultsKey)
    }

    /// Delete-then-add is the simplest correct upsert here: a session token is always replaced
    /// wholesale (see `store`'s own comment), so there is no partial-attribute-update case that
    /// would need `SecItemUpdate` instead.
    private func writeToken(_ token: String) {
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: Self.tokenAccount,
        ]
        SecItemDelete(baseQuery as CFDictionary)

        var addQuery = baseQuery
        addQuery[kSecValueData as String] = Data(token.utf8)
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    private func deleteToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: Self.tokenAccount,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
