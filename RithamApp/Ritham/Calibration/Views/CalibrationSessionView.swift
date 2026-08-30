import SwiftUI
import SwiftData
import RithamCore

// D-02 in full: measured via GPS/motion sensors when the user grants location access, motion or
// stopwatch otherwise, with no blocking prompt either way. For a walk this view uses
// PedometerSession when step counting is available and StopwatchSession otherwise, switching
// automatically and telling the user plainly which is running rather than failing -- and offers
// the stopwatch explicitly as a choice too, since D-02 requires the manual path work standalone
// and Phase 2 will pair passive-first capture with full manual configuration, so exposing the
// choice now keeps the two consistent rather than retrofitting it later.
//
// This screen never requests location authorisation. `LocationEnrichment` is attached so that
// where location has already been granted, pace and distance are shown with GPS precision;
// where it has not, the enricher stays inert, the session proceeds unchanged, and nothing
// prompts. The display binds to the enricher's optional values, falling back to the
// motion-derived ones, rather than branching on permission state in this view.
//
// Progress is shown as plain text and a bar strip -- never a ring, since 01-UI-SPEC.md's
// ring-and-dot ornament is a static, non-data-bearing mark that must never fill or represent a
// fraction of anything.
//
// A session ended early is kept incomplete: this view offers to restart or skip, never records
// a partial session as a baseline.
struct CalibrationSessionView: View, OnboardingStepPresenting {
    static let step: OnboardingStep = .calibrationSession

    static func makeView(flow: OnboardingFlow) -> AnyView {
        AnyView(CalibrationSessionView(flow: flow))
    }

    let flow: OnboardingFlow
    @Environment(\.modelContext) private var modelContext

    @State private var pedometerSession = PedometerSession()
    @State private var stopwatchSession = StopwatchSession()
    @State private var liftRecorder = LiftSessionRecorder()
    @State private var locationEnrichment = LocationEnrichment()

    @State private var usesStopwatch = false
    @State private var hasStarted = false
    @State private var exerciseName = ""

    private var mode: CalibrationMode { flow.calibrationMode }

    /// Whichever walk source is actually driving this session -- the pedometer when it is
    /// available and the user has not explicitly switched away from it, the stopwatch
    /// otherwise.
    private var activeWalkSource: any CalibrationSessionSource {
        (usesStopwatch || !pedometerSession.isAvailable) ? stopwatchSession : pedometerSession
    }

    private func progress() -> CalibrationProgress {
        mode == .walk ? activeWalkSource.progress : liftRecorder.progress
    }

    private func isComplete() -> Bool {
        CalibrationCompletion.evaluate(progress()) == .complete
    }

    var body: some View {
        RithamScreen(surface: DecorativeSurface.calibration, headline: sessionHeadline) {
            switch mode {
            case .walk:
                walkContent
            case .lift:
                liftContent
            }

            if isComplete() {
                PrimaryCTAButton(title: OnboardingCopy.Age.cta) {
                    completeSession()
                }
            }

            SecondaryCTAButton(title: OnboardingCopy.Calibration.skipCTA) {
                skipCalibration()
            }
        }
    }

    private var sessionHeadline: String {
        mode == .walk ? "Walking calibration" : "Lift calibration"
    }

    // MARK: - Walk

