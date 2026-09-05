import SwiftData
import SwiftUI
import RithamCore

// ONBOARD-01's triggered pre-assessment: a real guided walk or light-lift session, never a
// self-reported fitness-level control of any kind. Modelled on
// `RithamApp/Ritham/Calibration/Views/CalibrationSessionView.swift` -- same up-front duration
// statement, same `RadialSessionTimer` progress visual -- but measured through this phase's own
// session domain rather than conforming to `CalibrationSessionSource` (Phase 1's calibration-only
// protocol), per ROADMAP Phase 2 criterion 8. The walk half uses `StopwatchCardioSession`
// (Phase 2's own capture adapter/progress type); the lift half tracks working sets directly with
// no adapter needed. Both convert their finished measurement into the shape
// `CalibrationBaseline.derive` accepts only at completion -- that conversion is the one place
// this screen touches Phase 1's calibration domain, and it exists solely to reuse the
// already-tested completion/derivation rules rather than reinventing them.
//
// GPS is intentionally not used here even though it is also "this phase's own capture adapter":
// the walk completion bar (`CalibrationThreshold.qualifyingWalkDuration`) is duration-only, and
// requesting location authorization for a screen positioned as a fast, zero-friction pre-check
// would reintroduce exactly the blocking-prompt risk calibration's own precedent (D-02) avoids.
// A skipped location grant would not affect completion here anyway, since the threshold never
// depends on distance -- only on the derived pace zone's precision, which the conservative
// fallback already covers when distance is unmeasured.
//
// Per D-04, completion is baseline-only: this file calls neither a cardio-session save nor a
// lift-session save anywhere -- the absence of those calls is the enforcement, not a comment.
//
// Per D-04's forbidden-framing rule (inherited from the baseline type's own header comment): no
// text on this screen presents the result as a score, grade, level, percentile, or rating.

/// The two assessment modes this screen offers.
enum PreAssessmentMode: String, CaseIterable, Sendable {
    case walk
    case lift
}

/// Drives `PreAssessmentView`'s behavior at the model level, so `PreAssessmentTests` can assert
/// every behavior in the plan's `<behavior>` list without rendering the view.
@MainActor
@Observable
final class PreAssessmentModel {
    private(set) var mode: PreAssessmentMode = .walk
    private(set) var hasStarted = false

    private let stopwatchSession: StopwatchCardioSession
    private(set) var liftProgress = LiftProgress()
    private let now: () -> Date

    init(now: @escaping () -> Date = Date.init) {
        self.now = now
        self.stopwatchSession = StopwatchCardioSession(activityType: .walk, now: now)
    }

    /// A no-op once the session has started -- switching modes mid-session would silently
    /// discard whichever half was already in progress.
    func selectMode(_ mode: PreAssessmentMode) {
        guard !hasStarted else { return }
        self.mode = mode
    }

    func start() {
        hasStarted = true
        if mode == .walk {
            stopwatchSession.start()
        }
    }

    /// Warm-up sets must not be passed here -- they do not count toward
    /// `CalibrationThreshold.qualifyingWorkingSets`, matching `LiftProgress`'s own contract.
    func recordWorkingSet(exercise: String, loadKg: Double? = nil) {
        liftProgress.recordWorkingSet(exercise: exercise, loadKg: loadKg)
    }

    /// The current measurement, converted into the shape `CalibrationBaseline.derive` and
    /// `CalibrationCompletion.evaluate` accept. For walk mode this is the one conversion point
    /// between this phase's own `CardioProgress` and Phase 1's `WalkProgress` -- both already
    /// share the same three fields, so this is a direct field-for-field copy, not a
    /// reinterpretation.
    var progress: CalibrationProgress {
        switch mode {
        case .walk:
            let measured = stopwatchSession.progress
            return .walk(WalkProgress(
                continuousDuration: measured.continuousDuration,
                distanceMeters: measured.distanceMeters,
                wasInterrupted: measured.wasInterrupted
            ))
        case .lift:
            return .lift(liftProgress)
        }
    }

    var isComplete: Bool {
        CalibrationCompletion.evaluate(progress) == .complete
    }

    /// Derives and stores a measured baseline, then marks the pre-assessment complete. Returns
    /// `false` and stores nothing if `progress` has not reached its mode's completion bar --
    /// the caller gates the completing action on `isComplete`, but this guard keeps the store
    /// from ever accepting an unqualified result even if that guard is ever bypassed.
    @discardableResult
    func complete(store: HealthDataStore) -> Bool {
        guard let baseline = CalibrationBaseline.derive(from: progress, establishedAt: now()) else {
            return false
        }
        try? store.saveCalibrationBaseline(baseline)
        try? store.markPreAssessmentCompleted()
        return true
    }

    /// Marks the pre-assessment complete without storing a measured baseline. The store's own
    /// loader already returns a conservative fallback when nothing is stored, so this is the
    /// entire skip path -- no second fallback is written here.
    func skip(store: HealthDataStore) {
        try? store.markPreAssessmentCompleted()
    }
}

struct PreAssessmentView: View, OnboardingStepPresenting {
    static let step: OnboardingStep = .preAssessment

