import SwiftUI
import RithamCore

// Placeholder registrar for Phase 2's strength-history surface. Plan 02-15 replaces this file's
// placeholder presenter with the real history screen -- rewrite this file in place when that
// plan lands rather than appending a second registrar, so strength history keeps exactly one
// owner file for the rest of the phase.
@MainActor
enum StrengthHistoryRegistration {
    static func registerAll() {
        StepRegistry.register(StrengthHistoryPlaceholderView.self)
    }
}

private struct StrengthHistoryPlaceholderView: View, OnboardingStepPresenting {
    static let step: OnboardingStep = .strengthHistory

    static func makeView(flow: OnboardingFlow) -> AnyView {
        AnyView(StrengthHistoryPlaceholderView())
    }

    var body: some View {
        RithamScreen(
            surface: DecorativeSurface.flat,
            headline: "Strength history",
            bodyText: "This screen lands later in Phase 2."
        ) {
            EmptyView()
        }
    }
}
