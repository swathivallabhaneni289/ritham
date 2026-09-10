import SwiftUI
import RithamCore

// App-side wrapper around the flow's in-progress answers and navigation path (01-RESEARCH.md's
// Pattern 1). `advance`, `goBack`, and `open` are the ONLY ways the path changes.
//
// This class must contain no branching logic of its own. Adding an `if` on age, tier, or consent
// state to this class is a defect: it would place a routing decision outside the one function
// (`OnboardingRouter.nextStep`) that plan 01-07's tests exhaustively cover, which is exactly the
// kind of second branching authority CROSSGEN-05 forbids. Every next-step decision delegates
// wholly to the core router.
//
// `@MainActor` because SwiftUI reads `path` and `answers` from the main actor via `@Observable`
// and the single shared navigation container's path binding, and every call site (button actions
// inside step views) already runs on the main actor.
@MainActor
@Observable
final class OnboardingFlow {
    var answers: OnboardingAnswers
    var path: [OnboardingStep]

    /// The mode chosen on `CalibrationIntroView`, read by `CalibrationSessionView` (plan
    /// 01-15) to know which session to run. Deliberately NOT part of `OnboardingAnswers`
    /// (RithamCore): `OnboardingRouter.nextStep` never branches on which calibration mode was
    /// picked, only on `calibrationOutcome`, so this carries no routing consequence and does
    /// not belong in the `Codable`, persisted, branching-relevant answers aggregate. It is
    /// purely an in-session UI handoff between two screens this plan owns, scoped to the same
    /// in-memory lifetime as `path`/`answers` themselves -- storing it here is data, not the
    /// branching logic this class's own header comment forbids.
    var calibrationMode: CalibrationMode = .walk

    /// The activity type and capture mode chosen on `CardioActivityPickerView` (plan 02-10),
    /// read by `CardioSessionView` to know which activity/capture adapter to run. Deliberately
    /// NOT part of `OnboardingAnswers`, for the identical reason `calibrationMode` above is not:
    /// neither field ever changes what `OnboardingRouter.nextStep` returns -- Phase 2's cardio
    /// steps are reached only via `open(_:)`, never `advance`, and the router treats every one of
    /// them as terminal (`OnboardingStep.swift`'s header comment) -- so this is a pure in-session
    /// UI handoff between two screens this plan owns, not the branching logic this class's own
    /// header comment forbids. Scoped to the same in-memory lifetime as `path`/`answers`.
    var cardioActivityType: ActivityType = .run
    var cardioCaptureMode: CardioCaptureMode = .manual

    /// The group id chosen on `GroupListView` (plan 04.1-11), read by `GroupDetailView` to know
    /// which group to load. Deliberately NOT part of `OnboardingAnswers`, for the identical
    /// reason `calibrationMode`/`cardioActivityType` above are not: `OnboardingRouter.nextStep`
    /// never branches on which group is selected -- `.groupDetail` is reached only via `open(_:)`,
    /// never `advance`, and the router treats it as terminal exactly like every other Phase 4.1
    /// social surface -- so this is a pure in-session UI handoff between two screens this plan
    /// owns, not the branching logic this class's own header comment forbids. Defaults to `nil`
    /// and carries no navigation consequence of its own: setting it appends nothing to `path` by
    /// itself, and it shares the same in-memory, in-session lifetime as `path`/`answers`.
    var selectedGroupID: UUID?

    /// The Goal-Event id chosen or just created on `CreateGoalEventView`/a future Goal-Events list
    /// screen (plan 04.1-13), read by `GoalEventRSVPView` to know which event to load. Deliberately
    /// NOT part of `OnboardingAnswers`, for the identical reason `selectedGroupID` above is not:
    /// `OnboardingRouter.nextStep` never branches on which event is selected -- `.goalEventRSVP` is
    /// reached only via `open(_:)`, never `advance`, and the router treats it as terminal exactly
    /// like every other Phase 4.1 social surface -- so this is a pure in-session UI handoff between
    /// two screens this plan owns, not the branching logic this class's own header comment
    /// forbids. Defaults to `nil` and carries no navigation consequence of its own: setting it
    /// appends nothing to `path` by itself, and it shares the same in-memory, in-session lifetime
    /// as `path`/`answers`.
    var selectedGoalEventID: UUID?

    /// The Goal-Event id a completion is being logged against, set before opening
    /// `.completionLogging` (plan 04.1-14), read by `CompletionLoggingView` to know which event to
    /// submit its completion to. Deliberately NOT part of `OnboardingAnswers`, for the identical
    /// reason `selectedGoalEventID` above is not: `OnboardingRouter.nextStep` never branches on
    /// which event a completion is being logged against -- `.completionLogging` is reached only
    /// via `open(_:)`, never `advance`, and the router treats it as terminal exactly like every
    /// other Phase 4.1 social surface -- so this is a pure in-session UI handoff, not the branching
    /// logic this class's own header comment forbids. Defaults to `nil` and carries no navigation
    /// consequence of its own: setting it appends nothing to `path` by itself, and it shares the
    /// same in-memory, in-session lifetime as `path`/`answers`.
    var selectedCompletionEventID: UUID?

