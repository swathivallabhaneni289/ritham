import SwiftUI
import RithamCore

// §1.2's PAR-Q-style gate section: G1-G7 and the two immediate MED-1/MED-2 follow-ups.
// `YesNo`/`YesNoUnsure` need `Identifiable` to drive
// `ChoiceQuestionView`'s `ForEach` without a separate id parameter -- neither conforms in
// RithamCore, since Identifiable is a UI-layer concern (same rationale `ChecklistItem`'s
// retroactive conformance in `ChoiceQuestionView.swift` already documents). Declared once here,
// this plan's first consumer of either type -- every other screening view in this plan that also
// needs `YesNo`/`YesNoUnsure` (SeverityFollowUpView, EatingPatternFollowUpView,
// UniversalFollowUpView) sees this same module-wide conformance and must not redeclare it.
extension YesNo: @retroactive Identifiable {
    public var id: Self { self }
}

extension YesNoUnsure: @retroactive Identifiable {
    public var id: Self { self }
}

/// §1.2's gate section. Every branching decision (which step follows, which clearance
/// interstitial variant applies) is delegated entirely to `OnboardingRouter`/`GateResolution` --
/// this view only collects answers and reads `GateResolution.resolve`'s already-computed
/// `interstitial` value to decide whether to show the gate-pass affirmation before advancing.
///
/// The section heading renders `ScreeningCopy.gateSectionFraming` as the body, with
/// `ScreeningCopy.gateSectionHeadline` as a plain-text headline added 2026-09-01 (live-review
/// feedback: the screen had none). Neither is decorative -- `DecorativeSurface.flat` still
/// applies (this is one of the nine screens 01-UI-SPEC.md's Decorative Surface Inventory locks
/// flat, since it collects health data directly), so no band/arc/halftone is ever added here; a
/// plain-text headline doesn't touch that rule, matching the precedent `AgeStepView` already sets
/// for headlines on a flat-locked screen. 01-UI-SPEC.md flags the framing copy as a legal
/// constraint (it must not name the branded clinical instrument the questions are modelled on)
/// pending LAUNCH-01 counsel review, and `ScreeningCopyTests` already pins that the framing
/// string is free of that name.
///
/// This screen no longer shows a dedicated emergency-line callout (removed 2026-09-01, product
/// decision after live-review feedback that it visually dominated the top of the screen even
/// after a first pass compacted it). `GateEscalation.showsEmergencyLine(for: .gate)` now returns
/// `false` -- that domain-layer change, not a UI-only omission, is what this view obeys, so the
/// rule and the rendered screen cannot drift apart. The opening disclaimer (shown one screen
/// earlier) still carries the same "call your local emergency number" instruction inline in its
/// body text, and the urgent clearance interstitial still shows it as a dedicated callout when
/// G2/G3 = yes -- see `GateEscalation.showsEmergencyLine`'s own doc comment for the full record.
struct GateSectionView: View, OnboardingStepPresenting {
    static let step: OnboardingStep = .gateSection

    static func makeView(flow: OnboardingFlow) -> AnyView {
        AnyView(GateSectionView(flow: flow))
    }

    let flow: OnboardingFlow
    @State private var showGatePassAffirmation = false

