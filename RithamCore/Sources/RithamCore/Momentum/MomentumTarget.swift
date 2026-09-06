import Foundation

// MOMENTUM-01's weekly consistency target — the shared cross-modality count a user's qualifying
// cardio/lift sessions must reach each Momentum week — plus D-10's endowed week-one head start.
//
// D-10's reading (stated here verbatim so a later reviewer does not have to reconstruct it): the
// endowed credit is one credited session in the user's first Momentum week only, so a default
// target of 3 is met by 2 real qualifying sessions and an adjusted target of 5 by 4. This
// simultaneously satisfies REQUIREMENTS.md's literal "starts pre-filled at 1/3 after the user's
// first logged session" (`displayedCount` is 1 before any qualifying session lands in that week)
// and D-10's stated head start (`requiredQualifyingSessions` is target minus one). This is a
// one-time, week-one-only target adjustment, never a change to the per-session qualification bar
// itself — the bar lives in `CalibrationThreshold`
// (RithamCore/Sources/RithamCore/Calibration/CalibrationSession.swift) and this file must not
// reference or restate it.
//
// The endowed week is anchored to the week containing the user's earliest logged session. Plan
// 03-03's reconciliation fold never revisits weeks at or before its own last-reconciled anchor,
// so deleting that earliest session later can never retroactively move the endowed week or claw
// back an already-credited week.
public enum MomentumTarget {

    /// The only weekly-target values a user may select. `HealthDataStore.supportedMomentumTargets`
    /// (plan 03-04) and `MomentumTargetView`'s picker (plan 03-07) both pin themselves against
    /// this constant with their own tests — this is the phase-wide single source of truth.
    public static let supported: Set<Int> = [2, 3, 4, 5]

    /// The weekly target every new user starts with.
    public static let defaultTarget: Int = 3

    /// D-10's one-time, week-one-only credited session.
    public static let endowedCreditPerFirstWeek: Int = 1

    /// Whether `target` is one of the values a user may select.
    public static func isSupported(_ target: Int) -> Bool {
        supported.contains(target)
    }

    /// D-10: returns `endowedCreditPerFirstWeek` when `weekStart` is the same week as the user's
    /// first-ever logged session, and 0 for every other week — including when the user has no
    /// logged session at all (`firstSessionWeekStart == nil`), so there is no free credit before
    /// a first session exists.
    public static func endowedCredit(weekStart: Date, firstSessionWeekStart: Date?) -> Int {
        guard let firstSessionWeekStart, firstSessionWeekStart == weekStart else {
            return 0
        }
        return endowedCreditPerFirstWeek
    }

    /// The number of real qualifying sessions still needed this week: `target` minus
    /// `endowedCredit`, floored at 1 so a supported target can never require zero real sessions.
    public static func requiredQualifyingSessions(target: Int, endowedCredit: Int) -> Int {
        max(1, target - endowedCredit)
    }

    /// The count to display toward the weekly target: real qualifying sessions plus the endowed
    /// credit, capped at `target` so the displayed progress never exceeds the target itself.
    public static func displayedCount(qualifying: Int, endowedCredit: Int, target: Int) -> Int {
        min(target, qualifying + endowedCredit)
    }
}
