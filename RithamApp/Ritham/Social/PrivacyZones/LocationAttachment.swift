import CoreLocation
import Foundation

// GROUPEVENTS-03 / 04.1-RESEARCH.md Pattern 3, Pitfall 3: the capture-zone-check-geocode-discard
// sequence lives here as ONE function, in this ONE file, so the zone check's ordering relative to
// the geocode call is a property of this file's own control flow -- proven by
// `PrivacyZoneTests`'s zero-call-count assertions -- rather than a convention two separately
// planned features have to agree on and could silently drift apart from. Plan 04.1-14 only calls
// `LocationAttachment.resolveSharedPlaceName` -- it contains no zone-check or geocoding logic of
// its own.
enum LocationAttachment {

    /// Implements Pattern 3's five steps, in this exact order:
    /// 1. `fix` arrives already captured -- a transient, in-memory-only coordinate. This function
    ///    never touches `CLLocationManager` itself; it only ever receives what a caller already
    ///    captured.
    /// 2. Evaluate `fix` against every zone in `zones`, before `geocoder` is ever asked to do
    ///    anything.
    /// 3. If any containing zone's effect is `.suppress`, return `.suppressedByZone`
    ///    immediately -- `geocoder` is never invoked. When a coordinate falls inside more than one
    ///    zone with different effects, suppress always wins: the more protective effect governs
    ///    (`docs/group-events.md` §3).
    /// 4. Otherwise, if any containing zone's effect is `.generalize`, return
    ///    `.generalizedByZone(label)` immediately, carrying that zone's own user-given label --
    ///    never a geocoder result -- and again without ever invoking `geocoder`.
    /// 5. Only when `fix` falls inside no zone at all does `geocoder` run. Its result becomes
    ///    `.place(name)`, or `.none` on any failure, timeout, or nil result -- never a retry with a
    ///    wider or less specific request, and never a fallback to any numeric representation of
    ///    the position.
    ///
    /// `fix` never survives past this call: it is never assigned to a stored property, never
    /// passed to a persistence type, and never present in the returned `SharedLocationOutcome` --
    /// none of that type's cases can carry a coordinate, a radius, or a distance figure. Once this
    /// function returns, `fix` has gone out of scope.
    static func resolveSharedPlaceName(
        fix: CLLocationCoordinate2D?,
        zones: [PrivacyZone],
        geocoder: PlaceNameResolving
    ) async -> SharedLocationOutcome {
        guard let fix else { return .none }

        let containingZones = zones.filter { $0.contains(fix) }

        if containingZones.contains(where: { $0.effect == .suppress }) {
            return .suppressedByZone
        }
        if let generalizingZone = containingZones.first(where: { $0.effect == .generalize }) {
            return .generalizedByZone(generalizingZone.label)
        }

        guard let name = await geocoder.placeName(for: fix) else { return .none }
        return .place(name)
    }
}

/// The seam `resolveSharedPlaceName` calls through, so `PrivacyZoneTests` can substitute a
/// call-counting spy in place of `SystemGeocoder` -- the zero-call assertions on a zone match are
/// only provable against a real invocation count, not a convention.
protocol PlaceNameResolving: Sendable {
    /// Returns a coarse place name for `coordinate`, or `nil` on any failure -- never throws,
    /// since every caller's only correct response to a failure is "no location," and an error
    /// type would just be discarded at every call site anyway.
    func placeName(for coordinate: CLLocationCoordinate2D) async -> String?
}

/// The only place in this codebase that constructs or calls `CLGeocoder` -- a repository-wide
/// grep for `CLGeocoder` outside this file must return no hit (`PrivacyZoneTests`/this plan's own
/// `<verification>` block).
///
/// Processor-disclosure note for Phase 5 (LAUNCH-04), per 04.1-RESEARCH.md Pattern 3: this is
/// NOT on-device processing. `reverseGeocodeLocation` sends `coordinate` to Apple's own geocoding
/// servers and returns a `CLPlacemark` from them -- Ritham's own backend never receives the
/// coordinate, but Apple does, making Apple a third-party processor of that transient,
/// immediately-discarded value. Flag this explicitly in Phase 5's GDPR/CCPA review; "on-device"
/// does not cover this call by itself.
struct SystemGeocoder: PlaceNameResolving {
    func placeName(for coordinate: CLLocationCoordinate2D) async -> String? {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        guard let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first else {
            return nil
        }

        // Hard field allowlist, in this preference order: an area of interest, then the
        // sub-locality, then the locality, then the administrative area. Every finer-grained,
        // street-level placemark field is excluded by construction -- not merely unused --
        // because a street-level result carries exactly the kind of precision this feature exists
        // to never expose.
        return [placemark.areasOfInterest?.first, placemark.subLocality, placemark.locality, placemark.administrativeArea]
            .compactMap { $0 }
            .first
    }
}

/// What, if anything, leaves this function about a shared location. No case here has any
/// associated value capable of carrying a coordinate, a radius, or a distance figure --
/// `PrivacyZoneTests` asserts this exhaustively by switching over every case.
enum SharedLocationOutcome: Equatable {
    /// No fix was available, or the geocoder failed/returned nothing/timed out.
    case none
    /// The fix fell inside a zone whose effect is `.suppress`. Nothing about the location is
    /// shared, not even a zone label.
    case suppressedByZone
    /// The fix fell inside a zone whose effect is `.generalize`. Carries that zone's own
    /// user-given label -- never a geocoder result.
    case generalizedByZone(String)
    /// The fix fell inside no zone. Carries the geocoder's resolved coarse place name.
    case place(String)
}