    init(answers: OnboardingAnswers = OnboardingAnswers(), path: [OnboardingStep] = []) {
        self.answers = answers
        self.path = path
    }

    /// Advances past `step` by delegating entirely to `OnboardingRouter.nextStep`. Appends the
    /// router's answer to `path` — nothing more.
    ///
    /// Two cases intentionally do NOT append, and neither is an age/tier/consent branch: a `nil`
    /// result (nothing follows `.home`) and a result equal to `step` itself. The latter is a pure
    /// step-identity comparison, not a condition on the answers — it exists because
    /// `OnboardingRouter.nextStep(after: .ageIneligible, answers:)` returns `.ageIneligible`
    /// again (the router's own "hold here" signal for a step that isn't going anywhere), and
    /// appending that on every call would grow the path unboundedly if the same "continue" action
    /// were tapped repeatedly.
    func advance(from step: OnboardingStep) {
        guard let next = OnboardingRouter.nextStep(after: step, answers: answers), next != step else {
            return
        }
        path.append(next)
    }

    /// Pops the most recent step. A no-op on an empty path.
    func goBack() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    /// Pops back to the interim hub (`.home`) by removing every step pushed above it. For a
    /// feature nested more than one level below the hub -- `CardioSessionView` is reached via
    /// `.cardioActivityPicker` then `.cardioSession` -- finishing wants to return all the way to
    /// the hub, not one level back like `goBack()`. A no-op when `.home` is not present in `path`.
    /// Still a plain path mutation with no branching decision in it, matching `open(_:)`'s own
    /// reasoning above.
    func returnToHub() {
        guard let homeIndex = path.lastIndex(of: .home) else { return }
        path.removeLast(path.count - homeIndex - 1)
    }

    /// A user-initiated push to `step`, with no routing decision in it. Phase 2's interim hub
    /// (`HomeHubView`) navigates to surfaces `OnboardingRouter` deliberately never routes into --
    /// cardio, strength, guidance, recommendations -- by calling this rather than `advance`,
    /// which only ever delegates to the router. This class's own header comment forbids
    /// branching logic; this method contains none, since it takes its destination as a parameter
    /// rather than deciding one from `answers`, age, or any other stored state. Appends `step`
    /// only when it is not already the last element, so repeatedly invoking the same hub action
    /// does not grow the path unboundedly.
    func open(_ step: OnboardingStep) {
        guard path.last != step else { return }
        path.append(step)
    }
}

// Later plans contribute a screen by conforming a type to `OnboardingStepPresenting` and calling
// `StepRegistry.register(_:)` — never by editing this switch-like lookup or adding a branch
// anywhere else. `view(for:flow:)` returns a clearly labelled placeholder for any step not yet
// registered so the app compiles and runs before every screen plan has landed; that fallback is
// not a stand-in for a real screen, and `unregisteredSteps` is asserted empty by the phase's final
// verification plan (01-18).
@MainActor
enum StepRegistry {
    private static var factories: [OnboardingStep: (OnboardingFlow) -> AnyView] = [:]

    /// Tracks the concrete `Presenter.Type` registered per step, alongside `factories`. Exists
    /// solely so tests can assert *which* real screen type backs a step -- `view(for:flow:)`
    /// alone can't answer that, since its `AnyView` return type-erases the presenter before
    /// returning. Plan 02-16's `Phase2CoverageTests` is the first consumer.
    private static var presenterTypes: [OnboardingStep: Any.Type] = [:]

    /// Registers `type` under its own `step`, overwriting any prior registration for that step.
    static func register<Presenter: OnboardingStepPresenting>(_ type: Presenter.Type) {
        factories[type.step] = { flow in type.makeView(flow: flow) }
        presenterTypes[type.step] = type
    }

    /// The concrete `OnboardingStepPresenting` conformer registered for `step`, if any.
    static func registeredPresenterType(for step: OnboardingStep) -> Any.Type? {
        presenterTypes[step]
    }

    /// Resolves the view for `step`. Never traps: an unregistered step gets a labelled
    /// placeholder instead of crashing the app mid-onboarding.
    static func view(for step: OnboardingStep, flow: OnboardingFlow) -> AnyView {
        if let factory = factories[step] {
            return factory(flow)
        }
        return AnyView(UnimplementedStepView(step: step))
    }

    /// Steps with no registered presenter. Every step will be registered by the end of the
    /// phase; 01-18's `PhaseCoverageTests` asserts this is empty.
    static var unregisteredSteps: [OnboardingStep] {
        OnboardingStep.allCases.filter { factories[$0] == nil }
    }

    /// Test-only: clears every registration so tests can run deterministically regardless of
    /// execution order. Never called from app code.
    static func reset() {
        factories = [:]
        presenterTypes = [:]
    }
}

private struct UnimplementedStepView: View {
    let step: OnboardingStep

    var body: some View {
        VStack(spacing: 8) {
            Text("Screen not yet implemented")
                .font(.headline)
            Text(step.rawValue)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
