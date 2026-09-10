import CoreLocation
import Foundation
import SwiftData
import Testing
@testable import Ritham

// Nested under `MomentumContainerTouchingSuites` (`MomentumSuiteSerialization.swift`'s own doc
// comment: "every new container-creating suite this phase adds nests under this parent") so this
// suite's in-memory `ModelContainer` construction is ordered relative to every other
// container-touching suite during a full-target run, rather than risking the pre-existing
// cross-suite `ModelContainer` concurrency flake `STATE.md` records.
extension MomentumContainerTouchingSuites {

@MainActor
@Suite("PrivacyZoneTests", .serialized)
struct PrivacyZoneTests {

    // MARK: - Task 1 helpers

    /// Builds an in-memory container over the full `RithamModelContainer` model list -- the
    /// production schema, not a hand-picked subset -- so `PrivacyZoneRecord` missing from that
    /// list would fail here at first fetch, exactly as `MomentumStoreTests.makeStore()` already
    /// does for its own models.
    private func makeStore() throws -> (store: HealthDataStore, container: ModelContainer) {
        let container = try RithamModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        return (HealthDataStore(context: context), container)
    }

    /// A second `HealthDataStore` over the *same* in-memory container but a fresh `ModelContext`
    /// -- proves a value round-trips through actual persistence rather than merely surviving in
    /// the first context's live object graph.
    private func reopenStore(_ container: ModelContainer) -> HealthDataStore {
        HealthDataStore(context: ModelContext(container))
    }

    private func meters(_ metres: Double, asLatitudeDegreesFrom latitude: Double) -> Double {
        // ~111,320 metres per degree of latitude, accurate enough for the wide (10%+) margins
        // every boundary test below uses -- these tests are not asserting WGS84 precision, only
        // that `PrivacyZone.contains` computes a real geodesic distance rather than naive degree
        // subtraction.
        latitude + (metres / 111_320)
    }

    // MARK: - Containment: centre, just inside, just outside

    @Test("a coordinate at the zone centre is inside")
    func coordinateAtCentreIsInside() {
        let centre = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let zone = PrivacyZone(label: "Home", centre: centre, radiusMetres: 50, effect: .suppress)
        #expect(zone.contains(centre))
    }

    @Test("a coordinate clearly inside the radius is inside")
    func coordinateClearlyInsideRadiusIsInside() {
        let centre = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let zone = PrivacyZone(label: "Home", centre: centre, radiusMetres: 200, effect: .suppress)
        let insideLatitude = meters(180, asLatitudeDegreesFrom: centre.latitude)
        let insidePoint = CLLocationCoordinate2D(latitude: insideLatitude, longitude: centre.longitude)
        #expect(zone.contains(insidePoint))
    }

    @Test("a coordinate clearly outside the radius is outside")
    func coordinateClearlyOutsideRadiusIsOutside() {
        let centre = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let zone = PrivacyZone(label: "Home", centre: centre, radiusMetres: 200, effect: .suppress)
        let outsideLatitude = meters(260, asLatitudeDegreesFrom: centre.latitude)
        let outsidePoint = CLLocationCoordinate2D(latitude: outsideLatitude, longitude: centre.longitude)
        #expect(!zone.contains(outsidePoint))
    }

    // MARK: - Great-circle distance, not naive degree subtraction

    @Test("a zone at the pole does not produce a false negative from naive longitude-degree subtraction")
    func poleZoneAvoidsFalseNegative() {
        // The zone's centre IS the pole; the candidate is ~111m from the pole at the opposite
        // longitude. A naive implementation that weighs raw longitude-degree difference (180
        // degrees here) as if it were comparable to a latitude-degree difference would report
        // this candidate as enormously far away. The true geodesic distance is ~111m.
        let pole = CLLocationCoordinate2D(latitude: 90, longitude: 0)
        let zone = PrivacyZone(label: "Pole zone", centre: pole, radiusMetres: 1000, effect: .suppress)
        let nearPoleOppositeLongitude = CLLocationCoordinate2D(latitude: 89.999, longitude: 180)
        #expect(zone.contains(nearPoleOppositeLongitude))
    }

    @Test("a zone straddling the antimeridian does not produce a false negative from naive longitude-degree subtraction")
    func antimeridianZoneAvoidsFalseNegative() {
        // +179.999 and -179.999 degrees longitude are physically ~220m apart at the equator, not
        // ~360 degrees apart. A naive `abs(lon1 - lon2)` without antimeridian wrapping would
        // compute ~359.998 and report this candidate as outside any small zone.
        let centre = CLLocationCoordinate2D(latitude: 0, longitude: 179.999)
        let zone = PrivacyZone(label: "Antimeridian zone", centre: centre, radiusMetres: 500, effect: .suppress)
        let acrossTheLine = CLLocationCoordinate2D(latitude: 0, longitude: -179.999)
        #expect(zone.contains(acrossTheLine))
    }

