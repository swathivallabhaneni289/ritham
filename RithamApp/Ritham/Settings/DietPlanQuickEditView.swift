import SwiftUI
import RithamCore

/// The dashboard's diet-plan tap-to-open destination (checkpoint revision, 2026-09-08): presented
/// as a sheet from `HomeHubView`, hosting only `DietPlanSectionContent` -- the DIET-01-isolated
/// dietary-pattern and allergen pickers -- never the full `DietPlanView`. The food-allergy
/// screening checkbox and its severity follow-up stay reachable only through Settings > Diet plan
/// (`DietPlanView` itself); this view exists so the dashboard's tap-to-open card cannot
/// accidentally reintroduce that risk by opening the wrong screen (04-RESEARCH.md Pitfall 3).
///
/// Sheet-presented, unlike `DietPlanSectionContent`'s dashboard-embedded use: a genuine "Done"
/// control is correct here (Pitfall 5 only forbids `dismiss()` on the always-visible, non-modal
/// dashboard card itself).
struct DietPlanQuickEditView: View {
    let flow: OnboardingFlow

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        RithamScreen(surface: DecorativeSurface.flat, headline: "Diet plan") {
            DietPlanSectionContent(flow: flow)

            PrimaryCTAButton(title: "Done") {
                dismiss()
            }
        }
    }
}
