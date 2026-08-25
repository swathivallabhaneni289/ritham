// The SCOFF eating-disorder screen (docs/health-screening.md §1.4/§1.5). §1.5 requires that
// the computed score never surface to the user as a number, a positive/negative result, or a
// label naming a disorder — it resolves to the same neutral, supportive referral message as
// every other required-blocking trigger. `yesCount` below is for internal gate resolution
// only and must never be bound to a view; `isPositiveScreen` is the only value callers
// outside the engine should read.

/// The five SCOFF questionnaire answers (ED-1 through ED-5). Deliberately has no
/// `CustomStringConvertible` conformance and no display-name or summary property, so there
/// is no accidental path from this type to a user-visible score or label.
public struct SCOFFResponses: Sendable, Equatable, Codable {
    public var ed1MakesSelfSickWhenFull: YesNo
    public var ed2WorriesLostControlOverEating: YesNo
    public var ed3RecentSignificantWeightLoss: YesNo
    public var ed4BelievesSelfFatWhenToldTooThin: YesNo
    public var ed5FoodDominatesLife: YesNo

    public init(
        ed1MakesSelfSickWhenFull: YesNo,
        ed2WorriesLostControlOverEating: YesNo,
        ed3RecentSignificantWeightLoss: YesNo,
        ed4BelievesSelfFatWhenToldTooThin: YesNo,
        ed5FoodDominatesLife: YesNo
    ) {
        self.ed1MakesSelfSickWhenFull = ed1MakesSelfSickWhenFull
        self.ed2WorriesLostControlOverEating = ed2WorriesLostControlOverEating
        self.ed3RecentSignificantWeightLoss = ed3RecentSignificantWeightLoss
        self.ed4BelievesSelfFatWhenToldTooThin = ed4BelievesSelfFatWhenToldTooThin
        self.ed5FoodDominatesLife = ed5FoodDominatesLife
    }

    /// Internal gate-resolution input only. Must never be bound to a view, displayed as a
    /// number, or logged anywhere a user could see it — §1.5 forbids surfacing a score.
    public var yesCount: Int {
        [
            ed1MakesSelfSickWhenFull,
            ed2WorriesLostControlOverEating,
            ed3RecentSignificantWeightLoss,
            ed4BelievesSelfFatWhenToldTooThin,
            ed5FoodDominatesLife,
        ].filter { $0 == .yes }.count
    }

    /// Two or more "yes" answers is the established SCOFF positive-screen threshold (§1.4).
    /// This is the only value callers outside the gate engine should read.
    public var isPositiveScreen: Bool {
        yesCount >= 2
    }

    /// True only when `selection` contains the eating-disorder-history checklist item — per
    /// D-10, the SCOFF screen is not shown to every user, only those who select it.
    public static func isTriggered(by selection: ChecklistSelection) -> Bool {
        selection.items.contains(.eatingDisorderHistory)
    }
}