    @ViewBuilder
    private var walkContent: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            VStack(alignment: .leading, spacing: RithamSpacing.md) {
                Text(walkSourceStatusText)
                    .font(RithamType.label)
                    .foregroundStyle(RithamColor.paper)

                Text(formattedWalkDuration)
                    .font(RithamType.display)
                    .modifier(RithamType.numerals())
                    .foregroundStyle(RithamColor.paper)

                if let pace = displayPaceSecondsPerKm {
                    Text("Pace: \(formattedPace(pace)) / km")
                        .font(RithamType.body)
                        .modifier(RithamType.numerals())
                        .foregroundStyle(RithamColor.paper)
                }

                ProgressBarStrip(fraction: walkFraction)

                walkControls
            }
        }
    }

    @ViewBuilder
    private var walkControls: some View {
        if !hasStarted {
            PrimaryCTAButton(title: "Start walk") {
                startWalk()
            }
        } else {
            HStack(spacing: RithamSpacing.sm) {
                if usesStopwatch {
                    if stopwatchSession.isRunning {
                        SecondaryCTAButton(title: "Stop") {
                            stopwatchSession.stop()
                        }
                    } else {
                        SecondaryCTAButton(title: "Resume") {
                            stopwatchSession.resume()
                        }
                    }
                }
                if !usesStopwatch && pedometerSession.isAvailable {
                    SecondaryCTAButton(title: "Switch to manual stopwatch") {
                        switchToStopwatch()
                    }
                }
                SecondaryCTAButton(title: "Restart") {
                    restartWalk()
                }
            }
        }
    }

    private var walkSourceStatusText: String {
        if !hasStarted {
            if usesStopwatch {
                return "Using the manual stopwatch."
            }
            return pedometerSession.isAvailable
                ? "Using your phone's motion sensor."
                : "Motion sensor unavailable -- using the manual stopwatch."
        }
        if usesStopwatch {
            return stopwatchSession.isRunning ? "Manual stopwatch running." : "Manual stopwatch stopped."
        }
        return "Motion sensor running."
    }

    private var formattedWalkDuration: String {
        guard case .walk(let walk) = activeWalkSource.progress else { return "00:00" }
        let totalSeconds = max(0, Int(walk.continuousDuration))
        return String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
    }

    private var displayPaceSecondsPerKm: Double? {
        if let enriched = locationEnrichment.enrichedPaceSecondsPerKm {
            return enriched
        }
        guard case .walk(let walk) = activeWalkSource.progress, walk.distanceMeters > 0 else { return nil }
        return walk.continuousDuration / (walk.distanceMeters / 1000)
    }

    private func formattedPace(_ secondsPerKm: Double) -> String {
        let totalSeconds = max(0, Int(secondsPerKm))
        return String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
    }

    private var walkFraction: Double {
        guard case .walk(let walk) = activeWalkSource.progress else { return 0 }
        return walk.continuousDuration / CalibrationThreshold.qualifyingWalkDuration
    }

    private func startWalk() {
        hasStarted = true
        if !pedometerSession.isAvailable {
            usesStopwatch = true
        }
        if usesStopwatch {
            stopwatchSession.start()
        } else {
            pedometerSession.start()
        }
        locationEnrichment.startIfAlreadyAuthorized()
    }

    private func switchToStopwatch() {
        usesStopwatch = true
        pedometerSession.stop()
        stopwatchSession.start()
    }

    private func restartWalk() {
        pedometerSession.stop()
        locationEnrichment.stop()
        pedometerSession = PedometerSession()
        stopwatchSession = StopwatchSession()
        locationEnrichment = LocationEnrichment()
        hasStarted = false
    }

    // MARK: - Lift

    @ViewBuilder
    private var liftContent: some View {
        VStack(alignment: .leading, spacing: RithamSpacing.md) {
            TextField("Exercise name", text: $exerciseName)
                .font(RithamType.body)
                .foregroundStyle(RithamColor.paper)
                .padding(RithamSpacing.md)
                .frame(minHeight: RithamSpacing.minimumTapTarget)
                .background(
                    RoundedRectangle(cornerRadius: RithamSpacing.sm)
                        .stroke(RithamColor.paper, lineWidth: 1)
                )
                .accessibilityLabel("Exercise name")

            PrimaryCTAButton(title: "Record working set") {
                recordWorkingSet()
            }
            .disabled(exerciseName.trimmingCharacters(in: .whitespaces).isEmpty)

            HStack(spacing: RithamSpacing.md) {
                Text("Working sets: \(liftRecorder.totalWorkingSets)")
                    .modifier(RithamType.numerals())
                Text("Exercises: \(liftRecorder.distinctExercises)")
                    .modifier(RithamType.numerals())
            }
            .font(RithamType.body)
            .foregroundStyle(RithamColor.paper)

            ProgressBarStrip(fraction: liftFraction)
        }
    }

    private var liftFraction: Double {
        let setsFraction = Double(liftRecorder.totalWorkingSets) / Double(CalibrationThreshold.qualifyingWorkingSets)
        let exercisesFraction = Double(liftRecorder.distinctExercises) / Double(CalibrationThreshold.qualifyingExercises)
        return min(setsFraction, exercisesFraction)
    }

    private func recordWorkingSet() {
        let trimmed = exerciseName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        liftRecorder.recordWorkingSet(exercise: trimmed)
    }

    // MARK: - Completion / skip

    private func completeSession() {
        guard let baseline = CalibrationBaseline.derive(from: progress(), establishedAt: Date()) else { return }
        let store = HealthDataStore(context: modelContext)
        try? store.saveCalibrationBaseline(baseline)
        flow.answers.calibrationOutcome = CalibrationOutcome.completed(baseline)
        flow.advance(from: .calibrationSession)
    }

    /// Routes via `.calibrationIntro` rather than `.calibrationSession` on purpose:
    /// `OnboardingRouter`'s skip-aware branch (jumping straight past the completion screen once
    /// `calibrationOutcome == .skipped`) lives on the `.calibrationIntro` case, not
    /// `.calibrationSession`, which unconditionally routes to `.calibrationComplete`. Asking the
    /// router "what comes next given a skip, from the intro's perspective" reuses that already-
    /// correct, already-tested branch instead of adding a second one -- this view still computes
    /// no routing decision of its own, it just re-enters the router at the case that already
    /// knows how to answer this question for a pure function of `answers`.
    private func skipCalibration() {
        flow.answers.calibrationOutcome = CalibrationOutcome.skipped
        let store = HealthDataStore(context: modelContext)
        try? store.saveCalibrationBaseline(CalibrationBaseline.provisional(establishedAt: Date()))
        flow.advance(from: .calibrationIntro)
    }
}

/// A plain bar strip -- never a ring -- showing progress toward calibration completion.
/// 01-UI-SPEC.md's ring-and-dot ornament is a static, non-data-bearing brand mark that must
/// never fill or represent a fraction of anything, so calibration progress uses this data form
/// instead.
private struct ProgressBarStrip: View {
    let fraction: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(RithamColor.paper.opacity(0.2))
                Rectangle()
                    .fill(RithamColor.hot)
                    .frame(width: geo.size.width * min(max(fraction, 0), 1))
            }
        }
        .frame(height: 8)
        .clipShape(RoundedRectangle(cornerRadius: RithamSpacing.xs))
    }
}
