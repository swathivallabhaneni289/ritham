import Foundation
import SwiftData
import RithamCore

// `LiftSetRecord` is a top-level `@Model` with its own independent identity, never a value type
// embedded inline in `LiftSessionRecord`'s array -- because STRENGTH-05 reparents sets between
// sessions during a retroactive merge or split (`SessionRevision.merge`/`.split`), and a value
// type embedded in a session's array cannot survive that move without being recreated. Modelling
// the owning session as a stored `sessionID` (a plain field), rather than a SwiftData
// `@Relationship`, keeps reparenting a single field write: `HealthDataStore.applyRevision` can
// move a set to a different session by writing one property, never restructuring an array. This
// mirrors `ConditionTagRecord`'s "many independently addressable child records queried and
// deleted via `FetchDescriptor`" shape, not `CalibrationBaselineRecord`'s single-row shape.
@Model
public final class LiftSetRecord {
    public var id: UUID
    public var sessionID: UUID
    public var exerciseIdentifier: String
    public var weightKg: Double?
    public var reps: Int
    public var isWarmUp: Bool
    public var equipmentRaw: String?
    public var supersetGroupID: UUID?
    public var orderIndex: Int
    public var completedAt: Date

    public init(
        id: UUID,
        sessionID: UUID,
        exerciseIdentifier: String,
        weightKg: Double? = nil,
        reps: Int,
        isWarmUp: Bool = false,
        equipmentRaw: String? = nil,
        supersetGroupID: UUID? = nil,
        orderIndex: Int,
        completedAt: Date
    ) {
        self.id = id
        self.sessionID = sessionID
        self.exerciseIdentifier = exerciseIdentifier
        self.weightKg = weightKg
        self.reps = reps
        self.isWarmUp = isWarmUp
        self.equipmentRaw = equipmentRaw
        self.supersetGroupID = supersetGroupID
        self.orderIndex = orderIndex
        self.completedAt = completedAt
    }

    /// Builds a record directly from a domain `LiftSet`, tagged with the session it currently
    /// belongs to. Reuses the set's own `id` (never mints a new one) so a re-save never
    /// duplicates identity.
    public convenience init(set: LiftSet, sessionID: UUID) {
        self.init(
            id: set.id,
            sessionID: sessionID,
            exerciseIdentifier: set.exerciseIdentifier,
            weightKg: set.weightKg,
            reps: set.reps,
            isWarmUp: set.isWarmUp,
            equipmentRaw: set.equipment?.rawValue,
            supersetGroupID: set.supersetGroupID?.rawValue,
            orderIndex: set.orderIndex,
            completedAt: set.completedAt
        )
    }

    /// `nil` rather than a trap when `equipmentRaw` is present but no longer matches a known
    /// `Equipment` case (T-01-64's pattern). A `nil` `equipmentRaw` itself is not a decode
    /// failure -- it means "no equipment," a valid state `LiftSet.equipment` already supports.
    public var equipment: Equipment? {
        guard let equipmentRaw else { return nil }
        return Equipment(rawValue: equipmentRaw)
    }

    /// Reconstructs the domain `LiftSet`. `supersetGroupID`'s wrapper type has no raw-value
    /// vocabulary to fail to decode -- it is a plain UUID wrapper, so this direction never drops
    /// data the way `equipment` above can.
    public var liftSet: LiftSet {
        LiftSet(
            id: id,
            exerciseIdentifier: exerciseIdentifier,
            weightKg: weightKg,
            reps: reps,
            isWarmUp: isWarmUp,
            equipment: equipment,
            supersetGroupID: supersetGroupID.map(SupersetGroupID.init),
            orderIndex: orderIndex,
            completedAt: completedAt
        )
    }
}
