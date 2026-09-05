import SwiftUI
import RithamCore

// Placeholder registrar for Phase 2's recommendations and pre-assessment surfaces. Plan 02-13
// replaces this file's two placeholder presenters with the real screens -- rewrite this file in
// place when that plan lands rather than appending a second registrar, so recommendations keeps
// exactly one owner file for the rest of the phase.
@MainActor
enum RecommendationsRegistration {
    static func registerAll() {
        StepRegistry.register(RecommendationsPlaceholderView.self)
        StepRegistry.register(PreAssessmentPlaceholderView.self)
    }
}

private struct RecommendationsPlaceholderView: View, OnboardingStepPresenting {
    static let step: OnboardingStep = .recommendations

    static func makeView(flow: OnboardingFlow) -> AnyView {
        AnyView(RecommendationsPlaceholderView())
    }

    var body: some View {
        RithamScreen(
            surface: DecorativeSurface.flat,
            headline: "Recommendations",
            bodyText: "This screen lands later in Phase 2."
        ) {
            EmptyView()
        }
    }
}

private struct PreAssessmentPlaceholderView: View, OnboardingStepPresenting {
    static let step: OnboardingStep = .preAssessment

    static func makeView(flow: OnboardingFlow) -> AnyView {
        AnyView(PreAssessmentPlaceholderView())
    }

    var body: some View {
        RithamScreen(
            surface: DecorativeSurface.flat,
            headline: "Pre-assessment",
            bodyText: "This screen lands later in Phase 2."
        ) {
            EmptyView()
        }
    }
}
