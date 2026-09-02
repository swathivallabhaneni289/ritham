import SwiftUI
import SwiftData
import RithamCore

/// `EditAnswerFlow`/`SettingsView`'s first consumer of `EditableSection` as a `.sheet(item:)`
/// identity -- the same retroactive-`Identifiable` pattern `ChecklistItem`/`DietaryPattern`
/// already use at their own first UI-layer consumer.
extension EditableSection: @retroactive Identifiable {
    public var id: Self { self }
}

// DIET-01: `DietaryPattern` needs `Identifiable` to drive `ChoiceQuestionView`'s `ForEach`
// without a separate id parameter -- the same retroactive-conformance pattern above applies.
// `DietaryPattern` is already `Hashable` (raw-value-backed `CaseIterable` enums get that
// automatically); only `Identifiable` is missing. This conformance used to live in
// `DietaryPatternStepView.swift`, the onboarding screen for this question -- per direct product
// feedback (2026-08-29) that question moved out of onboarding entirely (see
// `OnboardingRouter`'s doc comment), making this view its sole remaining consumer.
extension DietaryPattern: @retroactive Identifiable {
    public var id: Self { self }
}

// Same reasoning as `DietaryPattern` above, for the allergens picker this view also renders.
extension FoodAllergen: @retroactive Identifiable {
    public var id: Self { self }
}

/// The diet plan (DIET-01's dietary-pattern choice plus the allergens picker) is opened as its
/// own screen via `DietPlanView`, a `.sheet`, rather than shown inline here -- direct product
/// feedback (2026-09-01): the two pickers belong together on a screen the user opens, not
/// spilled across this main Settings list. `DietaryPattern`/`FoodAllergen`'s `Identifiable`
/// conformances stay declared in this file since `DietPlanView` needs them and this is their
/// first UI-layer consumer.
///
/// Also offers an entry point to the health profile, plus one per-section entry point for each
/// of the four screening sections (`.gateSection`, `.conditionChecklist`, `.severityFollowUps`,
/// `.scoff`), each routed through `EditAnswerFlow` as a `.sheet` -- D-09 scopes each of those
/// edits to its own section, never the whole questionnaire, and CROSSGEN-05 reserves the app's
/// one `NavigationStack` for `OnboardingRootView`, so a section edit here is always a sheet,
/// never a push.
struct SettingsView: View {
    let flow: OnboardingFlow
    var onOpenHealthProfile: () -> Void = {}

    @Environment(\.modelContext) private var modelContext
    @State private var editingSection: EditableSection?
    @State private var isEditingDietPlan = false
    @State private var isReScreenDue = false

    init(flow: OnboardingFlow, onOpenHealthProfile: @escaping () -> Void = {}) {
        self.flow = flow
        self.onOpenHealthProfile = onOpenHealthProfile
    }

    var body: some View {
        RithamScreen(surface: DecorativeSurface.flat, headline: "Settings") {
            // D-07: shown when overdue, non-blocking, dismissible for the session. "Start
            // re-screen" opens the gate section -- the first screen of the real screening --
            // through the same section-scoped `EditAnswerFlow` every other entry point here
            // uses; this plan builds no separate full-questionnaire restart wizard.
            ReScreenBanner(isReScreenDue: isReScreenDue) {
                editingSection = .gateSection
            }

            SecondaryCTAButton(title: "Diet plan") {
                isEditingDietPlan = true
            }

            SecondaryCTAButton(title: "Health profile", action: onOpenHealthProfile)

            VStack(alignment: .leading, spacing: RithamSpacing.sm) {
                Text("Screening answers")
                    .font(RithamType.heading)
                    .foregroundStyle(RithamColor.paper)

                sectionEntryPoint(.gateSection, title: "Health questions")
                sectionEntryPoint(.conditionChecklist, title: "Condition checklist")
                sectionEntryPoint(.severityFollowUps, title: "Follow-up questions")
                sectionEntryPoint(.scoff, title: "Eating-pattern questions")
            }
        }
        .onAppear(perform: refreshReScreenDue)
        .sheet(item: $editingSection) { section in
            EditAnswerFlow(flow: flow, section: section)
                .onDisappear(perform: refreshReScreenDue)
        }
        .sheet(isPresented: $isEditingDietPlan) {
            DietPlanView(flow: flow)
        }
    }

    private func sectionEntryPoint(_ section: EditableSection, title: String) -> some View {
        SecondaryCTAButton(title: title) {
            editingSection = section
        }
    }

    private func refreshReScreenDue() {
        let store = HealthDataStore(context: modelContext)
        isReScreenDue = (try? store.isReScreenDue(now: Date())) ?? false
    }
}
