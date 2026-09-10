import Foundation

/// Every failure mode `PhotoAttachment.swift`'s transcode/upload pipeline (Task 2) and this
/// type's own upload-response initializer can raise. Declared here, alongside `StrippedPhotoAsset`
/// rather than in `PhotoAttachment.swift`, because `invalidUploadResponse` is this type's own
/// failure mode and Task 1 needs it to compile before Task 2's file exists (see this file's header
/// comment on the forward-dependency break).
enum PhotoAttachmentError: Error, Equatable {
    /// A picked item could not be read or decoded as an image at all.
    case unreadable
    /// The server's `PhotoUploadResponse` did not contain a well-formed asset id or shared URL.
    case invalidUploadResponse
}

/// The opaque, server-backed photo reference the certificate composer (plan 04.1-16) is later
/// restricted to. 04.1-RESEARCH.md Pattern 4 and Pitfall 5 describe a leak where a certificate
/// composites the client's local original instead of the server-stripped copy -- that guarantee
/// only holds if the composing code has no addressable reference to the original at all. Making
/// the only obtainable photo reference one that can be produced solely from a server upload
/// response is what makes that bypass unreachable rather than merely discouraged.
///
/// The memberwise initializer is `private`; the only accessible initializer takes
/// `PhotoUploadResponse` (`SocialAPIClient.swift`), the server's own `POST /v1/photos` reply. This
/// is a genuine, load-bearing forward-dependency break from `04.1-14-PLAN.md`'s own stated Task
/// boundaries: `CompletionDraft` (Task 1) declares a `photo: StrippedPhotoAsset?` field per this
/// plan's `<artifacts_produced>`, so this type must exist before Task 1 compiles even though the
/// plan's own file list places it under Task 2. Built here, in full, during Task 1 -- mirroring
/// plan 02-03's own documented precedent for breaking an identical forward-dependency
/// (`SupersetGroupID` created early, in Task 1 rather than Task 2). Task 2 adds `PhotoAttachment`
/// (the transcode/upload pipeline that actually produces a `PhotoUploadResponse`) and this type's
/// own dedicated behavior tests.
struct StrippedPhotoAsset: Equatable, Sendable {
    let assetID: UUID
    let sharedURL: URL

    private init(assetID: UUID, sharedURL: URL) {
        self.assetID = assetID
        self.sharedURL = sharedURL
    }

    /// The one accessible initializer. `PhotoUploadResponse`'s two fields are wire strings
    /// (`photoAssetId`/`sharedUrl`); a malformed value from the server (not something a client
    /// could ever construct itself) throws `PhotoAttachmentError.invalidUploadResponse` rather
    /// than producing a half-valid asset.
    init(uploadResponse: PhotoUploadResponse) throws {
        guard
            let assetID = UUID(uuidString: uploadResponse.photoAssetID),
            let sharedURL = URL(string: uploadResponse.sharedURL)
        else {
            throw PhotoAttachmentError.invalidUploadResponse
        }
        self.init(assetID: assetID, sharedURL: sharedURL)
    }
}
