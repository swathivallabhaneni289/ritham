import SwiftUI
import RithamCore

// Placeholder registrar for Phase 2's cardio surfaces. Plan 02-10 replaces this file's three
// placeholder presenters with the real activity-picker, session, and history screens -- rewrite
// this file in place when that plan lands rather than appending a second registrar, so cardio
// keeps exactly one owner file for the rest of the phase.
//
// Registered from Wave 1 onward (this plan) so `PhaseCoverageTests`'s unregistered-steps
// assertion stays green at every wave boundary, rather than going red for however many waves
// separate this plan from 02-10.
@MainActor
enum CardioRegistration {
    static func registerAll() {
        StepRegistry.register(CardioActivityPickerPlaceholderView.self)
        StepRegistry.register(CardioSessionPlaceholderView.self)
        StepRegistry.register(CardioHistoryPlaceholderView.self)
    }
}

private struct CardioActivityPickerPlaceholderView: View, OnboardingStepPresenting {
    static let step: OnboardingStep = .cardioActivityPicker

    static func makeView(flow: OnboardingFlow) -> AnyView {
        AnyView(CardioActivityPickerPlaceholderView())
    }

    var body: some View {
        RithamScreen(
            surface: DecorativeSurface.flat,
            headline: "Cardio activity picker",
            bodyText: "This screen lands later in Phase 2."
        ) {
            EmptyView()
        }
    }
}

private struct CardioSessionPlaceholderView: View, OnboardingStepPresenting {
    static let step: OnboardingStep = .cardioSession

    static func makeView(flow: OnboardingFlow) -> AnyView {
        AnyView(CardioSessionPlaceholderView())
    }

    var body: some View {
        RithamScreen(
            surface: DecorativeSurface.flat,
            headline: "Cardio session",
            bodyText: "This screen lands later in Phase 2."
        ) {
            EmptyView()
        }
    }
}

private struct CardioHistoryPlaceholderView: View, OnboardingStepPresenting {
    static let step: OnboardingStep = .cardioHistory

    static func makeView(flow: OnboardingFlow) -> AnyView {
        AnyView(CardioHistoryPlaceholderView())
    }

    var body: some View {
        RithamScreen(
            surface: DecorativeSurface.flat,
            headline: "Cardio history",
            bodyText: "This screen lands later in Phase 2."
        ) {
            EmptyView()
        }
    }
}
