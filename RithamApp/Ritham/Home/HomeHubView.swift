import SwiftUI
import RithamCore

/// D-05's deliberately interim hub -- not CROSSGEN-01's polished three-item home (Phase 4's
/// scope), just enough real navigation for Phase 2's own features to be reachable and testable
/// in the running app. `.boundedHeaderOnly` fits this screen's own naming rationale (a bounded
/// header band, used by screens that explain or introduce something without collecting,
/// confirming, or blocking on health or age data themselves): this hub collects nothing, it only
/// routes.
///
/// Navigates to every pushed destination through `flow.open(_:)`, never a second navigation
/// container -- CROSSGEN-05 reserves the app's one navigation container for `OnboardingRootView`.
/// Settings (and the health profile it can open) are sheets, exactly as `SettingsView` itself
/// already uses sheets for its own sub-screens, never pushes.
///
/// Nothing in app code constructs `SettingsView` before this view -- presenting it here is what
/// finally makes it, and therefore `DietPlanView` (DIET-01, already built), reachable in the
/// running app for the first time.
struct HomeHubView: View {
    let flow: OnboardingFlow

    @State private var isPresentingSettings = false
    @State private var isPresentingHealthProfile = false

    var body: some View {
        RithamScreen(
            surface: DecorativeSurface.boundedHeaderOnly,
            headline: "Your interim home",
            bodyText: "This is a temporary hub so Phase 2's tracking and guidance features are reachable now. A polished home screen arrives later."
        ) {
            VStack(alignment: .leading, spacing: RithamSpacing.md) {
                PrimaryCTAButton(title: "Track cardio") {
                    flow.open(.cardioActivityPicker)
                }
                SecondaryCTAButton(title: "Cardio history") {
                    flow.open(.cardioHistory)
                }
                PrimaryCTAButton(title: "Log strength") {
                    flow.open(.strengthSession)
                }
                SecondaryCTAButton(title: "Strength history") {
                    flow.open(.strengthHistory)
                }
                PrimaryCTAButton(title: "Guidance") {
                    flow.open(.guidance)
                }
                PrimaryCTAButton(title: "Recommendations") {
                    flow.open(.recommendations)
                }
                SecondaryCTAButton(title: "Settings") {
                    isPresentingSettings = true
                }
            }
        }
        .sheet(isPresented: $isPresentingSettings) {
            SettingsView(
                flow: flow,
                onOpenHealthProfile: {
                    isPresentingSettings = false
                    isPresentingHealthProfile = true
                }
            )
        }
        .sheet(isPresented: $isPresentingHealthProfile) {
            HealthProfileView()
        }
    }
}
