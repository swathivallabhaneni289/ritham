import Foundation

// RithamCore cannot import CoreLocation, so `LocationSample` mirrors exactly the fields a real
// `CLLocation` supplies (coordinate, horizontalAccuracy, verticalAccuracy, altitude, timestamp)
// and nothing more — the app-layer CoreLocation adapter (plan 02-09) maps a `CLLocation` into
// one of these without this package ever depending on CoreLocation. Distance is accumulated via
// a private great-circle (haversine) helper rather than `CLLocation.distance(from:)`, which this
// package cannot call.
//
// Per 02-RESEARCH.md's "Don't Hand-Roll" table, filtering is accuracy-threshold-based (discard
// points beyond a horizontal-accuracy threshold), not a hand-rolled Kalman/Hampel smoothing
// filter — CARDIO-02's visible-confidence-indicator requirement exists precisely so Ritham
// doesn't need to hide GPS noise behind a smoothing algorithm. Per the Security Domain V5 row,
// a sample implying an implausible instantaneous speed is discarded before it can inflate
// recorded distance (T-02-03).

/// A single location reading, containing exactly the fields a `CLLocation` supplies that this
/// accumulator needs.
public struct LocationSample: Sendable, Equatable {
    public let latitude: Double
    public let longitude: Double
    public let altitudeMeters: Double
    public let horizontalAccuracyMeters: Double
    public let verticalAccuracyMeters: Double
    public let timestamp: Date

    public init(
        latitude: Double,
        longitude: Double,
        altitudeMeters: Double,
        horizontalAccuracyMeters: Double,
        verticalAccuracyMeters: Double,
        timestamp: Date
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.altitudeMeters = altitudeMeters
        self.horizontalAccuracyMeters = horizontalAccuracyMeters
        self.verticalAccuracyMeters = verticalAccuracyMeters
        self.timestamp = timestamp
    }
}

/// Accumulates a `CardioProgress` from a stream of `LocationSample`s, filtering out samples that
/// are too inaccurate or that imply an implausible instantaneous speed, and emitting a
/// `CardioSplit` each time accumulated distance crosses a whole kilometre.
public struct CardioTrackAccumulator: Sendable {
    /// A sample with a horizontal accuracy circle wider than this (in metres) is rejected — the
    /// upper end of the 30-50 m band 02-RESEARCH.md cites for pace-sensitive apps.
    public static let rejectionAccuracyMeters: Double = 50

    /// A sample implying a speed above this (in metres/second, ~45 km/h) relative to the
    /// previously accepted sample is rejected as an implausible position jump — above elite
    /// running pace and below ordinary vehicle speed (the V5 sanity bound).
    public static let implausibleSpeedMetersPerSecond: Double = 12.5

    /// A `CardioSplit` is emitted every time accumulated distance crosses a whole multiple of
    /// this distance, in metres.
    public static let splitDistanceMeters: Double = 1_000

    public private(set) var progress: CardioProgress

    private var lastAcceptedSample: LocationSample?
    private var currentSplitStartTimestamp: Date?
    private var currentSplitDistanceMeters: Double = 0
    private var currentSplitElevationGainMeters: Double = 0
    private var nextSplitIndex: Int = 1

    public init(progress: CardioProgress = CardioProgress()) {
        self.progress = progress
    }

