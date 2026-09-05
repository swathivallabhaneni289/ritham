import Testing
import RithamCore
@testable import Ritham

/// Exercises `OnboardingFlow.open(_:)` directly, the same data-level style `AppShellTests` uses
/// for `advance`/`goBack`, rather than rendering `HomeHubView`. This suite never touches
/// `StepRegistry`'s shared static state, so it cannot join the cross-suite race
/// `STATE.md`'s Blockers/Concerns documents for suites that do.
@MainActor
@Suite("HomeHubTests")
struct HomeHubTests {

    @Test("opening cardioActivityPicker appends exactly that step")
    func openingCardioActivityPickerAppendsExactlyThatStep() {
        let flow = OnboardingFlow()
        flow.open(.cardioActivityPicker)
        #expect(flow.path == [.cardioActivityPicker])
    }

    @Test("opening cardioHistory appends exactly that step")
    func openingCardioHistoryAppendsExactlyThatStep() {
        let flow = OnboardingFlow()
        flow.open(.cardioHistory)
        #expect(flow.path == [.cardioHistory])
    }

    @Test("opening strengthSession appends exactly that step")
    func openingStrengthSessionAppendsExactlyThatStep() {
        let flow = OnboardingFlow()
        flow.open(.strengthSession)
        #expect(flow.path == [.strengthSession])
    }

    @Test("opening strengthHistory appends exactly that step")
    func openingStrengthHistoryAppendsExactlyThatStep() {
        let flow = OnboardingFlow()
        flow.open(.strengthHistory)
        #expect(flow.path == [.strengthHistory])
    }

    @Test("opening guidance appends exactly that step")
    func openingGuidanceAppendsExactlyThatStep() {
        let flow = OnboardingFlow()
        flow.open(.guidance)
        #expect(flow.path == [.guidance])
    }

    @Test("opening recommendations appends exactly that step")
    func openingRecommendationsAppendsExactlyThatStep() {
        let flow = OnboardingFlow()
        flow.open(.recommendations)
        #expect(flow.path == [.recommendations])
    }

    @Test("calling open(.recommendations) twice leaves path with exactly one .recommendations entry")
    func openingSameStepTwiceAppendsOnlyOnce() {
        let flow = OnboardingFlow()
        flow.open(.recommendations)
        flow.open(.recommendations)
        #expect(flow.path == [.recommendations])
    }

    @Test("opening a different step after another appends both, in order")
    func openingDifferentStepsAppendsBothInOrder() {
        let flow = OnboardingFlow()
        flow.open(.cardioActivityPicker)
        flow.open(.guidance)
        #expect(flow.path == [.cardioActivityPicker, .guidance])
    }
}
