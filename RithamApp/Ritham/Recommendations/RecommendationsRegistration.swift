import SwiftUI
import RithamCore

// Registrar for Phase 2's recommendations and pre-assessment surfaces. Plan 02-13 replaced the
// two placeholder presenters this file used to register with the real screens -- keep this the
// single owner file for both steps rather than adding a second registrar.
@MainActor
enum RecommendationsRegistration {
    static func registerAll() {
        StepRegistry.register(RecommendationsView.self)
        StepRegistry.register(PreAssessmentView.self)
    }
}
