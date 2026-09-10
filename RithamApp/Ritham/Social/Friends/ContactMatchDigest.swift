import Foundation

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
/// RED (Task 1, stub): returns one empty `Data` value per contact, ignoring both normalization
/// and `salt` -- deliberately wrong so `FriendsUITestsTask1's` digest-behavior tests fail
/// meaningfully before the real implementation lands in the GREEN commit.
enum ContactMatchDigest {
    static func digests(for contacts: [String], salt: String) -> [Data] {
        contacts.map { _ in Data() }
    }
}
