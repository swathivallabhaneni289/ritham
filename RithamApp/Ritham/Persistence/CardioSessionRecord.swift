import Foundation
import SwiftData
import RithamCore

// The persisted cardio session. Follows `CalibrationBaselineRecord.swift`'s shape exactly: plain
// stored properties, one raw-value column per enum, and a computed property returning the
// RithamCore domain type or `nil` rather than trapping when a raw value no longer decodes.
//
// `CardioSplit` (RithamCore) is not `Codable` and this plan does not touch `CardioSession.swift`
// (that file belongs to plans 02-01/02-03) -- so splits are serialized through the private
// `EncodedSplit` DTO below, kept entirely inside this file, rather than adding `Codable`
// conformance to a type this plan does not own.
@Model
public final class CardioSessionRecord {
    public var id: UUID
    public var activityTypeRaw: String
    public var sourceRaw: String
    public var startedAt: Date
    public var endedAt: Date
    public var continuousDuration: TimeInterval
    public var distanceMeters: Double
    public var elevationGainMeters: Double
    public var horizontalConfidenceRaw: Int
    public var elevationConfidenceRaw: Int
    public var wasInterrupted: Bool
    public var notes: String?
    public var splitsData: Data

    public init(
        id: UUID,
        activityTypeRaw: String,
        sourceRaw: String,
        startedAt: Date,
        endedAt: Date,
        continuousDuration: TimeInterval,
        distanceMeters: Double,
        elevationGainMeters: Double,
        horizontalConfidenceRaw: Int,
        elevationConfidenceRaw: Int,
        wasInterrupted: Bool,
        notes: String? = nil,
        splitsData: Data = Data()
    ) {
        self.id = id
        self.activityTypeRaw = activityTypeRaw
        self.sourceRaw = sourceRaw
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.continuousDuration = continuousDuration
        self.distanceMeters = distanceMeters
        self.elevationGainMeters = elevationGainMeters
        self.horizontalConfidenceRaw = horizontalConfidenceRaw
        self.elevationConfidenceRaw = elevationConfidenceRaw
        self.wasInterrupted = wasInterrupted
        self.notes = notes
        self.splitsData = splitsData
    }

    /// Builds a record directly from a domain `CardioSession`, encoding its splits through
    /// `EncodedSplit`. This is the one place splits ever get encoded, so `HealthDataStore` never
    /// needs to know the encoding exists.
    public convenience init(session: CardioSession) {
        let encoded = session.progress.splits.map(EncodedSplit.init)
        let data = (try? JSONEncoder().encode(encoded)) ?? Data()
        self.init(
            id: session.id,
            activityTypeRaw: session.activityType.rawValue,
            sourceRaw: session.source.rawValue,
            startedAt: session.startedAt,
            endedAt: session.endedAt,
            continuousDuration: session.progress.continuousDuration,
            distanceMeters: session.progress.distanceMeters,
            elevationGainMeters: session.progress.elevationGainMeters,
            horizontalConfidenceRaw: session.progress.horizontalConfidence.rawValue,
            elevationConfidenceRaw: session.progress.elevationConfidence.rawValue,
            wasInterrupted: session.progress.wasInterrupted,
            notes: session.notes,
            splitsData: data
        )
    }

    /// `nil` rather than a trap when `sourceRaw`, `horizontalConfidenceRaw` or
    /// `elevationConfidenceRaw` no longer matches a known case (T-01-64's pattern). `activityType`
    /// can never fail this way -- `ActivityType` is a `RawRepresentable` struct with a
    /// non-failable initializer (CARDIO-01's extensible-vocabulary design), not a closed enum.
    public var session: CardioSession? {
        guard
            let source = CardioCaptureSource(rawValue: sourceRaw),
            let horizontalConfidence = SignalConfidence(rawValue: horizontalConfidenceRaw),
            let elevationConfidence = SignalConfidence(rawValue: elevationConfidenceRaw)
        else {
            return nil
        }

        let splits = (try? JSONDecoder().decode([EncodedSplit].self, from: splitsData))?
            .map(\.split) ?? []

        let progress = CardioProgress(
            continuousDuration: continuousDuration,
            distanceMeters: distanceMeters,
            elevationGainMeters: elevationGainMeters,
            splits: splits,
            horizontalConfidence: horizontalConfidence,
            elevationConfidence: elevationConfidence,
            wasInterrupted: wasInterrupted
        )

        return CardioSession(
            id: id,
            activityType: ActivityType(rawValue: activityTypeRaw),
            source: source,
            startedAt: startedAt,
            endedAt: endedAt,
            progress: progress,
            notes: notes
        )
    }
}

/// A `Codable` mirror of `CardioSplit` used only for `splitsData`'s JSON encoding. Splits are
/// never reparented (unlike `LiftSetRecord`), so they carry no independent identity here -- an
/// encoded array is enough.
private struct EncodedSplit: Codable {
    let index: Int
    let distanceMeters: Double
    let duration: TimeInterval
    let averageSecondsPerKm: Double
    let elevationGainMeters: Double

    init(_ split: CardioSplit) {
        index = split.index
        distanceMeters = split.distanceMeters
        duration = split.duration
        averageSecondsPerKm = split.averageSecondsPerKm
        elevationGainMeters = split.elevationGainMeters
    }

    var split: CardioSplit {
        CardioSplit(
            index: index,
            distanceMeters: distanceMeters,
            duration: duration,
            averageSecondsPerKm: averageSecondsPerKm,
            elevationGainMeters: elevationGainMeters
        )
    }
}
