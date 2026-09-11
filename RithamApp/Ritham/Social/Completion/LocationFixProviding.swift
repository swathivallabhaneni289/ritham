import CoreLocation

/// A capture-only seam `CompletionLoggingModel` calls through to obtain a location fix, letting
/// this feature area avoid ever naming a CoreLocation type inside `CompletionLoggingModel.swift`
/// itself -- that file's own acceptance criterion
/// (`grep -Ec 'CLGeocoder|CLLocationManager|CLLocationCoordinate2D'` == 0) requires it, while
/// `key_links` requires that same file to call plan 04.1-07's
/// `LocationAttachment.resolveSharedPlaceName(fix:zones:geocoder:)`, whose `fix` parameter is
/// itself typed `CLLocationCoordinate2D?`. Naming this seam's own return type here, in its own
/// file, is what makes both requirements true at once: `CompletionLoggingModel.swift` writes
/// `await locationFixProvider.currentFix()` and never spells the coordinate type itself.
///
/// Declared in its own file, deliberately NOT inside `LocationAttachment.swift` (plan 04.1-07's
/// owned capture-zone-check-geocode-discard sequence, already tested and committed) -- adding a
/// fix-provider abstraction to that file would be an out-of-scope edit to a different plan's
/// proven file. This is a Rule 3 (blocking) deviation from this plan's own stated file list, not
/// present in `04.1-14-PLAN.md`'s `files_modified`.
protocol LocationFixProviding: Sendable {
    /// Returns a single, freshly captured fix, or `nil` on any failure (denied authorization, no
    /// fix within a reasonable time, or any other `CLLocationManager` error). Never throws --
    /// matching `PlaceNameResolving.placeName(for:)`'s own "the only correct response to a failure
    /// is 'no location'" reasoning (`LocationAttachment.swift`).
    func currentFix() async -> CLLocationCoordinate2D?
}

/// The production `LocationFixProviding` implementation: a thin, one-shot wrapper around
/// `CLLocationManager.requestLocation()`. Requests when-in-use authorization only, matching
/// `GPSTrackingSession`'s own precedent (`Cardio/GPSTrackingSession.swift`) of never requesting
/// always-authorization for a feature the user explicitly triggers. Never retains a fix or a
/// manager beyond the single in-flight `currentFix()` call that produced it -- once that call
/// returns, both are released, matching `LocationAttachment.resolveSharedPlaceName`'s own "the fix
/// never survives past this call" discipline one layer up.
///
/// Real GPS capture through this type is deferred to the project's existing end-of-project
/// physical-device batch verification pass (per `PROJECT.md`'s Key Decisions) -- the Simulator has
/// no real location hardware, matching plan 04.1-07's identical, already-documented deferral for
/// `LocationAttachment`'s own real-fix behavior.
final class SystemLocationFixProvider: NSObject, LocationFixProviding, CLLocationManagerDelegate, @unchecked Sendable {
    private let makeLocationManager: () -> CLLocationManager
    private let lock = NSLock()
    private var pendingContinuation: CheckedContinuation<CLLocationCoordinate2D?, Never>?
    private var activeManager: CLLocationManager?

    init(makeLocationManager: @escaping () -> CLLocationManager = CLLocationManager.init) {
        self.makeLocationManager = makeLocationManager
        super.init()
    }

    func currentFix() async -> CLLocationCoordinate2D? {
        await withCheckedContinuation { continuation in
            lock.lock()
            // WR-02 fix: a still-in-flight prior call's continuation and manager must never simply
            // be overwritten here -- that would either leak the prior CheckedContinuation (never
            // resumed -- a runtime trap in debug builds, a silent hang in release) or, if the prior
            // manager's delegate callback fires after this point, misattribute the prior call's
            // result to this new call. Detaching the prior manager's delegate first means its
            // callback can never reach `resume(with:)` at all once superseded; resuming the prior
            // continuation with `nil` immediately after means the prior caller sees a clean "no
            // fix" rather than hanging forever.
            let previousContinuation = pendingContinuation
            let previousManager = activeManager
            pendingContinuation = continuation
            let manager = makeLocationManager()
            manager.delegate = self
            activeManager = manager
            lock.unlock()

            previousManager?.delegate = nil
            previousContinuation?.resume(returning: nil)

            manager.requestWhenInUseAuthorization()
            manager.requestLocation()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        resume(with: locations.first?.coordinate)
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        resume(with: nil)
    }

    private func resume(with coordinate: CLLocationCoordinate2D?) {
        lock.lock()
        let continuation = pendingContinuation
        pendingContinuation = nil
        activeManager = nil
        lock.unlock()
        continuation?.resume(returning: coordinate)
    }
}
