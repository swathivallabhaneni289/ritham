import SwiftUI
import RithamCore

// CARDIO-01's activity-type selector and manual-start path, plus CROSSGEN-02's auto-detect
// confirmation prompt. Registers as `.cardioActivityPicker`, reached only via `flow.open(_:)`
// from the interim hub (`HomeHubView`) -- `OnboardingRouter` never advances into any Phase 2
// cardio step, per `OnboardingStep.swift`'s own header comment.
//
// The manual start never touches CoreLocation: this file imports neither CoreLocation nor
// CoreMotion directly (`MotionActivityDetector` wraps CoreMotion internally, but exposes no
// permission-triggering call this screen invokes for the manual path), so tapping "Start without
// location" cannot trigger any permission prompt -- PROJECT.md's phone-only promise holds
// structurally here, not just by convention.
//
// T-02-30: a detection candidate becomes a session only through the explicit "Log this session"
// accept action below. `MotionActivityDetector` itself exposes no method that writes a session
// (02-09's contract); dismissing here only clears the candidate and starts nothing.

extension ActivityType: @retroactive Identifiable {
    public var id: String { rawValue }
}

/// How this screen's chosen session should be captured -- an app-layer presentation/routing
/// concept (which capture adapter, `GPSTrackingSession` or `StopwatchCardioSession`, the session
/// screen should drive), never a fact `CardioSession`/RithamCore itself needs to carry: the
/// domain already expresses the *result* of a capture choice via `CardioCaptureSource`, and has
/// no reason to know about the screen-to-screen handoff that produced it.
enum CardioCaptureMode: String, CaseIterable, Sendable {
    case gps
    case manual
}

/// Drives this screen's behavior at the model level, so `CardioActivityPickerTests` can assert
/// every behavior in the plan's `<behavior>` list without rendering `CardioActivityPickerView`.
@MainActor
@Observable
final class CardioActivityPickerModel {
    private(set) var selectedActivityType: ActivityType?
    let detector: MotionActivityDetector

    init(detector: MotionActivityDetector = MotionActivityDetector()) {
        self.detector = detector
    }

    /// Selecting an activity type replaces the current selection and enables the start controls
    /// (the picker's start buttons are disabled until `selectedActivityType` is non-`nil`).
    func select(_ activityType: ActivityType) {
        selectedActivityType = activityType
    }

    /// Accepting carries `candidate`'s activity type into `selectedActivityType` -- the same
    /// state a manual chip tap sets -- then clears the candidate via `stopObserving()`. This is
    /// the only path on this screen that lets a detection influence a session; nothing here
    /// saves or starts a session by itself, matching `MotionActivityDetector`'s "no write path"
    /// contract.
    func acceptDetection(_ candidate: MotionDetectionCandidate) {
        selectedActivityType = candidate.activityType
        detector.stopObserving()
    }

    /// Dismissing writes nothing at all -- it only clears the candidate, the same side effect
    /// `stopObserving()` already has. No store, no session, no count anywhere changes.
    func dismissDetection() {
        detector.stopObserving()
    }

    /// Carries the chosen activity type and capture mode onto `flow` (an in-session UI handoff,
    /// the same discipline as `OnboardingFlow.calibrationMode`, never a routing decision) and
    /// pushes the session step. A no-op when nothing is selected yet, so a stray call before a
    /// chip is tapped cannot push an unconfigured session screen.
    func start(mode: CardioCaptureMode, on flow: OnboardingFlow) {
        guard let activityType = selectedActivityType else { return }
        flow.cardioActivityType = activityType
        flow.cardioCaptureMode = mode
        flow.open(.cardioSession)
    }
}

struct CardioActivityPickerView: View, OnboardingStepPresenting {
    static let step: OnboardingStep = .cardioActivityPicker

    static func makeView(flow: OnboardingFlow) -> AnyView {
        AnyView(CardioActivityPickerView(flow: flow))
    }

    let flow: OnboardingFlow
    @State private var model = CardioActivityPickerModel()

    private var selectionBinding: Binding<Set<ActivityType>> {
        Binding(
            get: { model.selectedActivityType.map { Set([$0]) } ?? [] },
            set: { newValue in
                guard let chosen = newValue.first else { return }
                model.select(chosen)
            }
        )
    }

    var body: some View {
        RithamScreen(
            surface: DecorativeSurface.flat,
            headline: "Track a cardio session",
            bodyText: "Choose an activity, then start with GPS tracking or a manual timer -- the manual timer needs no location access at all."
        ) {
            if let candidate = model.detector.detectionCandidate {
                detectionPrompt(candidate)
            }

            ChoiceQuestionView(
                prompt: "What are you doing?",
                options: ActivityType.known,
                mode: .single,
                selection: selectionBinding,
                optionTitle: \.displayName
            )

            PrimaryCTAButton(title: "Start with GPS") {
                model.start(mode: .gps, on: flow)
            }
            .disabled(model.selectedActivityType == nil)

            SecondaryCTAButton(title: "Start without location") {
                model.start(mode: .manual, on: flow)
            }
            .disabled(model.selectedActivityType == nil)
        }
        .onAppear { model.detector.startObserving() }
        .onDisappear { model.detector.stopObserving() }
    }

    @ViewBuilder
    private func detectionPrompt(_ candidate: MotionDetectionCandidate) -> some View {
        VStack(alignment: .leading, spacing: RithamSpacing.sm) {
            Text("It looks like you're moving. Log this as a \(candidate.activityType.displayName.lowercased())?")
                .font(RithamType.body)
                .foregroundStyle(RithamColor.paper)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: RithamSpacing.sm) {
                SecondaryCTAButton(title: "Not now") {
                    model.dismissDetection()
                }
                PrimaryCTAButton(title: "Log this session") {
                    model.acceptDetection(candidate)
                    model.start(mode: .gps, on: flow)
                }
            }
        }
        .padding(RithamSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: RithamSpacing.sm)
                .stroke(RithamColor.paper, lineWidth: 1)
        )
    }
}