    // MARK: - Suppress vs. generalize distinguishable after a store round trip

    @Test("a suppress zone and a generalize zone are distinguishable after a store round trip")
    func suppressAndGeneralizeZonesRoundTripDistinctly() throws {
        let (store, container) = try makeStore()
        let suppressZone = PrivacyZone(
            label: "Home", centre: CLLocationCoordinate2D(latitude: 1, longitude: 1),
            radiusMetres: 100, effect: .suppress
        )
        let generalizeZone = PrivacyZone(
            label: "Workplace", centre: CLLocationCoordinate2D(latitude: 2, longitude: 2),
            radiusMetres: 100, effect: .generalize
        )
        try store.savePrivacyZone(suppressZone)
        try store.savePrivacyZone(generalizeZone)

        let reopened = reopenStore(container)
        let loaded = try reopened.loadPrivacyZones()

        #expect(loaded.first { $0.id == suppressZone.id }?.effect == .suppress)
        #expect(loaded.first { $0.id == generalizeZone.id }?.effect == .generalize)
    }

    // MARK: - Unknown persisted raw value reads back as nil

    @Test("an unrecognised persisted effect raw value reads back as nil rather than crashing")
    func unrecognisedEffectRawValueReadsBackAsNil() {
        let record = PrivacyZoneRecord(
            label: "Home", latitude: 1, longitude: 1, radiusMetres: 100, effectRaw: "not-a-real-case"
        )
        #expect(record.effect == nil)
    }

    @Test("a nil persisted effect raw value reads back as nil")
    func nilEffectRawValueReadsBackAsNil() {
        let record = PrivacyZoneRecord(label: "Home", latitude: 1, longitude: 1, radiusMetres: 100, effectRaw: nil)
        #expect(record.effect == nil)
    }

    // MARK: - Add, rename, remove survive a store reload

    @Test("adding, renaming, and removing a zone survives a store reload")
    func addRenameRemoveSurviveStoreReload() throws {
        let (store, container) = try makeStore()
        let zoneStore = PrivacyZoneStore(store: store)
        zoneStore.load()
        #expect(zoneStore.zones.isEmpty)

        let centre = CLLocationCoordinate2D(latitude: 5, longitude: 5)
        #expect(zoneStore.add(label: "Home", centre: centre, radiusMetres: 100, effect: .suppress))

        // Reload through a brand-new store/context pair over the same underlying container --
        // this is what proves the add actually persisted rather than merely living in
        // `zoneStore`'s own in-memory `zones` array.
        let afterAdd = PrivacyZoneStore(store: reopenStore(container))
        afterAdd.load()
        #expect(afterAdd.zones.count == 1)
        let addedID = try #require(afterAdd.zones.first?.id)
        #expect(afterAdd.zones.first?.label == "Home")

        afterAdd.rename(id: addedID, to: "House")
        let afterRename = PrivacyZoneStore(store: reopenStore(container))
        afterRename.load()
        #expect(afterRename.zones.first?.label == "House")

        afterRename.remove(id: addedID)
        let afterRemove = PrivacyZoneStore(store: reopenStore(container))
        afterRemove.load()
        #expect(afterRemove.zones.isEmpty)
    }

    // MARK: - No user, event, or completion identifier field (T-04.1-37's neighbouring guarantee)

    @Test("PrivacyZoneRecord declares no user, event, or completion identifier field")
    func recordDeclaresNoForeignIdentifierField() {
        let record = PrivacyZoneRecord(
            label: "Home", latitude: 1, longitude: 1, radiusMetres: 100,
            effectRaw: PrivacyZoneEffect.suppress.rawValue
        )
        let labels = Mirror(reflecting: record).children.compactMap(\.label)

        // Positive control (`PersistenceTests.userProfileHasNoIndividualEatingDisorderAnswerProperty`'s
        // own precedent): confirm Mirror actually sees this record's own stored properties before
        // trusting the negative assertion below.
        let sawKnownStoredProperty = labels.contains { $0.lowercased().contains("label") || $0.lowercased().contains("radiusmetres") }
        #expect(sawKnownStoredProperty, "Mirror did not see PrivacyZoneRecord's own stored properties -- this test's negative assertion below cannot be trusted until it does")

        let forbiddenSubstrings = ["userid", "eventid", "completionid", "groupid", "memberid"]
        let sawForbiddenField = labels.contains { label in
            forbiddenSubstrings.contains { label.lowercased().contains($0) }
        }
        #expect(!sawForbiddenField, "PrivacyZoneRecord must belong to the device, never to a user/event/group/completion")
    }
}

}
