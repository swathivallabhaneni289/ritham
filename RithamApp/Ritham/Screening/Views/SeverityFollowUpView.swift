import SwiftUI
import RithamCore

// `BloodPressureControl`/`RhythmControl`/`SurgicalClearance`/`PostpartumWeeks` need
// `Identifiable` to drive `ChoiceQuestionView`'s `ForEach` -- this view is their first consumer
// in this plan (`YesNo`/`YesNoUnsure` were already declared once in `GateSectionView.swift`).
extension BloodPressureControl: @retroactive Identifiable {
    public var id: Self { self }
}

extension RhythmControl: @retroactive Identifiable {
    public var id: Self { self }
}

extension SurgicalClearance: @retroactive Identifiable {
    public var id: Self { self }
}

extension PostpartumWeeks: @retroactive Identifiable {
    public var id: Self { self }
}

/// One data-driven follow-up question from §1.4: a prompt, the applicability predicate that
/// decides whether it renders at all (the nested per-item conditions -- CV-2 only when "High
/// blood pressure" is checked, MSK-2 only when "prior injury or surgery" is checked, and so on),
/// and a closure that builds its `ChoiceQuestionView` bound to the right `ScreeningAnswers`
/// field. Not `private` -- `SeverityFollowUpView.questionsByCategory` is kept inspectable and
/// testable, per this plan's own instruction, rather than folded into eight separate view bodies.
struct SeverityQuestion: Identifiable {
    let id: String
    let isApplicable: (ChecklistSelection) -> Bool
    // `@MainActor` explicitly, not inferred: `ChoiceQuestionView` (a `View`) has a main-actor-
    // isolated initializer, and this closure is built inside `severityQuestion`, a plain
    // top-level (non-isolated) function -- without the annotation, Swift 6 strict concurrency
    // flags the generic `options`/`optionTitle` captures as an unproven cross-actor send. The
    // closure itself is only ever invoked from `SeverityFollowUpView.body`, already MainActor.
    let makeView: @MainActor (OnboardingFlow) -> AnyView
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

/// Builds one `SeverityQuestion` for any of this screen's option types, binding directly to a
/// `ScreeningAnswers` field via key path -- the mechanism that keeps the question list genuinely
/// data (one call site per question) instead of eight hand-built view bodies.
@MainActor
private func severityQuestion<Option: Hashable & Identifiable & Sendable>(
    id: String,
    prompt: String,
    options: [Option],
    optionTitle: @escaping @Sendable (Option) -> String,
    keyPath: WritableKeyPath<ScreeningAnswers, Option?>,
    isApplicable: @escaping (ChecklistSelection) -> Bool
) -> SeverityQuestion {
    SeverityQuestion(id: id, isApplicable: isApplicable) { flow in
        AnyView(
            ChoiceQuestionView(
                prompt: prompt,
                options: options,
                mode: .single,
                selection: Binding(
                    get: { flow.answers.screening[keyPath: keyPath].map { [$0] } ?? [] },
                    set: { flow.answers.screening[keyPath: keyPath] = $0.first }
                ),
                optionTitle: optionTitle
            )
        )
    }
}

private func hasAnyItem(in category: ChecklistCategory, _ checklist: ChecklistSelection) -> Bool {
    checklist.items.contains { $0.category == category }
}

/// §1.4: any Metabolic tag *except* Prediabetes alone needs M-1/M-2.
private func metabolicNeedsFollowUp(_ checklist: ChecklistSelection) -> Bool {
    let metabolicItems = checklist.items.filter { $0.category == .metabolic }
    guard !metabolicItems.isEmpty else { return false }
    return metabolicItems != [.prediabetes]
}

/// §1.4's severity/context follow-ups, covering seven applicable category groups
/// (cardiovascular, metabolic, musculoskeletal, pregnancy, postpartum, kidney, other serious
/// condition -- eating-disorder-history's follow-up is the separate SCOFF screen, and the
/// universal U-1 follow-up is `UniversalFollowUpView`, neither of which belongs here) as one
/// data-driven screen rather than seven hand-built ones.
///
/// Food allergies' FA-1 severity question used to live here too. It moved to `DietPlanView`
/// (Settings) alongside the rest of the allergy question set -- further live-review feedback
/// (2026-09-02) -- since the checklist item that gated it (`ChecklistItem.foodAllergies`) no
/// longer exists on the screening checklist at all; see `ConditionChecklistView`'s and
/// `DietPlanView`'s own header comments for the full story. `fa1SevereAllergyOrEpinephrine` and
/// the safety tag it feeds are unchanged, only asked from a different screen now.
struct SeverityFollowUpView: View, OnboardingStepPresenting {
    static let step: OnboardingStep = .severityFollowUps

