import SwiftUI
import SwiftData
import RithamCore

// DIET-01: `DietaryPattern` needs `Identifiable` to drive `ChoiceQuestionView`'s `ForEach`
// without a separate id parameter -- the same retroactive-conformance pattern
// `ChoiceQuestionView.swift` applies to `ChecklistItem`. `DietaryPattern` is already
// `Hashable` (raw-value-backed `CaseIterable` enums get that automatically); only
// `Identifiable` is missing.
extension DietaryPattern: @retroactive Identifiable {
    public var id: Self { self }
}

/// DIET-01: `dietary_pattern` -- Q0b -- is collected unconditionally, directly after age, for
/// every user who clears the 13+ floor. `OnboardingRouter` already sequences that
/// (`.age`/`.ageIneligible` -> `.dietaryPattern` -> `.privacyExplainer`), so this view simply
/// advances after persisting.
///
/// The helper copy tells the user this choice "only affects example foods later -- never your
/// health screening." That is DIET-01's isolation rule, and this file keeps it structurally:
/// the chosen pattern is written to the profile only, and this file must never call
/// `GateResolution`, read a `ConditionTag`, or pass the pattern to anything that does.
///
/// This step is unreachable unless age eligibility already cleared (the router only routes here
/// from `.age` when `isAgeEligible == true`), so a profile already exists by the time this view
/// can render -- `AgeStepView` created it. Persisting reads the profile's existing age back and
/// passes it through unchanged, since `UserProfileDraft` always requires an age value.
struct DietaryPatternStepView: View, OnboardingStepPresenting {
    static let step: OnboardingStep = .dietaryPattern

    static func makeView(flow: OnboardingFlow) -> AnyView {
        AnyView(DietaryPatternStepView(flow: flow))
    }

    let flow: OnboardingFlow
    @State private var selection: Set<DietaryPattern>
    @Environment(\.modelContext) private var modelContext

    init(flow: OnboardingFlow) {
        self.flow = flow
        _selection = State(initialValue: [flow.answers.dietaryPattern ?? .none])
    }

    var body: some View {
        RithamScreen(surface: DecorativeSurface.flat) {
            ChoiceQuestionView(
                prompt: OnboardingCopy.Diet.headline,
                helper: OnboardingCopy.Diet.helper,
                options: DietaryPattern.allCases,
                mode: .single,
                selection: $selection,
                optionTitle: optionTitle
            )

            // OnboardingCopy.Diet has no dedicated `cta` constant (01-UI-SPEC.md's Copywriting
            // Contract lists no CTA row for Q0b) -- reusing Age's already-locked "Continue"
            // string keeps every visible string resolving through OnboardingCopy rather than
            // inventing new, unreviewed copy.
            PrimaryCTAButton(title: OnboardingCopy.Age.cta) {
                guard let chosen = selection.first else { return }
                flow.answers.dietaryPattern = chosen
                persist(chosen)
                flow.advance(from: .dietaryPattern)
            }
        }
    }

    private func optionTitle(_ pattern: DietaryPattern) -> String {
        switch pattern {
        case .none: return OnboardingCopy.Diet.optionNone
        case .vegetarian: return OnboardingCopy.Diet.optionVegetarian
        case .vegan: return OnboardingCopy.Diet.optionVegan
        }
    }

    private func persist(_ pattern: DietaryPattern) {
        let store = HealthDataStore(context: modelContext)
        guard let existingAge = try? store.loadProfile().age else { return }
        try? store.updateProfile(UserProfileDraft(age: existingAge, dietaryPattern: pattern))
    }
}
