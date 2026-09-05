import SwiftUI
import RithamCore

// Plan 02-12's Task 3 rewrite: the interim placeholder screen this file registered is gone,
// replaced with the real guidance surface (`GuidanceView`). Rewritten in place rather than
// appended to, so guidance keeps exactly one registrar file for the rest of the phase.
@MainActor
enum GuidanceRegistration {
    static func registerAll() {
        StepRegistry.register(GuidanceView.self)
    }
}
