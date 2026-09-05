import Foundation

// RithamCore cannot import CoreMotion or CoreLocation — equipment definitions and plate-loading
// math must never depend on sensor availability. This file, together with PlateCalculator.swift,
// implements STRENGTH-02's nearest-loadable-weight calculation across five equipment kinds.

/// How an `Equipment` case accepts added resistance.
public enum LoadingStyle: Sendable, Equatable {
    /// Plates are loaded per side onto a bar; nearest loadable weight is found by plate-greedy
    /// arithmetic (see `PlateCalculator`).
    case plateLoaded

    /// Resistance is selected from a fixed pin-weight increment stack, never plate arithmetic.
    case pinStack
}

/// Named default plate denominations, in kilograms, sorted descending.
///
/// These numbers appear exactly once in the codebase, in the same spirit as
/// `CalibrationThreshold` (`Calibration/CalibrationSession.swift`).
public enum PlateInventory {
    public static let metricDefaultKg: [Double] = [25, 20, 15, 10, 5, 2.5, 1.25]
}

/// The five equipment kinds STRENGTH-02 enumerates.
public enum Equipment: String, CaseIterable, Sendable, Codable {
    case standardBarbell
    case ezBar
    case trapBar
    case smithMachine
    case stackMachine

    public var displayName: String {
        switch self {
        case .standardBarbell:
            return "Standard Barbell"
        case .ezBar:
            return "EZ Bar"
        case .trapBar:
            return "Trap Bar"
        case .smithMachine:
            return "Smith Machine"
        case .stackMachine:
            return "Stack Machine"
        }
    }

    /// Only `.stackMachine` loads via a fixed pin increment; every other case is plate-loaded.
    public var loadingStyle: LoadingStyle {
        self == .stackMachine ? .pinStack : .plateLoaded
    }

    /// The bar's own weight, in kilograms, before any plates are added.
    ///
    /// `.stackMachine` has no bar weight at all — it is zero here (never `nil`) precisely
    /// because `PlateCalculator` never reads this value for a `.pinStack` equipment kind in the
    /// first place (see `defaultIncrementKg`, the value that path actually uses).
    public var defaultBarWeightKg: Double {
        switch self {
        case .standardBarbell:
            return 20
        case .ezBar:
            return 10
        case .trapBar:
            return 25
        case .smithMachine:
            return 15
        case .stackMachine:
            return 0
        }
    }

    /// The fixed pin-weight increment for a `.pinStack` equipment kind. `nil` for every
    /// plate-loaded case, since they never round to a pin increment.
    public var defaultIncrementKg: Double? {
        self == .stackMachine ? 5 : nil
    }
}
