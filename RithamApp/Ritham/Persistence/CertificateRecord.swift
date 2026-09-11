import Foundation
import SwiftData
import RithamCore

/// GROUPEVENTS-05: one certificate per completion, generated automatically on a successful log
/// (`CompletionLoggingView`'s own `.logged` stage, plan 04.1-16) and accumulated here as the
/// person's own, private, unranked archive -- never a shared or group-visible record of any kind.
///
/// Carries exactly the fields `CertificateContent` (`Social/Certificate/CertificateContent.swift`)
/// needs to be rebuilt later: it holds no other member's data, and no image bytes of any kind --
/// the certificate image is recomposed from these fields on demand every time it is shown, so
/// nothing rendered is cached in a form that could outlive a later rule change. `photoAssetID`
/// alone (no shared URL, no bytes) is stored for a photo-bearing certificate; the shared URL is
/// re-resolved from the server by asset id at render time (`CertificateRecord.content(apiClient:)`
/// below), the same "server is the source of truth for where a photo actually lives" precedent
/// `StrippedPhotoAsset` itself already establishes.
///
/// Registered in `RithamModelContainer`'s schema (not this file), matching `PrivacyZoneRecord`'s
/// own precedent for where a Phase 4.1 model actually lives -- `HealthDataStore.swift` gets this
/// record's CRUD accessors instead, following every other model's registration split in this
/// persistence layer.
@Model
public final class CertificateRecord {
    public var id: UUID
    public var completionID: UUID
    public var eventName: String
    public var activityTypeRaw: String?
    public var participantName: String
    public var completionDate: Date
    public var ownTimeSeconds: Int?
    public var photoAssetID: UUID?

    public init(
        id: UUID = UUID(),
        completionID: UUID,
        eventName: String,
        activityTypeRaw: String?,
        participantName: String,
        completionDate: Date,
        ownTimeSeconds: Int?,
        photoAssetID: UUID?
    ) {
        self.id = id
        self.completionID = completionID
        self.eventName = eventName
        self.activityTypeRaw = activityTypeRaw
        self.participantName = participantName
        self.completionDate = completionDate
        self.ownTimeSeconds = ownTimeSeconds
        self.photoAssetID = photoAssetID
    }

    /// `nil` when unset or when the stored raw value no longer matches a known activity -- in
    /// practice `ActivityType`'s own `RawRepresentable` initializer never fails, so this is only
    /// ever `nil` for a record whose `activityTypeRaw` itself is `nil` (T-01-64's nil-safe-accessor
    /// pattern, applied here for consistency with every other raw-value-backed column in this
    /// persistence layer).
    public var activityType: ActivityType? {
        guard let activityTypeRaw else { return nil }
        return ActivityType(rawValue: activityTypeRaw)
    }
}

extension CertificateRecord {
    /// Rebuilds this record's renderable `CertificateContent`. When `photoAssetID` is set, this
    /// re-resolves the photo's shared URL from the server (`GET /v1/photos/{id}`, the same route
    /// `PhotoUploadResponse`'s own header comment names as this plan's eventual consumer) rather
    /// than reading a URL this record never stores -- a failed or unreachable fetch renders the
    /// certificate with its branded default frame (no photo) rather than failing the whole card.
    /// `placeName` is always `nil` here: this record carries no place field of its own, matching
    /// this file's own closed persisted-field list.
    @MainActor
    func content(apiClient: SocialAPIClient = SocialAPIClient(sessionStore: SessionStore())) async -> CertificateContent {
        var photo: StrippedPhotoAsset?
        if let photoAssetID {
            if let response: PhotoUploadResponse = try? await apiClient.get("v1/photos/\(photoAssetID.uuidString)") {
                photo = try? StrippedPhotoAsset(uploadResponse: response)
            }
        }
        return CertificateContent(
            eventDisplayName: eventName,
            activityType: activityType ?? .run,
            participantName: participantName,
            completionDate: completionDate,
            ownTimeSeconds: ownTimeSeconds,
            placeName: nil,
            photo: photo
        )
    }
}
