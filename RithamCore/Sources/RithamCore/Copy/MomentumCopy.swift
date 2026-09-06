// These strings are transcribed verbatim, character for character, from
// 03-UI-SPEC.md's Copywriting Contract "Verbatim shipped strings" table. Downstream
// view plans (03-06 through 03-09) reference these identifiers rather than re-transcribing
// or drafting a second copy of any string.
//
// Every string in this file is governed by the framing rule in 03-UI-SPEC.md's
// Copywriting Contract: informational and competence-based, describing what happened
// as a fact the user can act on, never threat-framed, never urgent, never punitive.
// MomentumCopyTests enforces the Copywriting Contract's banned-lexicon table
// mechanically against the shipped string values below, not against source text.
//
// This phase adds no error string of any kind. 03-UI-SPEC.md's Copywriting Contract
// requires reusing OnboardingCopy.Errors.savingFailed verbatim for any Momentum/Recovery
// saving failure rather than drafting a second one; views reference that constant directly.
//
// No em dash and no en dash (the two Unicode dash characters, not a plain ASCII hyphen)
// appears anywhere in this file, comments included, matching OnboardingCopy.swift and
// ScreeningCopy.swift's house-style convention for this directory. Four rows of
// 03-UI-SPEC.md's verbatim-strings table (the Recovery Week alert body, the injury alert
// body, the Movement Snapshot toggle helper, and the no-shields-yet empty state body) use
// an em dash in the source table. Each is rewritten here using a comma or a period split,
// the same house-style remedy ScreeningCopy.swift's own header names for exactly this
// situation, preserving the source sentence's meaning and framing without reintroducing
// the punctuation mark this directory excludes. Every substitution is called out at its
// declaration below.
public enum MomentumCopy {

    // MARK: - Weekly progress

    public enum Progress {
        public static func weekly(count: Int, target: Int) -> String {
            "This week: \(count) of \(target)"
        }

        public static func weeklyAccessibility(count: Int, target: Int) -> String {
            "This week: \(count) of \(target) qualifying sessions"
        }
    }

    // MARK: - Streak

    public enum Streak {
        public static func streak(weeks: Int) -> String {
            "\(weeks)-week streak"
        }

        /// Shown after a comeback window closes unclaimed. Frames the new week as a rebuild,
        /// never as an erasure back to a zero count.
        public static let rebuiltStreak = "Week 1 of your rebuilt streak"
    }

    // MARK: - Shields

    public enum Shields {
        public static func shields(earned: Int) -> String {
            "\(earned) of 3 shields"
        }
    }

    // MARK: - Comeback Session

    public enum Comeback {
        public static let headline = "Comeback Session available"

        public static func body(deadline: String) -> String {
            "Log one qualifying session by \(deadline) to continue your streak."
        }

        public static let button = "Log a Comeback Session"
    }

    // MARK: - Milestones

    public enum Milestones {
        public static let week4 = "A real month of consistency."
        public static let week12 = "You've built a real 12-week habit."
        public static let week26 = "Half a year of showing up."
        public static let week52 = "A full year of Momentum."

        /// Returns the tier line for an exact tier week count (4, 12, 26 or 52), or `nil` for
        /// any other week count.
        public static func line(forWeekCount weekCount: Int) -> String? {
            switch weekCount {
            case 4: return week4
            case 12: return week12
            case 26: return week26
            case 52: return week52
            default: return nil
            }
        }
    }

    // MARK: - Recovery Week flag

    public enum RecoveryWeek {
        public static let flagButton = "Flag Recovery Week"
        public static let alertTitle = "Flag this week as a Recovery Week?"

        /// Source table rewrite: the source em dash before "injury, illness, travel, or just
        /// needing rest" is replaced with ", including" here, preserving the same list of
        /// example reasons without the excluded punctuation mark.
        public static let alertBody = "This pauses this week's target without affecting your streak. You can do this anytime, for any reason, including injury, illness, travel, or just needing rest."

        public static let confirmButton = "Flag Recovery Week"
    }

    // MARK: - Injury / pain flag

