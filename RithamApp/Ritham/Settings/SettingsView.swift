import SwiftUI
import SwiftData
import RithamCore

/// `EditAnswerFlow`/`SettingsView`'s first consumer of `EditableSection` as a `.sheet(item:)`
/// identity -- the same retroactive-`Identifiable` pattern `ChecklistItem`/`DietaryPattern`
/// already use at their own first UI-layer consumer.
extension EditableSection: @retroactive Identifiable {
    public var id: Self { self }
}

/// DIET-01's dietary-pattern choice, edited in place with immediate effect and no re-screen
/// consequence -- a downstream-of-the-gate concern (DIET-01's own isolation rule), so the
/// `.onChange` handler below may never call `GateResolution` or
/// `HealthDataStore.invalidateSection`, and it does not.
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
    @State private var dietSelection: Set<DietaryPattern>
    @State private var editingSection: EditableSection?
    @State private var isReScreenDue = false

    init(flow: OnboardingFlow, onOpenHealthProfile: @escaping () -> Void = {}) {
        self.flow = flow
        self.onOpenHealthProfile = onOpenHealthProfile
        _dietSelection = State(initialValue: [flow.answers.dietaryPattern ?? .none])
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

            ChoiceQuestionView(
                prompt: OnboardingCopy.Diet.headline,
                helper: OnboardingCopy.Diet.helper,
                options: DietaryPattern.allCases,
                mode: .single,
                selection: $dietSelection,
                optionTitle: dietOptionTitle
            )

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
        .onChange(of: dietSelection) { _, newValue in
            guard let chosen = newValue.first else { return }
            flow.answers.dietaryPattern = chosen
            persistDiet(chosen)
        }
        .sheet(item: $editingSection) { section in
            EditAnswerFlow(flow: flow, section: section)
                .onDisappear(perform: refreshReScreenDue)
        }
    }

    private func sectionEntryPoint(_ section: EditableSection, title: String) -> some View {
        SecondaryCTAButton(title: title) {
            editingSection = section
        }
    }

    private func dietOptionTitle(_ pattern: DietaryPattern) -> String {
        switch pattern {
        case .none: return OnboardingCopy.Diet.optionNone
        case .vegetarian: return OnboardingCopy.Diet.optionVegetarian
        case .vegan: return OnboardingCopy.Diet.optionVegan
        }
    }

    /// DIET-01: no expiry, no re-screen. Never calls `GateResolution` and never invalidates a
    /// condition tag -- a dietary preference must never loosen (or otherwise touch) a safety
    /// gate.
    private func persistDiet(_ pattern: DietaryPattern) {
        let store = HealthDataStore(context: modelContext)
        guard let existingAge = try? store.loadProfile().age else { return }
        try? store.updateProfile(UserProfileDraft(age: existingAge, dietaryPattern: pattern))
    }

    private func refreshReScreenDue() {
        let store = HealthDataStore(context: modelContext)
        isReScreenDue = (try? store.isReScreenDue(now: Date())) ?? false
    }
}
