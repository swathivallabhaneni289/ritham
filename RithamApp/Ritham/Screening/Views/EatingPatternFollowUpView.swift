import SwiftUI
import RithamCore

/// §1.4's eating-disorder-history follow-up (SCOFF, ED-1 through ED-5) and §1.5's governing
/// constraint on what this screen may ever show.
///
/// §1.5 forbids surfacing a numeric score, a count of "yes" answers, a positive/negative result,
/// a progress indicator implying a threshold, or any word naming a clinical diagnosis. This view
/// renders only `ScreeningCopy.scoffIntro` and the five fixed-choice questions -- nothing else.
/// Plan 01-03 already removed the means to violate this: `SCOFFResponses` has no
/// `CustomStringConvertible` conformance and no display-name property, and its `yesCount` /
/// `isPositiveScreen` members are engine-internal -- neither is ever bound to a view here or
/// anywhere else in this file. The intro copy promises the user's individual answers are never
/// shown back as a score or a label; that promise must hold literally in any summary, review, or
/// edit surface built later, not just on this screen.
///
/// This screen is reachable only when the eating-disorder-history checklist item was selected
/// (D-10) -- `OnboardingRouter.nextStep` already enforces that from `.severityFollowUps`. This
/// view has no guard of its own on the checklist selection and is never presented from anywhere
/// but the routed `.scoffFollowUp` step.
///
/// The five answers are not persisted individually -- plan 01-11 stores only the derived
/// eating-disorder outcome. This view hands the responses to `flow.answers.screening.scoff`;
/// `UniversalFollowUpView` (the flow's final screening step) is what calls
/// `GateResolution.resolve` and `HealthDataStore.saveScreeningResult`, so only the resolved
/// result -- never the raw five answers -- ever reaches durable storage.
struct EatingPatternFollowUpView: View, OnboardingStepPresenting {
    static let step: OnboardingStep = .scoffFollowUp

    static func makeView(flow: OnboardingFlow) -> AnyView {
        AnyView(EatingPatternFollowUpView(flow: flow))
    }

    let flow: OnboardingFlow
    @State private var ed1: Set<YesNo>
    @State private var ed2: Set<YesNo>
    @State private var ed3: Set<YesNo>
    @State private var ed4: Set<YesNo>
    @State private var ed5: Set<YesNo>

    init(flow: OnboardingFlow) {
        self.flow = flow
        let existing = flow.answers.screening.scoff
        _ed1 = State(initialValue: existing.map { [$0.ed1MakesSelfSickWhenFull] } ?? [])
        _ed2 = State(initialValue: existing.map { [$0.ed2WorriesLostControlOverEating] } ?? [])
        _ed3 = State(initialValue: existing.map { [$0.ed3RecentSignificantWeightLoss] } ?? [])
        _ed4 = State(initialValue: existing.map { [$0.ed4BelievesSelfFatWhenToldTooThin] } ?? [])
        _ed5 = State(initialValue: existing.map { [$0.ed5FoodDominatesLife] } ?? [])
    }

    private var isComplete: Bool {
        !ed1.isEmpty && !ed2.isEmpty && !ed3.isEmpty && !ed4.isEmpty && !ed5.isEmpty
    }

    var body: some View {
        RithamScreen(surface: DecorativeSurface.flat, bodyText: ScreeningCopy.scoffIntro) {
            ChoiceQuestionView(
                prompt: ScreeningCopy.EatingPattern.ed1,
                options: YesNo.allCases,
                mode: .single,
                selection: $ed1,
                optionTitle: yesNoTitle
            )

            ChoiceQuestionView(
                prompt: ScreeningCopy.EatingPattern.ed2,
                options: YesNo.allCases,
                mode: .single,
                selection: $ed2,
                optionTitle: yesNoTitle
            )

            ChoiceQuestionView(
                prompt: ScreeningCopy.EatingPattern.ed3,
                options: YesNo.allCases,
                mode: .single,
                selection: $ed3,
                optionTitle: yesNoTitle
            )

            ChoiceQuestionView(
                prompt: ScreeningCopy.EatingPattern.ed4,
                options: YesNo.allCases,
                mode: .single,
                selection: $ed4,
                optionTitle: yesNoTitle
            )

            ChoiceQuestionView(
                prompt: ScreeningCopy.EatingPattern.ed5,
                options: YesNo.allCases,
                mode: .single,
                selection: $ed5,
                optionTitle: yesNoTitle
            )

            PrimaryCTAButton(title: OnboardingCopy.Age.cta) {
                guard
                    let a1 = ed1.first, let a2 = ed2.first, let a3 = ed3.first,
                    let a4 = ed4.first, let a5 = ed5.first
                else { return }
                flow.answers.screening.scoff = SCOFFResponses(
                    ed1MakesSelfSickWhenFull: a1,
                    ed2WorriesLostControlOverEating: a2,
                    ed3RecentSignificantWeightLoss: a3,
                    ed4BelievesSelfFatWhenToldTooThin: a4,
                    ed5FoodDominatesLife: a5
                )
                flow.advance(from: .scoffFollowUp)
            }
            .disabled(!isComplete)
        }
    }

    private func yesNoTitle(_ option: YesNo) -> String {
        switch option {
        case .yes: return "Yes"
        case .no: return "No"
        }
    }
}