    public enum Injury {
        public static let flagButton = "Flag pain or injury"
        public static let alertTitle = "Freeze your streak for pain or injury?"

        /// Source table rewrite: the source em dash is replaced with a period, splitting the
        /// sentence in two, preserving both clauses' meaning without the excluded punctuation
        /// mark.
        public static let alertBody = "Your streak stays exactly where it is until you clear this flag. No target, nothing to catch up on."

        public static let confirmButton = "Freeze streak"
        public static let clearButton = "Clear injury flag"
        public static let clearAlertTitle = "Clear injury flag and resume Momentum?"
    }

    // MARK: - Sleep check-in

    public enum Sleep {
        public static let headline = "How did you sleep?"
        public static let optionGreat = "Great"
        public static let optionOK = "OK"
        public static let optionPoor = "Poor"
        public static let noteFieldLabel = "Add a note (optional)"
    }

    // MARK: - Recovery-aware plan banner and equal-weight session choice

    public enum Plan {
        public static let banner = "Today's suggestions are a bit lighter, based on your sleep check-in."

        /// Not one of 03-UI-SPEC.md's verbatim-strings table rows. RECOVERY-01's invariant 2
        /// requires "do the original session instead" to be an equal-weight control alongside
        /// the lighter suggestion; these two constants are planner-authored additions closing
        /// that gap, the same precedent plan 01-15 set for a CTA the UI-SPEC table had no row
        /// for. Both are plain, non-comparative, non-urgent labels naming which version of the
        /// plan is being shown -- neither wording marks one option as preferred, and neither
        /// carries urgency punctuation.
        public static let showOriginalCTA = "Show original session"

        /// See `showOriginalCTA`'s doc comment: the equal-weight counterpart naming the other
        /// version of the plan being shown.
        public static let showLighterCTA = "Show lighter session"
    }

    // MARK: - Daily Movement Snapshot

    public enum Snapshot {
        public static let toggleLabel = "Show Daily Movement Snapshot"

        /// Source table rewrite: the source em dash is replaced with ", with", preserving the
        /// same clause without the excluded punctuation mark.
        public static let toggleHelper = "A plain calendar of your activity, with no streak, shield, or target attached."

        public static let toggleOptionOn = "On"
        public static let toggleOptionOff = "Off"
    }

    // MARK: - Weekly target

    public enum Target {
        public static let pickerPrompt = "Weekly Momentum target"
        public static let pickerHelper = "How many qualifying sessions do you want to aim for each week? Change this anytime."
    }

    // MARK: - Empty states

    public enum Empty {
        public static let noSessionsHeadline = "No sessions logged yet"
        public static let noSessionsBody = "Log your first cardio or lift session to start your streak."

        public static let noShieldsHeadline = "No shields yet"

        /// Source table rewrite: the source em dash is replaced with a period, splitting the
        /// sentence in two, preserving both clauses' meaning without the excluded punctuation
        /// mark.
        public static let noShieldsBody = "Shields build automatically after 4 consecutive successful weeks. Nothing to do but keep going."

        public static let noMilestonesHeadline = "No milestones yet"
        public static let noMilestonesBody = "Your first milestone arrives at 4 weeks of Momentum."

        public static let noSnapshotEntriesHeadline = "No entries yet"
        public static let noSnapshotEntriesBody = "Movement Snapshot fills in as you log activity."
    }

    // MARK: - Session verification label

    /// Reuses the exact existing strings `CardioHistoryView.swift` already ships (see that
    /// file's session row, `Text(session.source.isSensorVerified ? "Sensor-verified" :
    /// "Manually entered")`), transcribed verbatim rather than drafted anew, per
    /// 03-UI-SPEC.md Component 11.
    ///
    /// Lift session rows get no verification label at all in any Momentum history view.
    /// `LiftSessionRecord` has no capture-source field -- every lift session is manually
    /// logged by construction -- so a combined cardio+lift history list must render lift
    /// rows with zero label in that column. A default "Manually entered" label must never be
    /// invented for a field that does not exist on that record type.
    public enum Verification {
        public static let sensorVerified = "Sensor-verified"
        public static let manuallyEntered = "Manually entered"
    }
}
