import Foundation
import SwiftUI
import RithamCore

// The lift-mode counterpart to PedometerSession/StopwatchSession -- lets the user name or pick
// an exercise and record a working set, maintaining a LiftProgress. Only working sets count
// toward the bar; a caller must filter out warm-up sets before calling `recordWorkingSet`,
// matching LiftProgress.recordWorkingSet's own contract.
//
// This recorder never decides its own completion -- it exposes `progress`; the view calls
// CalibrationCompletion.evaluate (RithamCore, plan 01-05) exactly like the two walk sources do.
// Not itself actor-isolated -- see PedometerSession.swift's header comment for why an isolated
// conformance cannot combine with `CalibrationSessionSource`'s inherited `Sendable` requirement.
// `@unchecked Sendable` is the honest annotation: every mutation happens through
// `recordWorkingSet`, always called from the main-actor session view, and every read goes
// through the same main-actor view.
@Observable
final class LiftSessionRecorder: CalibrationSessionSource, @unchecked Sendable {
    let mode: CalibrationMode = .lift

    private(set) nonisolated(unsafe) var recorded = LiftProgress()

    var progress: CalibrationProgress {
        .lift(recorded)
    }

    var totalWorkingSets: Int { recorded.totalWorkingSets }
    var distinctExercises: Int { recorded.distinctExercises }

    /// Records one working set for `exercise`, with an optional load in kilograms. Warm-up sets
    /// must not be passed here -- they do not count toward
    /// CalibrationThreshold.qualifyingWorkingSets.
    func recordWorkingSet(exercise: String, loadKg: Double? = nil) {
        recorded.recordWorkingSet(exercise: exercise, loadKg: loadKg)
    }
}
