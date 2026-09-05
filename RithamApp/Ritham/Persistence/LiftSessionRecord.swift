import Foundation
import SwiftData

// The persisted lift session shell. Deliberately stores no set array -- `LiftSetRecord` is its
// own independently addressable `@Model` (see that file's header comment), and `HealthDataStore`
// assembles the domain `LiftSession` by combining this record with its matching
// `LiftSetRecord`s fetched separately. Keeping this record set-free is what makes STRENGTH-05's
// reparenting a plain field write on the set rather than a structural change to this record.
@Model
public final class LiftSessionRecord {
    public var id: UUID
    public var startedAt: Date
    public var endedAt: Date?
    public var notes: String?

    public init(
        id: UUID,
        startedAt: Date,
        endedAt: Date? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.notes = notes
    }
}
