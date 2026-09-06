import SwiftUI
import Testing
import RithamCore
@testable import Ritham

// Plan 02-16's Phase 2 completeness gate: plan 02-06 deliberately registered placeholder
// presenters for all eight Phase 2 steps so `PhaseCoverageTests`'s `unregisteredSteps`-is-empty
// assertion stayed green while feature screens landed across three later waves (02-10 through
// 02-13, 02-15). That earlier gate only proves a step resolves to *something* -- it cannot tell a
// placeholder apart from the real screen. This suite is what proves every one of those
// placeholders was subsequently replaced, by asserting the exact concrete presenter type
// `StepRegistry` holds for each of the eight steps and asserting none of them is a placeholder
// type.
//
// Nested inside `StepRegistryTouchingSuites` (`StepRegistrySerialization.swift`) because this
// suite resets and re-bootstraps `StepRegistry`'s shared static state, exactly like the other
// registry-touching suites -- it must be ordered relative to them, not only internally.
extension StepRegistryTouchingSuites {

@Suite("Phase2CoverageTests", .serialized)
@MainActor
struct Phase2CoverageTests {

    init() {
        StepRegistry.reset()
        StepBootstrap.registerAllSteps()
    }

    /// Every Phase 2 step (`OnboardingStep.swift`'s header comment: "Phase 2's eight surfaces,
    /// cardioActivityPicker through preAssessment") paired with the real screen type its owning
    /// plan created, per each area's registrar file
    /// (`CardioRegistration`/`StrengthLoggingRegistration`/`StrengthHistoryRegistration`/
    /// `GuidanceRegistration`/`RecommendationsRegistration`).
    private static let phase2StepsToRealTypes: [(step: OnboardingStep, type: Any.Type)] = [
        (.cardioActivityPicker, CardioActivityPickerView.self),
        (.cardioSession, CardioSessionView.self),
        (.cardioHistory, CardioHistoryView.self),
        (.strengthSession, StrengthSessionView.self),
        (.strengthHistory, StrengthHistoryView.self),
        (.guidance, GuidanceView.self),
        (.recommendations, RecommendationsView.self),
        (.preAssessment, PreAssessmentView.self),
    ]

    // MARK: - Each of the eight Phase 2 steps resolves to its real screen

    @Test("each of the eight Phase 2 steps resolves to a presenter whose type is the real screen its owning plan created")
    func eachPhase2StepResolvesToItsRealScreenType() {
        for entry in Self.phase2StepsToRealTypes {
            let registered = StepRegistry.registeredPresenterType(for: entry.step)
            #expect(registered != nil, "\(entry.step) has no registered presenter type")
            #expect(registered == entry.type, "\(entry.step) resolved to \(String(describing: registered)), expected \(entry.type)")
        }
    }

    // MARK: - No resolved presenter is one of plan 02-06's placeholder types

    @Test("no Phase 2 step resolves to a placeholder presenter type")
    func noPhase2StepResolvesToAPlaceholderType() {
        for entry in Self.phase2StepsToRealTypes {
            let registered = StepRegistry.registeredPresenterType(for: entry.step)
            let typeName = String(describing: registered)
            #expect(!typeName.contains("Placeholder"), "\(entry.step) resolved to \(typeName), which looks like a placeholder type")
        }
    }

    // MARK: - Every Phase 2 step also resolves without trapping, through the real registered factory

    @Test("every Phase 2 step's view(for:flow:) call resolves without trapping")
    func everyPhase2StepResolvesWithoutTrapping() {
        let flow = OnboardingFlow()
        for entry in Self.phase2StepsToRealTypes {
            _ = StepRegistry.view(for: entry.step, flow: flow)
        }
        #expect(true)
    }
}

}
