import SwiftUI
import RithamCore

// Placeholder registrar for Phase 2's strength-logging surface. Plan 02-11 replaces this file's
// placeholder presenter with the real session screen -- rewrite this file in place when that
// plan lands rather than appending a second registrar, so strength logging keeps exactly one
// owner file for the rest of the phase.
@MainActor
enum StrengthLoggingRegistration {
    static func registerAll() {
        StepRegistry.register(StrengthSessionPlaceholderView.self)
    }
}

private struct StrengthSessionPlaceholderView: View, OnboardingStepPresenting {
    static let step: OnboardingStep = .strengthSession

    static func makeView(flow: OnboardingFlow) -> AnyView {
        AnyView(StrengthSessionPlaceholderView())
    }

    var body: some View {
        RithamScreen(
            surface: DecorativeSurface.flat,
            headline: "Strength session",
            bodyText: "This screen lands later in Phase 2."
        ) {
            EmptyView()
        }
    }
}
