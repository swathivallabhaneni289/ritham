import CoreLocation
import Foundation
import SwiftData

// On-device-only persisted form of a `PrivacyZone` (Social/PrivacyZones/PrivacyZone.swift).
//
// 04.1-RESEARCH.md Pattern 3 is explicit that Privacy Zone definitions -- including a user's home
// address -- must live on-device only; there is no reason for Ritham's backend to ever see one.
// This record is registered in `RithamModelContainer`'s schema alongside `UserProfile` and every
// other model this app persists, so it shares that container's file protection (a home address is
// precisely the data that protection exists for) without needing a second store or a second
// protected file to manage.
//
// Deliberately carries no user identifier and no event or completion reference of any kind -- a
// zone belongs to the device, never to any shared object, matching `PrivacyZoneTests`'s own
// reflection check for this record.
//
// `effect` follows `UserProfile`'s exact shape for a raw-value-backed enum column: stored as an
// optional `String`, decoded through a nil-safe computed accessor that never force-unwraps, so a
// future case rename or an otherwise-corrupted raw value reads back as `nil` rather than crashing
// the app on old local data.
//
// `public`, matching every sibling `@Model` type in this persistence layer
// (`UserProfile`/`ConditionTagRecord`/`CardioSessionRecord`, etc.).
@Model
public final class PrivacyZoneRecord {
    public var id: UUID
    public var label: String
    public var latitude: Double
    public var longitude: Double
    public var radiusMetres: Double
    public var effectRaw: String?

    public init(
        id: UUID = UUID(),
        label: String,
        latitude: Double,
        longitude: Double,
        radiusMetres: Double,
        effectRaw: String?
    ) {
        self.id = id
        self.label = label
        self.latitude = latitude
        self.longitude = longitude
        self.radiusMetres = radiusMetres
        self.effectRaw = effectRaw
    }

    /// `nil` when unset or when the stored raw value no longer matches a known
    /// `PrivacyZoneEffect` case (T-01-64's pattern, applied here).
    public var effect: PrivacyZoneEffect? {
        guard let effectRaw else { return nil }
        return PrivacyZoneEffect(rawValue: effectRaw)
    }
}

extension PrivacyZoneRecord {
    /// Converts this record to the domain `PrivacyZone` value `HealthDataStore.loadPrivacyZones()`
    /// returns. Unlike most of this file's other records, an unrecognised `effectRaw` does not
    /// drop the zone from the loaded list (the "compactMap away a record that no longer decodes"
    /// pattern `CardioSessionRecord`/`LiftSetRecord` use elsewhere in this file) -- silently
    /// dropping a Privacy Zone would silently stop protecting the location it was created to
    /// protect, which is a worse failure than the zone reading back with the stricter of its two
    /// effects. `.suppress` is used here as that fail-closed default: it is the effect that leaks
    /// the least, never `.generalize`.
    public var zone: PrivacyZone {
        PrivacyZone(
            id: id,
            label: label,
            centre: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            radiusMetres: radiusMetres,
            effect: effect ?? .suppress
        )
    }
}
