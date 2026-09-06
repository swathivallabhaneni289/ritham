import SwiftUI
import RithamCore

// Registrar for this phase's Momentum detail screen. Mirrors
// `RecommendationsRegistration.swift`'s shape exactly -- later Momentum-area plans extend this
// one file rather than creating a second registrar for the same feature area.
@MainActor
enum MomentumRegistration {
    static func registerAll() {
        StepRegistry.register(MomentumView.self)
        StepRegistry.register(SleepCheckInView.self)
    }
}