    static func makeView(flow: OnboardingFlow) -> AnyView {
        AnyView(PreAssessmentView(flow: flow))
    }

    let flow: OnboardingFlow
    @Environment(\.modelContext) private var modelContext
    @State private var model = PreAssessmentModel()
    @State private var exerciseName = ""

    var body: some View {
        RithamScreen(surface: DecorativeSurface.calibrationSession, headline: "Quick starting-point check") {
            if !model.hasStarted {
                startContent
            } else {
                switch model.mode {
                case .walk: walkContent
                case .lift: liftContent
                }
            }

            SecondaryCTAButton(title: OnboardingCopy.Calibration.skipCTA) {
                skip()
            }
        }
    }

    // MARK: - Mode selection

    @ViewBuilder
    private var startContent: some View {
        VStack(alignment: .leading, spacing: RithamSpacing.md) {
            Text("A short walk or a light lift sets your real starting point -- no fitness-level dropdown.")
                .font(RithamType.body)
                .foregroundStyle(RithamColor.paper)

            HStack(spacing: RithamSpacing.sm) {
                SecondaryCTAButton(title: modeButtonTitle(.walk)) {
                    model.selectMode(.walk)
                }
                SecondaryCTAButton(title: modeButtonTitle(.lift)) {
                    model.selectMode(.lift)
                }
            }

            Text(durationHintText)
                .font(RithamType.label)
                .foregroundStyle(RithamColor.paper)

            PrimaryCTAButton(title: "Start") {
                model.start()
            }
        }
    }

    private func modeButtonTitle(_ mode: PreAssessmentMode) -> String {
        let base = mode == .walk ? "Walk" : "Light lift"
        return model.mode == mode ? "\(base) (selected)" : base
    }

    private var durationHintText: String {
        model.mode == .walk
            ? OnboardingCopy.Calibration.walkDurationHint
            : "A few working sets across two exercises -- no time limit."
    }

    // MARK: - Walk

    @ViewBuilder
    private var walkContent: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            VStack(alignment: .leading, spacing: RithamSpacing.md) {
                HStack {
                    Spacer(minLength: 0)
                    VStack(spacing: RithamSpacing.sm) {
                        RadialSessionTimer(fraction: walkFraction, isComplete: model.isComplete)
                        Text(formattedWalkDuration)
                            .font(RithamType.display)
                            .modifier(RithamType.numerals())
                            .foregroundStyle(RithamColor.paper)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Elapsed time")
                    .accessibilityValue(formattedWalkDuration)
                    Spacer(minLength: 0)
                }
                .padding(.vertical, RithamSpacing.sm)

                if model.isComplete {
                    PrimaryCTAButton(title: "Done") {
                        complete()
                    }
                }
            }
        }
    }

    private var walkFraction: Double {
        guard case .walk(let walk) = model.progress else { return 0 }
        return walk.continuousDuration / CalibrationThreshold.qualifyingWalkDuration
    }

    private var formattedWalkDuration: String {
        guard case .walk(let walk) = model.progress else { return "00:00" }
        let totalSeconds = max(0, Int(walk.continuousDuration))
        return String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
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

            HStack {
                Spacer(minLength: 0)
                RadialSessionTimer(fraction: liftFraction, isComplete: model.isComplete)
                Spacer(minLength: 0)
            }
            .padding(.vertical, RithamSpacing.sm)

            HStack(spacing: RithamSpacing.md) {
                Text("Working sets: \(liftWorkingSetsCount)")
                Text("Exercises: \(liftExercisesCount)")
            }
            .font(RithamType.body)
            .modifier(RithamType.numerals())
            .foregroundStyle(RithamColor.paper)

            if model.isComplete {
                PrimaryCTAButton(title: "Done") {
                    complete()
                }
            }
        }
    }

    private var liftWorkingSetsCount: Int {
        guard case .lift(let lift) = model.progress else { return 0 }
        return lift.totalWorkingSets
    }

    private var liftExercisesCount: Int {
        guard case .lift(let lift) = model.progress else { return 0 }
        return lift.distinctExercises
    }

    private var liftFraction: Double {
        guard case .lift(let lift) = model.progress else { return 0 }
        let setsFraction = Double(lift.totalWorkingSets) / Double(CalibrationThreshold.qualifyingWorkingSets)
        let exercisesFraction = Double(lift.distinctExercises) / Double(CalibrationThreshold.qualifyingExercises)
        return min(setsFraction, exercisesFraction)
    }

    private func recordWorkingSet() {
        let trimmed = exerciseName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        model.recordWorkingSet(exercise: trimmed)
    }

    // MARK: - Completion / skip

    /// Returns to `RecommendationsView`, the screen that opened this one -- `goBack()`, not
    /// `returnToHub()`, since this step is nested exactly one level below Recommendations, not
    /// below the interim hub itself.
    private func complete() {
        let store = HealthDataStore(context: modelContext)
        model.complete(store: store)
        flow.goBack()
    }

    private func skip() {
        let store = HealthDataStore(context: modelContext)
        model.skip(store: store)
        flow.goBack()
    }
}
