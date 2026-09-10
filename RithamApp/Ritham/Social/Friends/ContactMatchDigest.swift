import Foundation
import CryptoKit

/// Turns a device contact identifier (phone number or email) into a salted digest before it ever
/// leaves the device -- the client half of GROUPEVENTS-01's both-sides-opt-in contact matching
/// (T-04.1-51).
///
/// Two rules from `docs/group-events.md` §1 shape this file:
///   1. Raw contact identifiers never leave the device -- only this type's `Data` digest output
///      is ever handed to `FriendsClient`, never the identifier string itself.
///   2. A digest is submitted only while the user is opted in --
///      `FriendsModel.setContactMatchOptIn(_:digests:)` enforces this at the call site by
///      submitting an empty digest array whenever the opt-in is off, regardless of what this
///      type produces.
///
/// **Correction to this plan's own text (Rule 1):** PLAN.md's action text for this file says
/// "the salt value comes from the same configuration point the Go side reads." Reading
/// `RithamService/internal/friends/contactmatch.go` directly before implementing shows that is
/// architecturally wrong: the server applies its own additional HMAC-SHA256 pass
/// (`Service.saltDigest`, keyed by `RITHAM_CONTACT_MATCH_SALT`) uniformly to whatever digest this
/// client submits, regardless of what hash or salt this client used to produce it -- so a client
/// salt does not need to equal, or even relate to, the server's runtime salt for two different
/// users' digests of the same identifier to compare equal after the server's own pass. What
/// *does* matter, and is the actual reason `applicationSalt` exists here at all, is twofold: (a)
/// a fixed, non-empty salt raises the bar against an offline dictionary attack on the
/// pre-server-salt digest value that crosses the wire (a bare `SHA256(identifier)` would be
/// guessable against a phone-number keyspace via a precomputed rainbow table); and (b) every
/// install of this app must use the *identical* constant, forever, once shipped -- if a future
/// release ever changed `applicationSalt`, a pre-update device's already-submitted digests would
/// silently stop matching a post-update device's freshly computed digests for the same
/// identifier, with zero matches and no visible error, not a byte-identical value to
/// `RITHAM_CONTACT_MATCH_SALT` (that env var is a server-only secret with no iOS equivalent to
/// read it from, and copying its own documented development-only literal into this client would
/// read as shipping a "secret" value to production, inviting a future editor to "fix" this file
/// to read a server env var that does not and should not exist on-device). Treat this constant,
/// once shipped, as append-only/frozen -- exactly like a database migration already applied to
/// production.
enum ContactMatchDigest {
    /// A fixed constant compiled into every copy of this app -- never a per-device, per-user, or
    /// runtime-configured value. See this type's own header comment for the full rationale.
    static let applicationSalt = "ritham-contact-match-client-v1"

    /// Normalizes (trim whitespace, lowercase) then SHA-256-hashes each of `contacts` with
    /// `salt` appended, so the same address written with different capitalization or
    /// surrounding whitespace always produces the identical digest, and no raw identifier is
    /// itself ever returned.
    static func digests(for contacts: [String], salt: String) -> [Data] {
        contacts.map { contact in
            let normalized = contact.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let hash = SHA256.hash(data: Data((normalized + salt).utf8))
            return Data(hash)
        }
    }
}