    static func makeView(flow: OnboardingFlow) -> AnyView {
        AnyView(SeverityFollowUpView(flow: flow))
    }

    let flow: OnboardingFlow

    /// Doc order, §1.4: cardiovascular, metabolic, musculoskeletal/joint, pregnancy, postpartum,
    /// kidney/renal, other serious condition. A plain array (not `questionsByCategory.keys`,
    /// which has no stable order) so rendering order matches the doc.
    static let categoryOrder: [ChecklistCategory] = [
        .cardiovascular, .metabolic, .musculoskeletalJoint, .pregnancy, .postpartum,
        .kidneyRenal, .otherSeriousCondition,
    ]

    /// The question list, keyed by `ChecklistCategory` so the category-to-questions mapping is
    /// inspectable and testable, and so a future follow-up is a data change here rather than a
    /// new view.
    static let questionsByCategory: [ChecklistCategory: [SeverityQuestion]] = [
        .cardiovascular: [
            severityQuestion(
                id: "cv1", prompt: ScreeningCopy.FollowUp.cv1, options: YesNo.allCases,
                optionTitle: yesNoTitle, keyPath: \.cv1RecentCardiacEvent,
                isApplicable: { hasAnyItem(in: .cardiovascular, $0) }
            ),
            severityQuestion(
                id: "cv2", prompt: ScreeningCopy.FollowUp.cv2, options: BloodPressureControl.allCases,
                optionTitle: { option in
                    switch option {
                    case .wellControlled: return ScreeningCopy.FollowUp.cv2OptionWellControlled
                    case .notSureOrNotChecked: return ScreeningCopy.FollowUp.cv2OptionNotSureOrNotChecked
                    case .doctorSaysHigh: return ScreeningCopy.FollowUp.cv2OptionDoctorSaysHigh
                    }
                },
                keyPath: \.cv2BloodPressureControl,
                isApplicable: { $0.items.contains(.highBloodPressure) }
            ),
            severityQuestion(
                id: "cv2b", prompt: ScreeningCopy.FollowUp.cv2b, options: RhythmControl.allCases,
                optionTitle: { option in
                    switch option {
                    case .yes: return "Yes"
                    case .notSure: return "Not sure"
                    case .no: return "No"
                    }
                },
                keyPath: \.cv2bRhythmControl,
                isApplicable: { $0.items.contains(.irregularHeartbeat) }
            ),
        ],
        .metabolic: [
            severityQuestion(
                id: "m1", prompt: ScreeningCopy.FollowUp.m1, options: YesNoUnsure.allCases,
                optionTitle: yesNoUnsureTitle, keyPath: \.m1InsulinOrHypoglycemiaRiskMedication,
                isApplicable: metabolicNeedsFollowUp
            ),
            severityQuestion(
                id: "m2", prompt: ScreeningCopy.FollowUp.m2, options: YesNoUnsure.allCases,
                optionTitle: yesNoUnsureTitle, keyPath: \.m2RetinopathyNeuropathyOrFootWound,
                isApplicable: metabolicNeedsFollowUp
            ),
        ],
        .musculoskeletalJoint: [
            severityQuestion(
                id: "msk1", prompt: ScreeningCopy.FollowUp.msk1, options: YesNo.allCases,
                optionTitle: yesNoTitle, keyPath: \.msk1CurrentFlare,
                isApplicable: { hasAnyItem(in: .musculoskeletalJoint, $0) }
            ),
            severityQuestion(
                id: "msk2", prompt: ScreeningCopy.FollowUp.msk2, options: SurgicalClearance.allCases,
                optionTitle: { option in
                    switch option {
                    case .fullyCleared: return ScreeningCopy.FollowUp.msk2OptionFullyCleared
                    case .stillInRecoveryNotCleared: return ScreeningCopy.FollowUp.msk2OptionStillInRecoveryNotCleared
                    case .notApplicable: return ScreeningCopy.FollowUp.msk2OptionNotApplicable
                    }
                },
                keyPath: \.msk2SurgicalClearance,
                isApplicable: { $0.items.contains(.priorInjuryOrSurgery) }
            ),
        ],
        .pregnancy: [
            severityQuestion(
                id: "pg1", prompt: ScreeningCopy.FollowUp.pg1, options: YesNoUnsure.allCases,
                optionTitle: yesNoUnsureTitle, keyPath: \.pg1PregnancyComplications,
                isApplicable: { $0.items.contains(.currentlyPregnant) }
            ),
        ],
        .postpartum: [
            severityQuestion(
                id: "pp1", prompt: ScreeningCopy.FollowUp.pp1, options: YesNo.allCases,
                optionTitle: yesNoTitle, keyPath: \.pp1CSectionOrDeliveryComplications,
                isApplicable: { $0.items.contains(.postpartum) }
            ),
            severityQuestion(
                id: "pp2", prompt: ScreeningCopy.FollowUp.pp2, options: PostpartumWeeks.allCases,
                optionTitle: { option in
                    switch option {
                    case .underSix: return ScreeningCopy.FollowUp.pp2OptionUnderSix
                    case .sixToTwelve: return ScreeningCopy.FollowUp.pp2OptionSixToTwelve
                    case .overTwelve: return ScreeningCopy.FollowUp.pp2OptionOverTwelve
                    }
                },
                keyPath: \.pp2WeeksPostpartum,
                isApplicable: { $0.items.contains(.postpartum) }
            ),
        ],
        .kidneyRenal: [
            severityQuestion(
                id: "kr1", prompt: ScreeningCopy.FollowUp.kr1, options: YesNo.allCases,
                optionTitle: yesNoTitle, keyPath: \.kr1CurrentlyOnDialysis,
                isApplicable: { hasAnyItem(in: .kidneyRenal, $0) }
            ),
            severityQuestion(
                id: "kr2", prompt: ScreeningCopy.FollowUp.kr2, options: YesNoUnsure.allCases,
                optionTitle: yesNoUnsureTitle, keyPath: \.kr2SpecificDietaryLimits,
                isApplicable: { hasAnyItem(in: .kidneyRenal, $0) }
            ),
        ],
        .otherSeriousCondition: [
            severityQuestion(
                id: "os1", prompt: ScreeningCopy.FollowUp.os1, options: YesNo.allCases,
                optionTitle: yesNoTitle, keyPath: \.os1NewDiagnosisOrTreatmentChange,
                isApplicable: { hasAnyItem(in: .otherSeriousCondition, $0) }
            ),
        ],
    ]

    var body: some View {
        RithamScreen(surface: DecorativeSurface.flat) {
            ForEach(Self.categoryOrder, id: \.self) { category in
                ForEach(Self.questionsByCategory[category] ?? []) { question in
                    if question.isApplicable(flow.answers.screening.checklist) {
                        question.makeView(flow)
                    }
                }
            }

            PrimaryCTAButton(title: OnboardingCopy.Age.cta) {
                flow.advance(from: .severityFollowUps)
            }
        }
    }
}