    /// Attempts to accept a sample into the tracked progress. Returns `false` (and leaves
    /// `progress` unchanged) when the sample is rejected for poor horizontal accuracy or an
    /// implausible implied speed.
    @discardableResult
    public mutating func accept(_ sample: LocationSample) -> Bool {
        guard sample.horizontalAccuracyMeters >= 0,
              sample.horizontalAccuracyMeters <= Self.rejectionAccuracyMeters else {
            return false
        }

        var distanceDeltaMeters: Double = 0
        var durationDeltaSeconds: TimeInterval = 0

        if let last = lastAcceptedSample {
            distanceDeltaMeters = Self.haversineDistanceMeters(
                latitude1: last.latitude, longitude1: last.longitude,
                latitude2: sample.latitude, longitude2: sample.longitude
            )
            durationDeltaSeconds = sample.timestamp.timeIntervalSince(last.timestamp)

            // A non-positive time delta cannot yield a meaningful speed; treat it as
            // implausible rather than risk a divide-by-zero producing a false accept.
            guard durationDeltaSeconds > 0 else { return false }

            let impliedSpeedMetersPerSecond = distanceDeltaMeters / durationDeltaSeconds
            guard impliedSpeedMetersPerSecond <= Self.implausibleSpeedMetersPerSecond else {
                return false
            }
        }

        let elevationDeltaMeters: Double
        if let last = lastAcceptedSample {
            // Only positive altitude deltas count toward elevation gain — descents never
            // subtract from it.
            elevationDeltaMeters = max(0, sample.altitudeMeters - last.altitudeMeters)
        } else {
            elevationDeltaMeters = 0
        }

        progress.record(
            distanceMeters: distanceDeltaMeters,
            elevationGainMeters: elevationDeltaMeters,
            duration: durationDeltaSeconds
        )
        progress.updateConfidence(
            horizontal: Self.horizontalConfidence(forAccuracyMeters: sample.horizontalAccuracyMeters),
            elevation: Self.elevationConfidence(forAccuracyMeters: sample.verticalAccuracyMeters)
        )

        if currentSplitStartTimestamp == nil {
            currentSplitStartTimestamp = lastAcceptedSample?.timestamp ?? sample.timestamp
        }
        currentSplitDistanceMeters += distanceDeltaMeters
        currentSplitElevationGainMeters += elevationDeltaMeters

        while currentSplitDistanceMeters >= Self.splitDistanceMeters {
            let splitStart = currentSplitStartTimestamp ?? sample.timestamp
            let splitDuration = sample.timestamp.timeIntervalSince(splitStart)
            let averageSecondsPerKm = currentSplitDistanceMeters > 0
                ? splitDuration / (currentSplitDistanceMeters / 1_000)
                : 0

            progress.appendSplit(CardioSplit(
                index: nextSplitIndex,
                distanceMeters: currentSplitDistanceMeters,
                duration: splitDuration,
                averageSecondsPerKm: averageSecondsPerKm,
                elevationGainMeters: currentSplitElevationGainMeters
            ))

            nextSplitIndex += 1
            currentSplitDistanceMeters -= Self.splitDistanceMeters
            currentSplitElevationGainMeters = 0
            currentSplitStartTimestamp = sample.timestamp
        }

        lastAcceptedSample = sample
        return true
    }

    /// Maps a horizontal accuracy reading (metres) onto `SignalConfidence`. Only ever called
    /// with values already passed by the `rejectionAccuracyMeters` guard above.
    private static func horizontalConfidence(forAccuracyMeters accuracy: Double) -> SignalConfidence {
        guard accuracy >= 0 else { return .unavailable }
        switch accuracy {
        case ..<10: return .high
        case ..<25: return .medium
        default: return .low
        }
    }

    /// Maps a vertical accuracy reading (metres) onto `SignalConfidence`, independently from
    /// horizontal confidence — iPhone vertical accuracy is materially noisier, and is not
    /// subject to the same rejection threshold as horizontal accuracy.
    private static func elevationConfidence(forAccuracyMeters accuracy: Double) -> SignalConfidence {
        guard accuracy >= 0 else { return .unavailable }
        switch accuracy {
        case ..<5: return .high
        case ..<15: return .medium
        default: return .low
        }
    }

    /// Great-circle distance between two coordinates, in metres. RithamCore cannot call
    /// `CLLocation.distance(from:)`, so this is a standard haversine implementation.
    private static func haversineDistanceMeters(
        latitude1: Double, longitude1: Double,
        latitude2: Double, longitude2: Double
    ) -> Double {
        let earthRadiusMeters = 6_371_000.0

        let lat1Radians = latitude1 * .pi / 180
        let lat2Radians = latitude2 * .pi / 180
        let deltaLatRadians = (latitude2 - latitude1) * .pi / 180
        let deltaLonRadians = (longitude2 - longitude1) * .pi / 180

        let a = sin(deltaLatRadians / 2) * sin(deltaLatRadians / 2)
            + cos(lat1Radians) * cos(lat2Radians) * sin(deltaLonRadians / 2) * sin(deltaLonRadians / 2)
        let c = 2 * atan2(a.squareRoot(), (1 - a).squareRoot())

        return earthRadiusMeters * c
    }
}
