import SwiftUI
import RithamCore

// Rewritten in place per plan 02-06's header instruction: `StrengthHistoryView` (plan 02-15)
// replaces the placeholder this file used to register. This stays the single owner file for
// strength-history registration for the rest of the phase -- do not add a second registrar.
@MainActor
enum StrengthHistoryRegistration {
    static func registerAll() {
        StepRegistry.register(StrengthHistoryView.self)
    }
}
