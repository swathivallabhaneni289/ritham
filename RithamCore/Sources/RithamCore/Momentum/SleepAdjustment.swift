import Foundation

/// A user's self-reported sleep quality for one day.
///
/// Exactly three cases, each carrying a stable raw value used for persistence and copy lookups.
public enum SleepQuality: String, CaseIterable, Sendable, Equatable, Codable {
    case great
    case ok
    case poor
}

/// One day's sleep self-report.
///
/// This type is deliberately minimal, and that minimalism is load-bearing. Per this phase's D-03,
/// the sleep check-in is a structurally independent self-report signal that shares zero state with
/// the rest of the Momentum domain: it stores only an identifier, the day it applies to, the
/// reported quality and an optional note, and nothing else, ever. It has no shield field, no
/// streak field, no recovery-week membership and no milestone state, and it must never grow one --
/// that separation is what keeps RECOVERY-01's "never auto-consumes" and "never auto-triggers"
/// invariants structurally true rather than merely untested.
public struct SleepCheckIn: Sendable, Equatable, Identifiable {
    public let id: UUID

    /// Day-granularity date this check-in applies to. The caller is responsible for normalizing
    /// this to the start of the day before constructing a value; this type performs no
    /// normalization of its own.
    public let day: Date

    public let quality: SleepQuality

    public let note: String?

    public init(id: UUID = UUID(), day: Date, quality: SleepQuality, note: String? = nil) {
        self.id = id
        self.day = day
        self.quality = quality
        self.note = note
    }
}

/// Whether a day's suggested session should shift lighter.
///
/// Named `unchanged` rather than `none` so call sites that also handle an absent check-in
/// (`SleepCheckIn?`) read unambiguously: `.unchanged` describes the shift decision itself, not the
/// presence or absence of a check-in.
public enum IntensityShift: String, Sendable, Equatable {
    case unchanged
    case lighter
}

/// RECOVERY-01's decision rule: a pure function of an optional sleep check-in.
///
/// This file is the enforcement point for four of RECOVERY-01's seven invariants:
/// - the qualifying-session bar for Momentum never changes because of a sleep check-in -- nothing
///   in this file imports or references any qualification-threshold type or constant, and nothing
///   here computes or restates a duration, a set minimum or an exercise minimum;
/// - a skipped check-in has zero effect and is indistinguishable from a day with no check-in
///   surface at all -- `shift(for: nil)`, `shift(for: .great)` and `shift(for: .ok)` all return
///   the same `.unchanged` value, never an assumed poor state;
/// - this rule never consumes a shield;
/// - this rule never triggers a recovery pause of a week's target.
/// The last two hold structurally, not just by test coverage: no ledger, award, comeback-window or
/// recovery-week type is imported or referenced anywhere in this file.
public enum SleepAdjustment {
    /// Returns `.lighter` only for a `.poor` check-in. `.great`, `.ok`, and `nil` (no check-in at
    /// all) all return `.unchanged` -- skipping the check-in is never treated as an assumed poor
    /// state.
    public static func shift(for checkIn: SleepCheckIn?) -> IntensityShift {
        guard let checkIn, checkIn.quality == .poor else {
            return .unchanged
        }
        return .lighter
    }

    /// The one numeric lever a `.lighter` shift applies to a prescribed set count.
    ///
    /// Planning decision, in the same spirit as this codebase's other documented single-lever
    /// mappings: reducing prescribed volume by exactly one set, floored at one, is the only
    /// numeric adjustment the generated plan's existing shape offers that moves toward
    /// technique-light, lower-force work. It can never increase load: `.unchanged` always returns
    /// `sets` untouched, and `.lighter` always returns a value less than or equal to `sets`. It
    /// deliberately does not touch any rep range or added weight, and it is not invented clinical
    /// content -- it is a volume trim, nothing more. A future phase with real graduated
    /// prescriptions can refine this mapping without changing this function's signature.
    public static func adjustedSetCount(_ sets: Int, shift: IntensityShift) -> Int {
        switch shift {
        case .unchanged:
            return sets
        case .lighter:
            return max(1, sets - 1)
        }
    }
}
