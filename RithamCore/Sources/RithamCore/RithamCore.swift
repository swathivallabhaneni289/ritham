// HARD CONSTRAINT: no file under Sources/RithamCore/ may import SwiftUI, UIKit, AppKit,
// SwiftData, CoreMotion, or CoreLocation. Foundation only.
//
// This is what makes the package compile and run its tests on a machine with no iOS SDK
// installed, and it is the compile-time enforcement of the pure-module mandate in
// 01-RESEARCH.md's Architectural Responsibility Map: every safety-critical decision
// module (gate resolution, age floor, calibration thresholds, onboarding routing) lives
// here, entirely free of UI, persistence, and sensor framework dependencies.

/// Root namespace for the RithamCore package. Exists so the target has a compilable
/// root symbol; later plans add the real safety-critical modules alongside it.
public enum RithamCore {
    /// Schema version for on-disk/persisted data shapes owned by RithamCore.
    public static let schemaVersion = 1
}
