import SwiftData
import SwiftUI
import RithamCore

// CARDIO-02's live session screen: shows position and elevation confidence as two independent
// indicators (never blended, per `CardioProgress`'s own header comment and 02-RESEARCH.md
// Pitfall 5), and shows grade-adjusted pace only when `GradeAdjustedPace.adjustedSecondsPerKm`
// actually returns a value -- an absent optional renders as an absence, never a placeholder
// glyph in a numeric slot (T-02-04). A denied/restricted GPS authorization switches to the
// manual timer and keeps the session running; this screen never presents a blocking dialog and
// never ends the session on a permission decision (T-02-31).
//
// Saves through `HealthDataStore.saveCardioSession` (plan 02-08's accessor) on finish and adds
// no persistence code of its own -- this file never touches `HealthDataStore.swift`.

/// Drives `CardioSessionView`'s behavior at the model level, so `CardioSessionScreenTests` can
/// assert every behavior in the plan's `<behavior>` list without rendering the view.
@MainActor
@Observable
final class CardioSessionModel {
    let activityType: ActivityType

    private(set) var isRunning = false
    private let gpsSession: GPSTrackingSession?
    private let stopwatchSession: StopwatchCardioSession

    /// `gpsSession` is `nil` when the picker's capture-mode choice was manual -- this model
    /// never constructs a `GPSTrackingSession` itself in that case, so a manual start never
    /// touches CoreLocation at all.
    init(
        activityType: ActivityType,
        gpsSession: GPSTrackingSession?,
        stopwatchSession: StopwatchCardioSession? = nil,
        now: @escaping () -> Date = Date.init
    ) {
        self.activityType = activityType
        self.gpsSession = gpsSession
        self.stopwatchSession = stopwatchSession ?? StopwatchCardioSession(activityType: activityType, now: now)
    }

    /// `true` from the very first render when the picker chose the manual path (`gpsSession ==
    /// nil`), and becomes `true` the moment a GPS session reports a denied/restricted
    /// authorization -- read fresh on every access (never cached) so a denial arriving
    /// asynchronously, after `start()` has already been called, is picked up with no dedicated
    /// observer (T-02-31).
    var isUsingManualCapture: Bool {
        guard let gpsSession else { return true }
        return gpsSession.requiresManualFallback
    }

    var progress: CardioProgress {
        isUsingManualCapture ? stopwatchSession.progress : (gpsSession?.progress ?? stopwatchSession.progress)
    }

    func start() {
        isRunning = true
        if isUsingManualCapture {
            stopwatchSession.start()
        } else {
            gpsSession?.start()
        }
    }

    /// Calls `stopwatchSession.stop()`, not `.pause()`: `StopwatchCardioSession.pause()` zeroes
    /// the continuous-duration clock via `CardioProgress.recordInterruption()` (the calibration
    /// "this broke continuity" semantics its doc comment describes), while `.stop()` freezes the
    /// displayed elapsed time without that penalty -- the freeze-then-continue behavior this
    /// button's "Pausing and resuming reflect in the displayed duration" contract needs.
    func pause() {
        isRunning = false
        if isUsingManualCapture {
            stopwatchSession.stop()
        } else {
            gpsSession?.pause()
        }
    }

    func resume() {
        isRunning = true
        if isUsingManualCapture {
            stopwatchSession.resume()
        } else {
            // GPSTrackingSession exposes no resume() -- 02-09's SUMMARY explicitly deferred
            // "pause/resume-by-restarting-location-updates" to "a future plan that revisits the
            // contract." Restarting location updates via start() is that contract: it
            // re-requests authorization (a no-op once already granted) and calls
            // startUpdatingLocation() again, the only resume path this session type has.
            gpsSession?.start()
        }
    }

    /// Called once per second by the view's `TimelineView` tick. Lazily starts
    /// `stopwatchSession` the moment `isUsingManualCapture` turns true while the session is
    /// meant to be running -- covers the realistic flow where `GPSTrackingSession.start()`'s
    /// authorization prompt is answered *after* this session has already started, so the manual
    /// fallback picks up timing with no gap and no dialog of its own.
    func tick() {
        guard isRunning, isUsingManualCapture, !stopwatchSession.isRunning else { return }
        stopwatchSession.start()
    }

