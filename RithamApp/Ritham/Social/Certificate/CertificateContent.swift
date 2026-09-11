import Foundation
import RithamCore

/// GROUPEVENTS-05's never-on-it list ("no other member's name, photo, status, or time") is
/// satisfied here by absence rather than by filtering: this is the complete, closed set of values
/// a certificate may ever carry. There is no field on this type capable of holding another
/// member's identity, photo, status, or time -- `CertificateTests`'s reflection test pins this
/// type's exact seven-field set, so adding an eighth field is a product decision that must fail
/// that test first, not a change a later editor can slip in unnoticed.
///
/// There is also deliberately no field for a member count or a completion figure. A solo export
/// must never carry group composition -- `docs/group-events.md` §5's group-composition rule and
/// this phase's own Non-Comparative Structural Visual Rules both forbid a denominator anywhere
/// near a completion, and a certificate is exactly the kind of artifact a "6 of 8 finished"
/// afterthought would otherwise get bolted onto.
///
/// `photo` is typed `StrippedPhotoAsset?`, not `UIImage?`/`Data?`/a file `URL` -- see
/// `CertificateComposer.swift`'s own header comment for why that type, and only that type, may
/// ever reach this struct's initializer.
struct CertificateContent: Equatable, Sendable {
    var eventDisplayName: String
    var activityType: ActivityType
    var participantName: String
    var completionDate: Date
    var ownTimeSeconds: Int?
    var placeName: String?
    var photo: StrippedPhotoAsset?
}
