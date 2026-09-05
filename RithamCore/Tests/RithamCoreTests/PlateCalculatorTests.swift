import Testing
@testable import RithamCore

@Suite("PlateCalculatorTests")
struct PlateCalculatorTests {

    @Test("100 kg target on a 20 kg standard barbell yields 40 kg per side and 100 kg achieved")
    func exactMatchOnStandardBarbell() {
        let result = PlateCalculator.nearestLoadable(
            target: 100,
            equipment: .standardBarbell,
            availablePlatesKg: PlateInventory.metricDefaultKg,
            barWeightKg: 20
        )
        #expect(result?.perSideWeightKg == 40)
        #expect(result?.achievedWeightKg == 100)
        #expect(result?.isExactMatch == true)
    }

    @Test("101 kg target on the same setup yields the nearest achievable weight at or below target")
    func nearestBelowTarget() {
        let result = PlateCalculator.nearestLoadable(
            target: 101,
            equipment: .standardBarbell,
            availablePlatesKg: PlateInventory.metricDefaultKg,
            barWeightKg: 20
        )
        #expect(result?.achievedWeightKg == 100)
        #expect(result?.isExactMatch == false)
    }

    @Test("a target at or below the bar weight yields an empty plate list and the bar weight as achieved")
    func targetAtOrBelowBarWeight() {
        let atBar = PlateCalculator.nearestLoadable(target: 20, equipment: .standardBarbell, barWeightKg: 20)
        #expect(atBar?.platesPerSideKg.isEmpty == true)
        #expect(atBar?.achievedWeightKg == 20)
        #expect(atBar?.isExactMatch == true)

        let belowBar = PlateCalculator.nearestLoadable(target: 5, equipment: .standardBarbell, barWeightKg: 20)
        #expect(belowBar?.platesPerSideKg.isEmpty == true)
        #expect(belowBar?.achievedWeightKg == 20)
    }

    @Test("a negative target weight returns nil")
    func negativeTargetReturnsNil() {
        #expect(PlateCalculator.nearestLoadable(target: -5, equipment: .standardBarbell) == nil)
    }

    @Test("a non-finite target weight returns nil")
    func nonFiniteTargetReturnsNil() {
        #expect(PlateCalculator.nearestLoadable(target: .infinity, equipment: .standardBarbell) == nil)
        #expect(PlateCalculator.nearestLoadable(target: .nan, equipment: .standardBarbell) == nil)
    }

    @Test("an absurdly large target weight returns nil")
    func absurdlyLargeTargetReturnsNil() {
        #expect(PlateCalculator.nearestLoadable(target: 100_000, equipment: .standardBarbell) == nil)
    }

    @Test("a stack machine target resolves to the nearest pin increment with an empty plate list")
    func stackMachineResolvesToPinIncrement() {
        let result = PlateCalculator.nearestLoadable(target: 47, equipment: .stackMachine)
        #expect(result?.platesPerSideKg.isEmpty == true)
        #expect(result?.achievedWeightKg == 45)
    }

    @Test("smithMachine and trapBar carry their own default bar weight, distinct from the standard barbell's")
    func distinctDefaultBarWeights() {
        #expect(Equipment.smithMachine.defaultBarWeightKg != Equipment.standardBarbell.defaultBarWeightKg)
        #expect(Equipment.trapBar.defaultBarWeightKg != Equipment.standardBarbell.defaultBarWeightKg)
    }
}

@Suite("OneRepMaxCalculatorTests")
struct OneRepMaxCalculatorTests {

    @Test("a single-rep input returns the input weight unchanged")
    func singleRepReturnsInputUnchanged() {
        #expect(OneRepMaxCalculator.estimate(weightKg: 100, reps: 1) == 100)
    }

    @Test("a 100 kg x 5 reps input returns an estimate strictly greater than 100 kg")
    func fiveRepEstimateExceedsWeight() {
        let estimate = OneRepMaxCalculator.estimate(weightKg: 100, reps: 5)
        #expect(estimate != nil)
        #expect((estimate ?? 0) > 100)
    }

    @Test("estimates increase monotonically with rep count at a fixed weight")
    func estimatesIncreaseMonotonically() {
        let estimates = (1...12).compactMap { OneRepMaxCalculator.estimate(weightKg: 100, reps: $0) }
        #expect(estimates.count == 12)
        for index in 1..<estimates.count {
            #expect(estimates[index] > estimates[index - 1])
        }
    }

    @Test("a rep count outside the supported range returns nil")
    func repCountOutsideRangeReturnsNil() {
        #expect(OneRepMaxCalculator.estimate(weightKg: 100, reps: 13) == nil)
        #expect(OneRepMaxCalculator.estimate(weightKg: 100, reps: 0) == nil)
    }

    @Test("a non-positive or non-finite weight returns nil")
    func invalidWeightReturnsNil() {
        #expect(OneRepMaxCalculator.estimate(weightKg: 0, reps: 5) == nil)
        #expect(OneRepMaxCalculator.estimate(weightKg: -10, reps: 5) == nil)
        #expect(OneRepMaxCalculator.estimate(weightKg: .infinity, reps: 5) == nil)
        #expect(OneRepMaxCalculator.estimate(weightKg: .nan, reps: 5) == nil)
    }
}
