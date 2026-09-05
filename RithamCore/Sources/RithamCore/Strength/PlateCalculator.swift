import Foundation

// RithamCore cannot import CoreMotion or CoreLocation — plate-loading math must never depend on
// sensor availability. Source: 02-RESEARCH.md Pattern 4 (plate calculator as a pure-Swift greedy
// algorithm). T-02-06 (ASVS V5, threat model): a non-finite, negative, or absurdly large target
// is rejected by returning `nil` rather than producing a number the caller could try to load
// onto a bar.

/// The result of a nearest-loadable-weight calculation.
public struct PlateLoad: Sendable, Equatable {
    /// Plates to load per side, in the order they were selected (largest first). Empty for a
    /// `.pinStack` equipment kind, and empty when the target is at or below the bar weight.
    public let platesPerSideKg: [Double]

    /// The weight actually achievable — either from `platesPerSideKg` (plate-loaded) or the
    /// rounded pin increment (`.pinStack`). Never a weight the caller cannot actually load.
    public let achievedWeightKg: Double

    /// The combined weight of `platesPerSideKg` on one side. Zero for a `.pinStack` equipment
    /// kind, since pin stacks have no per-side plate concept.
    public let perSideWeightKg: Double

    /// Whether `achievedWeightKg` exactly equals the requested target.
    public let isExactMatch: Bool

    public init(platesPerSideKg: [Double], achievedWeightKg: Double, perSideWeightKg: Double, isExactMatch: Bool) {
        self.platesPerSideKg = platesPerSideKg
        self.achievedWeightKg = achievedWeightKg
        self.perSideWeightKg = perSideWeightKg
        self.isExactMatch = isExactMatch
    }
}

public enum PlateCalculator {
    /// The largest target weight, in kilograms, this calculator accepts. Values above this are
    /// rejected as implausible input (ASVS V5 bounding, T-02-06) rather than processed.
    private static let maximumPlausibleTargetKg: Double = 1_000

    /// Finds the nearest loadable weight for `target` on `equipment`.
    ///
    /// Returns `nil` for a non-finite, negative, or implausibly large target — this bounding is
    /// the ASVS V5 control 02-VALIDATION.md assigns to STRENGTH-02, not an optional nicety.
    ///
    /// A `.pinStack` equipment kind (`Equipment.loadingStyle`) rounds `target` to the nearest
    /// multiple of `equipment.defaultIncrementKg` and returns an empty plate list — it must
    /// never be routed through plate arithmetic (02-RESEARCH.md Pattern 4's equipment note). A
    /// `.plateLoaded` equipment kind computes `(target - barWeight) / 2` per side and fills
    /// greedily from the largest available denomination down.
    ///
    /// - Parameters:
    ///   - target: The requested total weight, in kilograms.
    ///   - equipment: The equipment kind being loaded.
    ///   - availablePlatesKg: The plate denominations available to load, in kilograms. Defaults
    ///     to `PlateInventory.metricDefaultKg`.
    ///   - barWeightKg: The bar's own weight, in kilograms. Defaults to
    ///     `equipment.defaultBarWeightKg` when `nil`.
    public static func nearestLoadable(
        target: Double,
        equipment: Equipment,
        availablePlatesKg: [Double] = PlateInventory.metricDefaultKg,
        barWeightKg: Double? = nil
    ) -> PlateLoad? {
        guard target.isFinite, target >= 0, target <= maximumPlausibleTargetKg else {
            return nil
        }

        switch equipment.loadingStyle {
        case .pinStack:
            let increment = equipment.defaultIncrementKg ?? 1
            let steps = (target / increment).rounded()
            let achieved = steps * increment
            return PlateLoad(
                platesPerSideKg: [],
                achievedWeightKg: achieved,
                perSideWeightKg: 0,
                isExactMatch: achieved == target
            )

        case .plateLoaded:
            let barWeight = barWeightKg ?? equipment.defaultBarWeightKg
            guard target > barWeight else {
                return PlateLoad(
                    platesPerSideKg: [],
                    achievedWeightKg: barWeight,
                    perSideWeightKg: 0,
                    isExactMatch: target == barWeight
                )
            }

            let perSideTarget = (target - barWeight) / 2
            var remaining = perSideTarget
            var used: [Double] = []
            for plate in availablePlatesKg.sorted(by: >) where plate > 0 {
                while remaining >= plate {
                    used.append(plate)
                    remaining -= plate
                }
            }

            let perSideAchieved = used.reduce(0, +)
            let achievedWeight = barWeight + perSideAchieved * 2
            return PlateLoad(
                platesPerSideKg: used,
                achievedWeightKg: achievedWeight,
                perSideWeightKg: perSideAchieved,
                isExactMatch: achievedWeight == target
            )
        }
    }
}
