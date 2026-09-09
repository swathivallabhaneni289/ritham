import Foundation

// RED phase (Task 1, TDD): stubbed as a per-instance in-memory store, not yet backed by the
// Keychain. This intentionally fails `SocialIdentityTests.tokenWrittenByOneInstanceIsReadableByAnother`
// -- a fresh instance cannot see a token stored by a different instance's in-memory state -- proving
// the test actually exercises persistence rather than passing vacuously. GREEN commit replaces the
// storage mechanism; the public API surface below is already final.
@MainActor
final class SessionStore {
    private var storedToken: String?

    init() {}

    var token: String? {
        storedToken
    }

    var isSignedIn: Bool {
        token != nil
    }

    var currentUserID: String?
    var displayName: String?

    func store(token: String, expiresAt: Date, userID: String, displayName: String) {
        storedToken = token
        self.currentUserID = userID
        self.displayName = displayName
    }

    func clear() {
        storedToken = nil
        currentUserID = nil
        displayName = nil
    }
}
