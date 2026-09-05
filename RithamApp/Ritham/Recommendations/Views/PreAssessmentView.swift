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
//
// Per D-04, completion is baseline-only: this file calls neither a cardio-session save nor a
// lift-session save anywhere -- the absence of those calls is the enforcement, not a comment.
//
// Per D-04's forbidden-framing rule (inherited from `CalibrationBaseline`'s own header comment):
// no text on this screen presents the result as a score, grade, level, percentile, or rating.
//
// STUB (TDD RED): `isComplete` is hardcoded to `false` and `complete(store:)`/`skip(store:)` are
// no-ops, so `PreAssessmentTests` fails meaningfully before the real behavior lands.

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
    private let now: () -> Date

    init(now: @escaping () -> Date = Date.init) {
        self.now = now
    }

    func selectMode(_ mode: PreAssessmentMode) {
        self.mode = mode
    }

    func start() {
        hasStarted = true
    }

    func recordWorkingSet(exercise: String, loadKg: Double? = nil) {}

    var progress: CalibrationProgress {
        .walk(WalkProgress())
    }

    var isComplete: Bool { false }

    @discardableResult
    func complete(store: HealthDataStore) -> Bool { false }

    func skip(store: HealthDataStore) {}
}

struct PreAssessmentView: View, OnboardingStepPresenting {
    static let step: OnboardingStep = .preAssessment

    static func makeView(flow: OnboardingFlow) -> AnyView {
        AnyView(PreAssessmentView(flow: flow))
    }

    let flow: OnboardingFlow
    @Environment(\.modelContext) private var modelContext
    @State private var model = PreAssessmentModel()

    var body: some View {
        RithamScreen(surface: DecorativeSurface.calibrationSession, headline: "Quick starting-point check") {
            EmptyView()
        }
    }
}
