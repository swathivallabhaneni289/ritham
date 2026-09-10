import CoreLocation
import Foundation

// GROUPEVENTS-03 / 04.1-RESEARCH.md Pattern 3: a Privacy Zone is an on-device-only area a user
// draws around a place (home, workplace) that a shared location must never reveal. `PrivacyZone`
// itself is a pure value type -- it holds no reference to any persisted record, any shared
// object, or the network layer, matching `PrivacyZoneRecord`'s own "belongs to the device, not to
// any shared object" discipline one layer down.
//
// `CLLocationCoordinate2D` does not conform to `Sendable` under this project's
// `SWIFT_STRICT_CONCURRENCY: complete` setting, so the coordinate is stored as two plain `Double`
// columns (`latitude`/`longitude`) -- exactly mirroring `PrivacyZoneRecord`'s own stored shape --
// with `centre` as a computed convenience for call sites that want the `CLLocationCoordinate2D`
// form (`contains(_:)`, the map picker).
//
// `public` throughout, matching `HealthDataStore.swift`'s own file-wide convention (its
// `loadPrivacyZones`/`savePrivacyZone` accessors return/accept this type, so it must be at least
// as visible as they are).
public struct PrivacyZone: Identifiable, Sendable, Equatable {
    public let id: UUID
    public var label: String
    public var latitude: Double
    public var longitude: Double

    /// `docs/group-events.md` §3's standing rule: the radius is an internal evaluation input
    /// only. It is never displayed anywhere in the UI, never returned from any accessor beyond
    /// this type's own storage, and never sent to the backend -- an exposed radius is a boundary
    /// an observer could correlate against across multiple shared activities (the same reasoning
    /// `docs/group-events.md` §3 applies to a displayed numeric distance). `PrivacyZonesView`'s
    /// own acceptance check greps for the absence of any radius rendering in that file.
    public var radiusMetres: Double

    public var effect: PrivacyZoneEffect

    public var centre: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    public init(id: UUID = UUID(), label: String, centre: CLLocationCoordinate2D, radiusMetres: Double, effect: PrivacyZoneEffect) {
        self.id = id
        self.label = label
        self.latitude = centre.latitude
        self.longitude = centre.longitude
        self.radiusMetres = radiusMetres
        self.effect = effect
    }

    /// True when `coordinate` falls within `radiusMetres` of this zone's centre, inclusive of the
    /// boundary itself. Computed via `CLLocation.distance(from:)` -- a great-circle (geodesic)
    /// distance -- rather than naive degree subtraction on latitude/longitude, so a zone near a
    /// pole (where a degree of longitude spans a vanishingly small real distance) or straddling
    /// the antimeridian (where +179.9 and -179.9 degrees longitude are physically adjacent, not
    /// ~360 degrees apart) never produces a false negative.
    public func contains(_ coordinate: CLLocationCoordinate2D) -> Bool {
        let zoneLocation = CLLocation(latitude: latitude, longitude: longitude)
        let candidateLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return zoneLocation.distance(from: candidateLocation) <= radiusMetres
    }
}

/// What a matching zone does to a location before it would otherwise be shared. Two rungs only --
/// there is no third "show but blur" option, per `docs/group-events.md` §3's "a coarse named
/// place, never a pin, address, or numeric radius" rule: a zone either substitutes its own label
/// or removes the location entirely, and nothing in between leaks a hint of precision.
public enum PrivacyZoneEffect: String, CaseIterable, Sendable, Codable, Equatable {
    /// Replace the resolved location with this zone's own `label` -- e.g. "Home" -- never the
    /// underlying place name a geocoder would otherwise have returned.
    case generalize
    /// Omit the location entirely. No place name, no zone label, nothing.
    case suppress
}
