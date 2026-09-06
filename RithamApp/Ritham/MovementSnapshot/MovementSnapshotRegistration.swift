import SwiftUI
import RithamCore

// Registrar for the Daily Movement Snapshot feature area. Mirrors `MomentumRegistration.swift`'s
// shape exactly -- its own separate file/enum, not a case added to that registrar, since this
// feature deliberately lives in its own `RithamApp/Ritham/MovementSnapshot/` directory rather
// than under `Momentum/` (see `MovementSnapshotView.swift`'s header comment for why).
@MainActor
enum MovementSnapshotRegistration {
    static func registerAll() {
        StepRegistry.register(MovementSnapshotView.self)
    }
}
