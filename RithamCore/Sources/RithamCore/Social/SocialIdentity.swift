import Foundation

// ACCOUNT-01: Sign in with Apple-anchored identity, per 04.1-CONTEXT.md's Identity & Account
// Recovery decision. Ritham's backend verifies Apple's identity token against Apple's published
// public keys and stores only the resulting stable Apple user identifier plus its own opaque
// user ID and session token -- these are the pure domain mirrors of that server state, value
// types only, matching `MomentumLedger.swift`'s established layer split (pure domain here;
// SwiftData records and wire types are separate layers built by later plans).

/// Ritham's own opaque user identifier -- never the Apple-issued identity token or a raw Apple
/// user ID exposed to any client-visible type.
public struct SocialUserID: Hashable, Sendable, Codable {
    public var value: String

    public init(value: String) {
        self.value = value
    }
}

public struct SocialUser: Sendable, Equatable, Codable {
    public var id: SocialUserID
    public var displayName: String

    public init(id: SocialUserID, displayName: String) {
        self.id = id
        self.displayName = displayName
    }
}

/// A signed-in session. Deliberately not `Codable` -- a session token is bearer-sensitive and
/// this type is never persisted to disk or serialized as a JSON field on a broader payload; a
/// later plan's transport layer carries the token separately (e.g. an Authorization header), not
/// as an encoded `SocialSession` value.
public struct SocialSession: Sendable, Equatable {
    public var userID: SocialUserID
    public var expiresAt: Date

    public init(userID: SocialUserID, expiresAt: Date) {
        self.userID = userID
        self.expiresAt = expiresAt
    }
}
