import CoreLocation
import Foundation
import SwiftUI
import RithamCore

// D-02's other half: measured via GPS/motion sensors when the user grants location access, with
// GPS layered on as enrichment per 01-RESEARCH.md Assumption A1. This type reads
// CLLocationManager's current authorization status and starts location updates ONLY when that
// status is already .authorizedWhenInUse or .authorizedAlways. When the status is
// .notDetermined, .denied, or .restricted it stays inert and publishes nothing -- no location
// manager is started, no property changes.
//
// This type must never call requestWhenInUseAuthorization or requestAlwaysAuthorization -- doing
// either here would breach D-02's no-blocking-prompt rule. This is the distinction that makes
// D-02 satisfiable in both directions: a user who already granted location for some other
// reason gets more precise pace and distance, and a user who has not is never prompted and
// never blocked.
//
// This type contributes display precision only -- CalibrationCompletion.evaluate (RithamCore)
// decides completion from CalibrationProgress alone, so a GPS dropout or a denied permission can
// never prevent a session from completing. This type never gates anything.
@MainActor
@Observable
final class LocationEnrichment: NSObject, @unchecked Sendable {
    private(set) var isEnriching = false
    private(set) var enrichedPaceSecondsPerKm: Double?
    private(set) var enrichedDistanceMeters: Double?

    private let authorizationStatusProvider: () -> CLAuthorizationStatus
    private let makeLocationManager: () -> CLLocationManager
    // `@ObservationIgnored` -- the underlying `CLLocationManager` is an implementation detail no
    // view ever reads directly, and `@Observable`'s tracking macro cannot be applied to a `lazy`
    // property regardless.
    @ObservationIgnored
    private lazy var locationManager: CLLocationManager = {
        let manager = makeLocationManager()
        manager.delegate = self
        return manager
    }()

    private var startedAt: Date?
    private var lastLocation: CLLocation?
    private let now: () -> Date

    init(
        authorizationStatusProvider: @escaping () -> CLAuthorizationStatus = { CLLocationManager().authorizationStatus },
        makeLocationManager: @escaping () -> CLLocationManager = CLLocationManager.init,
        now: @escaping () -> Date = Date.init
    ) {
        self.authorizationStatusProvider = authorizationStatusProvider
        self.makeLocationManager = makeLocationManager
        self.now = now
        super.init()
    }

    /// Evaluates the current authorization status and starts enriching only when access was
    /// already granted -- never requests it. Safe to call repeatedly (e.g. each time the
    /// session screen appears).
    func startIfAlreadyAuthorized() {
        switch authorizationStatusProvider() {
        case .authorizedWhenInUse, .authorizedAlways:
            guard !isEnriching else { return }
            isEnriching = true
            startedAt = now()
            locationManager.startUpdatingLocation()
        case .notDetermined, .denied, .restricted:
            isEnriching = false
        @unknown default:
            isEnriching = false
        }
    }

    func stop() {
        locationManager.stopUpdatingLocation()
        isEnriching = false
        startedAt = nil
        lastLocation = nil
    }

    fileprivate func handleUpdate(_ locations: [CLLocation]) {
        guard let newest = locations.last, let startedAt else { return }
        if let lastLocation {
            enrichedDistanceMeters = (enrichedDistanceMeters ?? 0) + newest.distance(from: lastLocation)
        }
        lastLocation = newest
        if let distance = enrichedDistanceMeters, distance > 0 {
            let elapsed = now().timeIntervalSince(startedAt)
            enrichedPaceSecondsPerKm = elapsed / (distance / 1000)
        }
    }
}

extension LocationEnrichment: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            handleUpdate(locations)
        }
    }
}