    func finish() -> CardioSession {
        isRunning = false
        if isUsingManualCapture {
            return stopwatchSession.finish()
        }
        gpsSession?.stop()
        return gpsSession?.finish() ?? stopwatchSession.finish()
    }
}

struct CardioSessionView: View, OnboardingStepPresenting {
    static let step: OnboardingStep = .cardioSession

    static func makeView(flow: OnboardingFlow) -> AnyView {
        AnyView(CardioSessionView(flow: flow))
    }

    let flow: OnboardingFlow
    @Environment(\.modelContext) private var modelContext

    @State private var model: CardioSessionModel

    /// HEALTH-03's inline workout guidance for this session, loaded once `modelContext` is
    /// available in `onAppear` -- `GuidanceContext`'s own initializer reads the store immediately,
    /// so this is never rebuilt mid-session; a screening edit made elsewhere while a session is
    /// already running is picked up the next time this screen appears, matching every other
    /// store-driven read on this screen (T-02-34).
    @State private var guidanceContext: GuidanceContext?

    init(flow: OnboardingFlow) {
        self.flow = flow
        let activityType = flow.cardioActivityType
        let gps: GPSTrackingSession? = flow.cardioCaptureMode == .gps
            ? GPSTrackingSession(activityType: activityType)
            : nil
        _model = State(initialValue: CardioSessionModel(activityType: activityType, gpsSession: gps))
    }

    var body: some View {
        RithamScreen(surface: DecorativeSurface.flat, headline: "\(model.activityType.displayName) session") {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                VStack(alignment: .leading, spacing: RithamSpacing.md) {
                    captureStatusText

                    HStack {
                        Spacer(minLength: 0)
                        VStack(spacing: RithamSpacing.sm) {
                            RadialSessionTimer(fraction: ringFraction, isComplete: false)
                            Text(formattedDuration)
                                .font(RithamType.display)
                                .modifier(RithamType.numerals())
                                .foregroundStyle(RithamColor.paper)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, RithamSpacing.sm)

                    metricsSection
                    confidenceSection
                    gradeAdjustedPaceSection
                    splitsSection
                    guidanceSection
                    controls
                }
                .onChange(of: context.date) { _, _ in
                    model.tick()
                }
            }
        }
        .onAppear {
            model.start()
            setupGuidance()
        }
    }

    // MARK: - Guidance

    /// HEALTH-03's workout guidance, shown inline above `controls` so the adjustment is visible
    /// at the moment this session is being logged, not on a separate screen. Never gates any
    /// control on this screen -- `AdjustedGuidanceBanner` renders a referral message in place of
    /// personalized text under a required-blocking permission, but timing, pausing, and finishing
    /// all keep working regardless (HEALTH-06's domain-scoped-never-app-wide rule).
    @ViewBuilder
    private var guidanceSection: some View {
        if let guidanceContext {
            AdjustedGuidanceBanner(context: guidanceContext, domain: .workout)
        }
    }

    private func setupGuidance() {
        guard guidanceContext == nil else { return }
        guidanceContext = GuidanceContext(context: modelContext)
    }

    // MARK: - Status / controls

    private var captureStatusText: some View {
        Text(model.isUsingManualCapture
            ? "Timing manually -- no location is being used for this session."
            : "Tracking with GPS.")
            .font(RithamType.label)
            .foregroundStyle(RithamColor.paper)
    }

    @ViewBuilder
    private var controls: some View {
        HStack(spacing: RithamSpacing.sm) {
            if model.isRunning {
                SecondaryCTAButton(title: "Pause") {
                    model.pause()
                }
            } else {
                SecondaryCTAButton(title: "Resume") {
                    model.resume()
                }
            }
            PrimaryCTAButton(title: "Finish") {
                finish()
            }
        }
    }

    // MARK: - Metrics

