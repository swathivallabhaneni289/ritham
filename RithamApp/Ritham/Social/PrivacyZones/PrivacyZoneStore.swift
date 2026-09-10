import CoreLocation
import SwiftUI

/// Thin, on-device-only facade over `HealthDataStore`'s Privacy Zone accessors
/// (`HealthDataStore.swift`'s `MARK: - Privacy Zones` section), following `CardioHistoryModel`'s
/// "an `@Observable` model wraps the store" shape. `PrivacyZonesView` and `AddPrivacyZoneView`
/// read and mutate zones only through this type, never through `HealthDataStore` directly -- the
/// same isolation `CardioHistoryModel` gives `CardioHistoryView` from its own store accessors.
///
/// `zones` starts empty and is populated only by an explicit `load()` call (never eagerly in
/// `init`), matching `CardioHistoryModel.load()`'s own deferred-load shape -- `PrivacyZonesView`
/// calls this from `.onAppear`, the same trigger `CardioHistoryView` uses, so a view built via
/// `StepRegistry.view(for:flow:)` with no store context yet can still be constructed safely.
@MainActor
@Observable
final class PrivacyZoneStore {
    private(set) var zones: [PrivacyZone] = []

    private let store: HealthDataStore

    init(store: HealthDataStore) {
        self.store = store
    }

    /// Reloads every stored zone. Failure reads back as an empty list rather than throwing --
    /// matching `CardioHistoryModel.load()`'s own `(try? ...) ?? []` discipline -- since this is a
    /// Settings list, not a screen any correctness guarantee depends on.
    func load() {
        zones = (try? store.loadPrivacyZones()) ?? []
    }

    /// Adds a new zone and reloads. Returns `false` on a persistence failure, leaving `zones`
    /// unchanged from the last successful `load()`.
    @discardableResult
    func add(label: String, centre: CLLocationCoordinate2D, radiusMetres: Double, effect: PrivacyZoneEffect) -> Bool {
        let zone = PrivacyZone(label: label, centre: centre, radiusMetres: radiusMetres, effect: effect)
        do {
            try store.savePrivacyZone(zone)
            load()
            return true
        } catch {
            return false
        }
    }

    /// Removes a stored zone and reloads. A no-op (besides a reload) when `id` no longer matches
    /// any stored zone.
    func remove(id: UUID) {
        try? store.deletePrivacyZone(id: id)
        load()
    }

    /// Renames a stored zone's own user-given label and reloads. A no-op (besides a reload) when
    /// `id` no longer matches any stored zone.
    func rename(id: UUID, to label: String) {
        try? store.renamePrivacyZone(id: id, to: label)
        load()
    }
}
