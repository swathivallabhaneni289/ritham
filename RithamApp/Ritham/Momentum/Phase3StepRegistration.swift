import Foundation

// The single aggregate registrar for every Phase 3 feature area, calling each area's own
// registrar exactly once -- matching Phase 2's own `Phase2StepRegistration` precedent
// (`RithamApp/Ritham/Home/Phase2StepRegistration.swift`). `StepBootstrap` calls only this file;
// later Phase 3 plans extend this file's call list rather than each touching the app bootstrap
// or each other's registrar files.
@MainActor
enum Phase3StepRegistration {
    static func registerAll() {
        MomentumRegistration.registerAll()
    }
}