    var body: some View {
        RithamScreen(
            surface: DecorativeSurface.flat,
            headline: ScreeningCopy.gateSectionHeadline,
            bodyText: ScreeningCopy.gateSectionFraming
        ) {
            ChoiceQuestionView(
                prompt: ScreeningCopy.Gate.g1,
                options: YesNo.allCases,
                mode: .single,
                selection: yesNoBinding(\.g1HeartConditionOrHighBP),
                optionTitle: yesNoTitle
            )

            ChoiceQuestionView(
                prompt: ScreeningCopy.Gate.g2,
                options: YesNo.allCases,
                mode: .single,
                selection: yesNoBinding(\.g2ChestPainOrBreathlessness),
                optionTitle: yesNoTitle
            )

            ChoiceQuestionView(
                prompt: ScreeningCopy.Gate.g3,
                helper: ScreeningCopy.Gate.g3Clarification,
                options: YesNo.allCases,
                mode: .single,
                selection: yesNoBinding(\.g3DizzinessOrLossOfConsciousness),
                optionTitle: yesNoTitle
            )

            ChoiceQuestionView(
                prompt: ScreeningCopy.Gate.g4,
                options: YesNo.allCases,
                mode: .single,
                selection: yesNoBinding(\.g4OtherOngoingCondition),
                optionTitle: yesNoTitle
            )

            ChoiceQuestionView(
                prompt: ScreeningCopy.Gate.g5,
                options: YesNo.allCases,
                mode: .single,
                selection: yesNoBinding(\.g5MedicationOrPrescribedDiet),
                optionTitle: yesNoTitle
            )

            // MED-1/MED-2 reveal immediately and inline when G5 = Yes, per §1.2. The `.onChange`
            // below clears both the moment G5 is changed back to "No", so a retracted answer can
            // never reach `GateResolution.resolve` (T-01-95).
            if flow.answers.screening.g5MedicationOrPrescribedDiet == .yes {
                ChoiceQuestionView(
                    prompt: ScreeningCopy.Gate.med1,
                    options: YesNoUnsure.allCases,
                    mode: .single,
                    selection: yesNoUnsureBinding(\.med1RateLimitingHeartOrBPMedication),
                    optionTitle: yesNoUnsureTitle
                )

                ChoiceQuestionView(
                    prompt: ScreeningCopy.Gate.med2,
                    options: YesNo.allCases,
                    mode: .single,
                    selection: yesNoBinding(\.med2ClinicianPrescribedDietOrMealPlan),
                    optionTitle: yesNoTitle
                )
            }

            ChoiceQuestionView(
                prompt: ScreeningCopy.Gate.g6,
                options: YesNo.allCases,
                mode: .single,
                selection: yesNoBinding(\.g6BoneJointSoftTissueProblem),
                optionTitle: yesNoTitle
            )

            ChoiceQuestionView(
                prompt: ScreeningCopy.Gate.g7,
                options: YesNo.allCases,
                mode: .single,
                selection: yesNoBinding(\.g7MedicallySupervisedOnly),
                optionTitle: yesNoTitle
            )

            PrimaryCTAButton(title: OnboardingCopy.Age.cta) {
                // The resolver -- not a hand-rolled "any G yes" check in this view -- decides
                // whether the gate-pass affirmation applies. `OnboardingRouter.nextStep` makes
                // the identical determination independently when `flow.advance` runs below, so
                // both reads agree by construction (same source fields, same "any yes" rule).
                let result = GateResolution.resolve(
                    answers: flow.answers.screening,
                    ageDerivedTags: flow.answers.ageDerivedTags
                )
                if result.interstitial == .none {
                    showGatePassAffirmation = true
                } else {
                    flow.advance(from: .gateSection)
                }
            }
        }
        .onChange(of: flow.answers.screening.g5MedicationOrPrescribedDiet) { _, newValue in
            guard newValue != .yes else { return }
            flow.answers.screening.med1RateLimitingHeartOrBPMedication = nil
            flow.answers.screening.med2ClinicianPrescribedDietOrMealPlan = nil
        }
        .alert(ScreeningCopy.gatePassAffirmation, isPresented: $showGatePassAffirmation) {
            Button(OnboardingCopy.Age.cta) {
                flow.advance(from: .gateSection)
            }
        }
    }

    private func yesNoBinding(_ keyPath: WritableKeyPath<ScreeningAnswers, YesNo?>) -> Binding<Set<YesNo>> {
        Binding(
            get: { flow.answers.screening[keyPath: keyPath].map { [$0] } ?? [] },
            set: { flow.answers.screening[keyPath: keyPath] = $0.first }
        )
    }

    private func yesNoUnsureBinding(_ keyPath: WritableKeyPath<ScreeningAnswers, YesNoUnsure?>) -> Binding<Set<YesNoUnsure>> {
        Binding(
            get: { flow.answers.screening[keyPath: keyPath].map { [$0] } ?? [] },
            set: { flow.answers.screening[keyPath: keyPath] = $0.first }
        )
    }

    private func yesNoTitle(_ option: YesNo) -> String {
        switch option {
        case .yes: return "Yes"
        case .no: return "No"
        }
    }

    private func yesNoUnsureTitle(_ option: YesNoUnsure) -> String {
        switch option {
        case .yes: return "Yes"
        case .no: return "No"
        case .notSure: return "Not sure"
        }
    }
}
