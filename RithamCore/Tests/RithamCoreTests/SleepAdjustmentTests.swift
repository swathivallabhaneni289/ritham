import Foundation
import Testing
@testable import RithamCore

@Suite("SleepAdjustmentTests")
struct SleepAdjustmentTests {

    // MARK: - shift(for:)

    @Test("a Poor check-in yields a lighter shift")
    func poorCheckInYieldsLighterShift() {
        let checkIn = SleepCheckIn(day: Date(), quality: .poor)
        #expect(SleepAdjustment.shift(for: checkIn) == .lighter)
    }

    @Test("a Great check-in yields no shift")
    func greatCheckInYieldsNoShift() {
        let checkIn = SleepCheckIn(day: Date(), quality: .great)
        #expect(SleepAdjustment.shift(for: checkIn) == .unchanged)
    }

    @Test("an OK check-in yields no shift")
    func okCheckInYieldsNoShift() {
        let checkIn = SleepCheckIn(day: Date(), quality: .ok)
        #expect(SleepAdjustment.shift(for: checkIn) == .unchanged)
    }

    @Test("skippedCheckInIsIdenticalToNoCheckIn")
    func skippedCheckInIsIdenticalToNoCheckIn() {
        let noCheckIn = SleepAdjustment.shift(for: nil)
        #expect(noCheckIn == .unchanged)
        #expect(noCheckIn == SleepAdjustment.shift(for: SleepCheckIn(day: Date(), quality: .great)))
        #expect(noCheckIn == SleepAdjustment.shift(for: SleepCheckIn(day: Date(), quality: .ok)))
    }

    // MARK: - adjustedSetCount

    @Test("adjustedSetCount reduces a lighter shift by one, floored at one")
    func adjustedSetCountReducesByOneWithFloor() {
        #expect(SleepAdjustment.adjustedSetCount(3, shift: .lighter) == 2)
        #expect(SleepAdjustment.adjustedSetCount(1, shift: .lighter) == 1)
    }

    @Test("adjustedSetCount leaves an unchanged shift untouched")
    func adjustedSetCountLeavesUnchangedUntouched() {
        #expect(SleepAdjustment.adjustedSetCount(4, shift: .unchanged) == 4)
    }

    @Test("adjustedSetCount never returns a value greater than its input")
    func adjustedSetCountNeverIncreases() {
        for sets in 1...12 {
            for shift: IntensityShift in [.unchanged, .lighter] {
                #expect(SleepAdjustment.adjustedSetCount(sets, shift: shift) <= sets)
            }
        }
    }

    // MARK: - SleepQuality

    @Test("SleepQuality has exactly three cases with stable raw values")
    func sleepQualityHasStableRawValues() {
        #expect(SleepQuality.allCases.count == 3)
        #expect(SleepQuality.great.rawValue == "great")
        #expect(SleepQuality.ok.rawValue == "ok")
        #expect(SleepQuality.poor.rawValue == "poor")
    }

    // MARK: - SleepCheckIn

    @Test("SleepCheckIn is Equatable")
    func sleepCheckInIsEquatable() {
        let day = Date()
        let id = UUID()
        let a = SleepCheckIn(id: id, day: day, quality: .poor, note: "restless")
        let b = SleepCheckIn(id: id, day: day, quality: .poor, note: "restless")
        #expect(a == b)
    }

    @Test("sleepCheckInCarriesNoMomentumState")
    func sleepCheckInCarriesNoMomentumState() {
        let checkIn = SleepCheckIn(day: Date(), quality: .poor, note: "a note")
        let mirror = Mirror(reflecting: checkIn)
        let labels = Set(mirror.children.compactMap { $0.label })
        #expect(labels == ["id", "day", "quality", "note"])
    }
}