    @ViewBuilder
    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: RithamSpacing.xs) {
            Text("Distance: \(formattedDistanceKm) km")
            Text("Elevation gain: \(Int(model.progress.elevationGainMeters)) m")
            if let pace = currentPaceSecondsPerKm {
                Text("Pace: \(formattedPace(pace)) / km")
            }
        }
        .font(RithamType.body)
        .modifier(RithamType.numerals())
        .foregroundStyle(RithamColor.paper)
    }

    /// CARDIO-02's whole point: two independent indicators, never one blended reading -- reads
    /// `horizontalConfidence` and `elevationConfidence` as the two separate `CardioProgress`
    /// fields they are.
    @ViewBuilder
    private var confidenceSection: some View {
        HStack(spacing: RithamSpacing.md) {
            Text("Position: \(confidenceLabel(model.progress.horizontalConfidence))")
            Text("Elevation: \(confidenceLabel(model.progress.elevationConfidence))")
        }
        .font(RithamType.label)
        .foregroundStyle(RithamColor.paper)
    }

    /// T-02-04: consumed via optional binding, never force-unwrapped, and the row is omitted
    /// entirely -- never a placeholder glyph in a numeric slot -- when the elevation signal
    /// isn't good enough yet.
    @ViewBuilder
    private var gradeAdjustedPaceSection: some View {
        if let adjusted = gradeAdjustedPaceSecondsPerKm {
            Text("Grade-adjusted pace: \(formattedPace(adjusted)) / km")
                .font(RithamType.body)
                .modifier(RithamType.numerals())
                .foregroundStyle(RithamColor.paper)
        } else {
            Text("Elevation signal isn't strong enough yet for a grade-adjusted pace.")
                .font(RithamType.label)
                .foregroundStyle(RithamColor.paper)
        }
    }

    @ViewBuilder
    private var splitsSection: some View {
        if !model.progress.splits.isEmpty {
            VStack(alignment: .leading, spacing: RithamSpacing.xs) {
                ForEach(model.progress.splits, id: \.index) { split in
                    Text("Split \(split.index): \(formattedPace(split.averageSecondsPerKm)) / km")
                }
            }
            .font(RithamType.label)
            .modifier(RithamType.numerals())
            .foregroundStyle(RithamColor.paper)
        }
    }

    // MARK: - Derived values

    private var ringFraction: Double {
        // No fixed target duration exists for an open-ended tracked session (unlike
        // calibration's qualifying-session bar) -- the ring instead sweeps a full circle every
        // `CalibrationThreshold.qualifyingWalkDuration`, giving a continuously-moving dial rather
        // than a fraction of nothing.
        let period = CalibrationThreshold.qualifyingWalkDuration
        return model.progress.continuousDuration.truncatingRemainder(dividingBy: period) / period
    }

    private var formattedDuration: String {
        let totalSeconds = max(0, Int(model.progress.continuousDuration))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
            : String(format: "%02d:%02d", minutes, seconds)
    }

    private var formattedDistanceKm: String {
        String(format: "%.2f", model.progress.distanceMeters / 1000)
    }

    private var currentPaceSecondsPerKm: Double? {
        guard model.progress.distanceMeters > 0 else { return nil }
        return model.progress.continuousDuration / (model.progress.distanceMeters / 1000)
    }

    private var gradeAdjustedPaceSecondsPerKm: Double? {
        guard
            let pace = currentPaceSecondsPerKm,
            let gradePercent = GradeAdjustedPace.gradePercent(
                elevationGainMeters: model.progress.elevationGainMeters,
                distanceMeters: model.progress.distanceMeters
            )
        else { return nil }
        return GradeAdjustedPace.adjustedSecondsPerKm(
            paceSecondsPerKm: pace,
            gradePercent: gradePercent,
            elevationConfidence: model.progress.elevationConfidence
        )
    }

    private func formattedPace(_ secondsPerKm: Double) -> String {
        let totalSeconds = max(0, Int(secondsPerKm))
        return String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
    }

    private func confidenceLabel(_ confidence: SignalConfidence) -> String {
        switch confidence {
        case .unavailable: return "Unavailable"
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }

    // MARK: - Finish

    private func finish() {
        let session = model.finish()
        let store = HealthDataStore(context: modelContext)
        try? store.saveCardioSession(session)
        flow.returnToHub()
    }
}
