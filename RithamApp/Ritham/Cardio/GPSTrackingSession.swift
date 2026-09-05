import CoreLocation
import Foundation
import SwiftUI
import RithamCore

// Inversion notice: `LocationEnrichment.swift`'s rule forbidding both of CLLocationManager's
// authorization-request methods is scoped to *calibration's* D-02 no-blocking-prompt decision --
// it does not generalize to Phase 2. Here GPS is the feature CARDIO-02 asks for: the user
// explicitly starts a GPS-tracked cardio session, so requesting when-in-use authorization at
// session start is expected and correct. A future reader must not assume the old calibration
// rule still governs this file. What preserves PROJECT.md's phone-only promise is that
// `StopwatchCardioSession` never depends on a permission decision -- not a blanket ban on ever
// prompting.
//
// Copies `LocationEnrichment`'s `CLLocationManager` wrapper structure (delegate pattern,
// accuracy-threshold handling), but every filtering/distance/elevation/split computation is
// delegated to RithamCore's `CardioTrackAccumulator` (plan 02-01, unit-tested) -- this type maps
// each `CLLocation` into a `LocationSample` and feeds it; it performs no arithmetic of its own.
//
// 02-RESEARCH.md Pitfall 4: background location updates stay disabled and always-authorization
// is never requested -- both are tied to battery drain and App Store review pushback, and
// nothing in CARDIO-02's success criteria needs either. The only call that starts location
// updates lives in `start()`, with a matching stop in `stop()` and `pause()`, so no update
// stream can outlive a session.
@MainActor
@Observable
final class GPSTrackingSession: NSObject, @unchecked Sendable {
    let activityType: ActivityType

    private(set) var authorizationStatus: CLAuthorizationStatus
    private(set) var progress: CardioProgress = CardioProgress()

    /// Contract for the view layer: a denied or restricted authorization status must fall back
    /// to `StopwatchCardioSession` rather than blocking the session. This type never presents an
    /// alert or navigates anywhere itself -- that belongs to plan 02-10's view.
    var requiresManualFallback: Bool {
        switch authorizationStatus {
        case .denied, .restricted:
            return true
        default:
            return false
        }
    }

    private var accumulator = CardioTrackAccumulator()
    private var sessionStartedAt: Date?

    private let authorizationStatusProvider: () -> CLAuthorizationStatus
    private let makeLocationManager: () -> CLLocationManager
    // `@ObservationIgnored` -- the underlying `CLLocationManager` is an implementation detail no
    // view ever reads directly, and `@Observable`'s tracking macro cannot be applied to a `lazy`
    // property regardless.
    @ObservationIgnored
    private lazy var locationManager: CLLocationManager = {
        let manager = makeLocationManager()
        manager.delegate = self
        manager.activityType = .fitness
        manager.pausesLocationUpdatesAutomatically = true
        return manager
    }()

    private let now: () -> Date

    init(
        activityType: ActivityType,
        authorizationStatusProvider: @escaping () -> CLAuthorizationStatus = { CLLocationManager().authorizationStatus },
        makeLocationManager: @escaping () -> CLLocationManager = CLLocationManager.init,
        now: @escaping () -> Date = Date.init
    ) {
        self.activityType = activityType
        self.authorizationStatusProvider = authorizationStatusProvider
        self.makeLocationManager = makeLocationManager
        self.now = now
        self.authorizationStatus = authorizationStatusProvider()
        super.init()
    }

    /// Requests when-in-use authorization (CARDIO-02 makes GPS a feature the user explicitly
    /// starts, so this prompt is expected -- see the header comment's inversion notice), then
    /// begins updating location. Confined to this single call site: no other method in this
    /// type starts location updates.
    func start() {
        sessionStartedAt = now()
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }

    func pause() {
        locationManager.stopUpdatingLocation()
    }

    func stop() {
        locationManager.stopUpdatingLocation()
    }

    /// Produces the finished `CardioSession` with the GPS capture source. All measurement comes
    /// from `accumulator.progress`, which every accepted `LocationSample` has already fed --
    /// this method performs no computation of its own.
    func finish() -> CardioSession {
        let endedAt = now()
        return CardioSession(
            activityType: activityType,
            source: .gps,
            startedAt: sessionStartedAt ?? endedAt,
            endedAt: endedAt,
            progress: accumulator.progress
        )
    }

    private func handleUpdate(_ locations: [CLLocation]) {
        for location in locations {
            let sample = LocationSample(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                altitudeMeters: location.altitude,
                horizontalAccuracyMeters: location.horizontalAccuracy,
                verticalAccuracyMeters: location.verticalAccuracy,
                timestamp: location.timestamp
            )
            accumulator.accept(sample)
        }
        progress = accumulator.progress
    }
}

extension GPSTrackingSession: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            handleUpdate(locations)
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            authorizationStatus = status
        }
    }
}
