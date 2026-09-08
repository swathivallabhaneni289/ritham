import SwiftUI
import RithamCore

/// The dashboard's workout-plan tap-to-open destination (checkpoint revision, 2026-09-08):
/// presented as a sheet from `HomeHubView`, hosting `RecommendationsSectionContent` over the same
/// `RecommendationsModel` instance the dashboard's own compact summary card observes -- passed in,
/// never reconstructed here, so a plan already fetched from the summary card's own "Get my plan"
/// tap is still showing when the sheet opens, and any state change made inside the sheet (a fetch,
/// a retry, toggling the sleep-adjusted plan) is immediately visible on the summary card once the
/// sheet is dismissed, since both observe the same `@Observable` instance.
///
/// Sheet-presented, unlike `RecommendationsView`'s push-based `.recommendations` registration
/// (still registered, still unreached from this dashboard -- 04-RESEARCH.md Pitfall 4): a genuine
/// "Done" control is correct here, unlike the dashboard's own inline sections.
struct RecommendationsQuickView: View {
    let model: RecommendationsModel
    let flow: OnboardingFlow

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        RithamScreen(surface: DecorativeSurface.flat, headline: "Your workout plan") {
            RecommendationsSectionContent(model: model, flow: flow)

            PrimaryCTAButton(title: "Done") {
                dismiss()
            }
        }
    }
}
