import Foundation
import PhotosUI
import SwiftUI
import UIKit

/// 04.1-RESEARCH.md Pattern 2 / Pitfall 2: the server's strip pipeline (`RithamService/internal/photo`,
/// plan 04.1-04) decodes only formats the Go standard library knows -- it deliberately does not
/// decode HEIC, the container format an iPhone camera captures into by default. Without a
/// client-side transcode, every ordinary capture would hit the server's reject path (415) instead
/// of the success path plan 04.1-04 already pinned. This file is what keeps normal photo attaches
/// on the success path: every picked item, regardless of its original container, is decoded and
/// re-encoded as JPEG -- the one format that both leaves this device and the format the server's
/// pipeline is built to strip and re-encode -- using only the platform's own `UIKit`/`ImageIO`
/// encoding, no third-party dependency. The original file is never touched or replaced; it stays
/// in the user's own photo library exactly as captured.
enum PhotoAttachment {
    /// JPEG quality for the on-device re-encode. High enough that a real photo still looks like a
    /// photo, but never `1.0` -- some compression keeps typical camera captures comfortably under
    /// `internal/httpapi.maxPhotoUploadBytes` (9 MiB, 04.1-04-SUMMARY.md), which the downscale step
    /// below reinforces for the camera's largest capture sizes.
    private static let jpegCompressionQuality: CGFloat = 0.85

    /// A real capture easily exceeds this on its longest side; downscaling before encode is what
    /// keeps a full-resolution photo well under the server's byte cap, not just the compression
    /// quality alone. `RithamType`'s own display use of a shared/photo image never needs more than
    /// this for a feed card or a certificate.
    private static let maxDimensionPixels: CGFloat = 2048

    /// The testable core: decodes `data` (any format `UIImage(data:)` can decode -- JPEG, PNG,
    /// HEIC, and anything else ImageIO on this platform supports) and re-encodes it as JPEG.
    /// Called by both overloads below, so exactly one code path ever produces the bytes this
    /// feature uploads -- an already-JPEG input is still routed through this same re-encode, so
    /// the server never sees two different "the client says this is already fine" shapes.
    static func encodableJPEG(from data: Data) throws -> Data {
        guard let image = UIImage(data: data) else {
            throw PhotoAttachmentError.unreadable
        }
        let resized = resized(image, maxDimension: maxDimensionPixels)
        guard let jpegData = resized.jpegData(compressionQuality: jpegCompressionQuality) else {
            throw PhotoAttachmentError.unreadable
        }
        return jpegData
    }

    /// The `PhotosPicker` overload: loads the picked item's raw bytes, then defers to the
    /// `Data`-based core above. `PhotosPickerItem` cannot be constructed outside a real picker
    /// interaction, so this overload itself has no dedicated unit test -- `CompletionLoggingTests`
    /// exercises the shared core directly with synthetic fixture data instead.
    static func encodableJPEG(from item: PhotosPickerItem) async throws -> Data {
        guard let data = try await item.loadTransferable(type: Data.self) else {
            throw PhotoAttachmentError.unreadable
        }
        return try encodableJPEG(from: data)
    }

    /// Uploads already-transcoded JPEG bytes through the shared social client's multipart method
    /// (`SocialAPIClient.upload`, declared for exactly this purpose) and wraps the server's
    /// response in the one accessible way to produce a `StrippedPhotoAsset`. A failed upload
    /// throws -- there is no partial or placeholder asset value this function can return, so a
    /// caller catching the error has nothing to attach to a draft.
    static func upload(_ data: Data, via client: SocialAPIClient) async throws -> StrippedPhotoAsset {
        let response = try await client.upload("v1/photos", fieldName: "photo", filename: "photo.jpg", contentType: "image/jpeg", data: data)
        return try StrippedPhotoAsset(uploadResponse: response)
    }

    private static func resized(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let largestSide = max(size.width, size.height)
        guard largestSide > maxDimension, largestSide > 0 else { return image }
        let scale = maxDimension / largestSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
