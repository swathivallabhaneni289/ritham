import SwiftUI

/// Composes `CertificateCardView` into a static image using the platform's own view-to-image
/// renderer (`ImageRenderer`) -- no third-party dependency, no second rendering path.
///
/// **Why this type's only photo input is `CertificateContent.photo: StrippedPhotoAsset?`, never a
/// local file reference, raw image bytes, a decoded platform image, or the system photo picker's
/// own selection type.** 04.1-RESEARCH.md Pattern 4 and Pitfall 5 describe the exact failure mode
/// this guards against: the client holds the metadata-intact original photo in its own photo
/// library the whole time a completion is being logged, and reaching for that reference from this
/// file would be the path of least resistance in ordinary view code -- it would compile, it would
/// look correct on screen, and it would silently leak the original's metadata through the exported
/// image even though `RithamService/internal/photo`'s server-side stripping pipeline ran correctly
/// on the copy that was actually uploaded. Because this type's only photo-shaped input is
/// `CertificateContent`, and `CertificateContent.photo` is typed `StrippedPhotoAsset?` -- a type
/// whose only accessible initializer takes the server's own upload response
/// (`StrippedPhotoAsset.swift`) -- there is no local-original reference anywhere in this call graph
/// for a future editor to reach for by accident. The bypass is unreachable by construction, not
/// merely discouraged by convention.
///
/// `CertificateTests` pins this file's own source text as a second, independent guarantee beyond
/// the type signature alone -- deliberately not spelling the disallowed type names out literally in
/// this comment either, matching `CompletionLoggingModel.swift`'s own precedent for this exact kind
/// of self-referential source-scan gate (the grep this gate runs does not filter comments, so a
/// comment naming the very tokens it forbids would trip its own check).
enum CertificateComposer {
    /// The default export scale -- @3x, matching this device family's own default screen scale, so
    /// an exported certificate reads crisply on the recipient's device regardless of what scale
    /// rendered it.
    static let defaultExportScale: CGFloat = 3

    /// Renders `content` to a `UIImage` at `scale`. `nil` only if `ImageRenderer` itself fails to
    /// produce an image (a platform-level failure, not a validation error this type has any
    /// recovery path for).
    @MainActor
    static func render(_ content: CertificateContent, scale: CGFloat = defaultExportScale) -> UIImage? {
        let renderer = ImageRenderer(content: CertificateCardView(content: content))
        renderer.scale = scale
        return renderer.uiImage
    }
}
