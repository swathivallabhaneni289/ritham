import SwiftUI
import RithamCore

// Placeholder registrar for Phase 2's guidance surface. Plan 02-12 replaces this file's
// placeholder presenter with the real screen -- rewrite this file in place when that plan lands
// rather than appending a second registrar, so guidance keeps exactly one owner file for the
// rest of the phase.
@MainActor
enum GuidanceRegistration {
    static func registerAll() {
        StepRegistry.register(GuidancePlaceholderView.self)
    }
}

private struct GuidancePlaceholderView: View, OnboardingStepPresenting {
    static let step: OnboardingStep = .guidance

    static func makeView(flow: OnboardingFlow) -> AnyView {
        AnyView(GuidancePlaceholderView())
    }

    var body: some View {
        RithamScreen(
            surface: DecorativeSurface.flat,
            headline: "Guidance",
            bodyText: "This screen lands later in Phase 2."
        ) {
            EmptyView()
        }
    }
}
