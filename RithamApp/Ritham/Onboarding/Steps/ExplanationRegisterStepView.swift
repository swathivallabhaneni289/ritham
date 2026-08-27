import SwiftUI
import SwiftData
import RithamCore

// EXPLAIN-01: `ExplanationRegister` needs `Identifiable` to drive `ChoiceQuestionView`'s
// `ForEach` without a separate id parameter -- the same retroactive-conformance pattern
// 01-12-SUMMARY.md documents for `ChecklistItem` (its Deviation #2). Declared once here, this
// type's one UI-layer consumer in this wave. `ExplanationRegister` is already `Hashable`
// (raw-value-backed `CaseIterable` enums get that automatically) -- only `Identifiable` is
// missing.
extension ExplanationRegister: @retroactive Identifiable {
    public var id: Self { self }
}

/// EXPLAIN-01's register choice.
///
/// Persisting is deferred rather than unconditional: no `UserProfile` exists yet the *first*
/// time a user reaches this screen -- it comes before `.age` in the flow, and
/// `UserProfileDraft.age` is required (non-optional). `HealthDataStore.updateProfile`'s own doc
/// comment names the age step as "the very first write" for exactly this reason. So this view
/// only writes through `HealthDataStore` when a profile already exists (a later visit after Age
/// has run, or a Settings edit reusing this same screen, per plan 01-17); on the very first
/// pass, the choice lives in `flow.answers.register` only, and `AgeStepView` folds it into its
/// own first-ever `updateProfile` call. Either way the choice reaches durable storage no later
/// than the moment onboarding clears the age floor -- EXPLAIN-01's "persists" promise is kept,
/// just not by this file alone. The helper copy promises the choice can be changed at any time
/// in Settings, so this view never disables the control once a selection is made.
struct ExplanationRegisterStepView: View, OnboardingStepPresenting {
    static let step: OnboardingStep = .explanationRegister

    static func makeView(flow: OnboardingFlow) -> AnyView {
        AnyView(ExplanationRegisterStepView(flow: flow))
    }

    let flow: OnboardingFlow
    @State private var selection: Set<ExplanationRegister>
    @Environment(\.modelContext) private var modelContext

    init(flow: OnboardingFlow) {
        self.flow = flow
        _selection = State(initialValue: [flow.answers.register ?? .plainLanguage])
    }

    var body: some View {
        RithamScreen(surface: DecorativeSurface.boundedHeaderOnly) {
            ChoiceQuestionView(
                prompt: OnboardingCopy.Register.headline,
                helper: OnboardingCopy.Register.helper,
                options: ExplanationRegister.allCases,
                mode: .single,
                selection: $selection,
                optionTitle: { $0.optionLabel }
            )

            PrimaryCTAButton(title: OnboardingCopy.Register.cta) {
                guard let chosen = selection.first else { return }
                flow.answers.register = chosen
                persistIfProfileExists(chosen)
                flow.advance(from: .explanationRegister)
            }
        }
    }

    private func persistIfProfileExists(_ register: ExplanationRegister) {
        let store = HealthDataStore(context: modelContext)
        guard let existingAge = try? store.loadProfile().age else { return }
        try? store.updateProfile(UserProfileDraft(age: existingAge, explanationRegister: register))
    }
}
