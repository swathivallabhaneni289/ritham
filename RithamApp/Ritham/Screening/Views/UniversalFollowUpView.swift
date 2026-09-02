import SwiftUI
import RithamCore

/// §1.4's universal follow-up (U-1), shown to every user regardless of what else was
/// selected -- including a user who chose only "None of the above" -- so this view has no guard
/// on `flow.answers.screening.checklist` at all. The question asks only about recent inactivity;
/// it does not ask about age at all (live-review feedback, 2026-09-01, dropped a redundant
/// "are you 65 or older" clause -- see `ScreeningCopy.universalFollowUp`'s own comment). Per
/// §1.1's precedence rule, a "No" answer here never clears an age-derived
/// `65+ / Deconditioned / Returning After Inactivity` tag a user already holds from Q0
/// (age >= 65); `ConditionTag.ageDerivedTags`/`TagDerivation` already guarantee that
/// additive-only behavior, and this view has no logic of its own that could violate it.
///
/// On continue, resolves the complete screening result and persists it via
/// `HealthDataStore.saveScreeningResult` -- the last write the onboarding screening flow makes.
/// Every confirmed 13+ user reaches this screen with full, identical access; there is no consent
/// gate of any kind to satisfy first. A save failure surfaces the standard error copy instead of
/// crashing -- the router only reaches this step for a user who already passed the age floor (a
/// profile already exists by construction), so a failure here means something else upstream (a
/// storage error) is wrong, not a missing profile.
struct UniversalFollowUpView: View, OnboardingStepPresenting {
    static let step: OnboardingStep = .universalFollowUp

    static func makeView(flow: OnboardingFlow) -> AnyView {
        AnyView(UniversalFollowUpView(flow: flow))
    }

    let flow: OnboardingFlow
    @Environment(\.modelContext) private var modelContext
    @State private var selection: Set<YesNo>
    @State private var showSaveError = false

    init(flow: OnboardingFlow) {
        self.flow = flow
        _selection = State(initialValue: flow.answers.screening.u1ReturningAfterInactivity.map { [$0] } ?? [])
    }

    var body: some View {
        RithamScreen(surface: DecorativeSurface.flat) {
            ChoiceQuestionView(
                prompt: ScreeningCopy.universalFollowUp,
                options: YesNo.allCases,
                mode: .single,
                selection: $selection,
                optionTitle: yesNoTitle
            )

            if showSaveError {
                Text(OnboardingCopy.Errors.savingFailed)
                    .font(RithamType.label)
                    .foregroundStyle(RithamColor.hot)
                    .fixedSize(horizontal: false, vertical: true)
            }

            PrimaryCTAButton(title: OnboardingCopy.Age.cta) {
                flow.answers.screening.u1ReturningAfterInactivity = selection.first
                resolveAndSave()
            }
        }
    }

    private func resolveAndSave() {
        let result = GateResolution.resolve(
            answers: flow.answers.screening,
            ageDerivedTags: flow.answers.ageDerivedTags
        )
        let store = HealthDataStore(context: modelContext)
        do {
            try store.saveScreeningResult(result, answers: flow.answers.screening, now: Date())
            showSaveError = false
            flow.advance(from: .universalFollowUp)
        } catch {
            showSaveError = true
        }
    }

    private func yesNoTitle(_ option: YesNo) -> String {
        switch option {
        case .yes: return "Yes"
        case .no: return "No"
        }
    }
}
