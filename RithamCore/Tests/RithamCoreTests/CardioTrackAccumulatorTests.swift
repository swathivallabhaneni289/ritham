import Foundation
import Testing
@testable import RithamCore

@Suite("CardioTrackAccumulatorTests")
struct CardioTrackAccumulatorTests {

    /// Degrees of latitude per metre at the equator, used to synthesize samples a known
    /// great-circle distance apart without depending on CoreLocation.
    private static let degreesLatitudePerMeter = 1.0 / 111_320.0

    private static let baseTimestamp = Date(timeIntervalSince1970: 0)

    private static func sample(
        metersNorthOfOrigin: Double,
        altitudeMeters: Double = 0,
        horizontalAccuracyMeters: Double = 5,
        verticalAccuracyMeters: Double = 3,
        secondsAfterBase: Double
    ) -> LocationSample {
        LocationSample(
            latitude: metersNorthOfOrigin * degreesLatitudePerMeter,
            longitude: 0,
            altitudeMeters: altitudeMeters,
            horizontalAccuracyMeters: horizontalAccuracyMeters,
            verticalAccuracyMeters: verticalAccuracyMeters,
            timestamp: baseTimestamp.addingTimeInterval(secondsAfterBase)
        )
    }

    // MARK: - Accuracy rejection

    @Test("a sample beyond the rejection accuracy threshold is discarded and contributes zero distance")
    func inaccurateSampleIsDiscarded() {
        var accumulator = CardioTrackAccumulator()

        let accepted = accumulator.accept(Self.sample(
            metersNorthOfOrigin: 100,
            horizontalAccuracyMeters: CardioTrackAccumulator.rejectionAccuracyMeters + 1,
            secondsAfterBase: 0
        ))

        #expect(accepted == false)
        #expect(accumulator.progress.distanceMeters == 0)
    }

    // MARK: - Distance accumulation

    @Test("two consecutive accepted samples 100m apart 60s apart accumulate 100m of distance")
    func consecutiveSamplesAccumulateDistance() {
        var accumulator = CardioTrackAccumulator()

        #expect(accumulator.accept(Self.sample(metersNorthOfOrigin: 0, secondsAfterBase: 0)) == true)
        #expect(accumulator.accept(Self.sample(metersNorthOfOrigin: 100, secondsAfterBase: 60)) == true)

        #expect(abs(accumulator.progress.distanceMeters - 100) < 1)
    }

    // MARK: - Implausible speed rejection

    @Test("a sample implying an implausible instantaneous speed is discarded and contributes zero distance")
    func implausibleSpeedSampleIsDiscarded() {
        var accumulator = CardioTrackAccumulator()

        #expect(accumulator.accept(Self.sample(metersNorthOfOrigin: 0, secondsAfterBase: 0)) == true)
        // 5,000m in 1 second is far above implausibleSpeedMetersPerSecond.
        let teleported = accumulator.accept(Self.sample(metersNorthOfOrigin: 5_000, secondsAfterBase: 1))

        #expect(teleported == false)
        #expect(accumulator.progress.distanceMeters == 0)
    }

    // MARK: - Split emission

    @Test("crossing 1000m emits exactly one split with index 1; crossing 2000m emits a second with index 2")
    func splitsEmitAtEachWholeKilometre() {
        var accumulator = CardioTrackAccumulator()

        #expect(accumulator.accept(Self.sample(metersNorthOfOrigin: 0, secondsAfterBase: 0)) == true)
        #expect(accumulator.accept(Self.sample(metersNorthOfOrigin: 600, secondsAfterBase: 100)) == true)
        #expect(accumulator.progress.splits.isEmpty)

        #expect(accumulator.accept(Self.sample(metersNorthOfOrigin: 1_200, secondsAfterBase: 200)) == true)
        #expect(accumulator.progress.splits.count == 1)
        #expect(accumulator.progress.splits[0].index == 1)

        #expect(accumulator.accept(Self.sample(metersNorthOfOrigin: 1_800, secondsAfterBase: 300)) == true)
        #expect(accumulator.accept(Self.sample(metersNorthOfOrigin: 2_400, secondsAfterBase: 400)) == true)
        #expect(accumulator.progress.splits.count == 2)
        #expect(accumulator.progress.splits[1].index == 2)
    }

    // MARK: - Independent confidence tracking

    @Test("accepted samples with poor vertical accuracy leave elevationConfidence low while horizontalConfidence may still be high")
    func elevationConfidenceIsIndependentOfHorizontalConfidence() {
        var accumulator = CardioTrackAccumulator()

        accumulator.accept(Self.sample(
            metersNorthOfOrigin: 0,
            horizontalAccuracyMeters: 3,
            verticalAccuracyMeters: 40,
            secondsAfterBase: 0
        ))

        #expect(accumulator.progress.horizontalConfidence == .high)
        #expect(accumulator.progress.elevationConfidence == .low)
    }

    // MARK: - Elevation gain

    @Test("elevation gain accumulates only from positive altitude deltas, never from descents")
    func elevationGainIgnoresDescents() {
        var accumulator = CardioTrackAccumulator()

        #expect(accumulator.accept(Self.sample(metersNorthOfOrigin: 0, altitudeMeters: 100, secondsAfterBase: 0)) == true)
        #expect(accumulator.accept(Self.sample(metersNorthOfOrigin: 50, altitudeMeters: 110, secondsAfterBase: 30)) == true)
        #expect(accumulator.accept(Self.sample(metersNorthOfOrigin: 100, altitudeMeters: 95, secondsAfterBase: 60)) == true)

        #expect(accumulator.progress.elevationGainMeters == 10)
    }
}
