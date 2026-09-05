import SwiftData

// A single-row preference record. This is preference data in the same category as
// `FoodAllergenRecord`: no gate resolution, tag derivation or screening logic ever reads it.
// `routeComparisonOptIn` defaults to `false` so CARDIO-03's route-comparison feature is opt-in
// rather than default-on -- the storage-level expression of the project's permanent prohibition
// on any cross-user aggregate location visualization. `hasCompletedPreAssessment` also defaults
// to `false`: a fresh install has not yet run ONBOARD-01's triggered pre-assessment.
/// `weeklyFrequency` has no instantiation default -- `HealthDataStore.loadWeeklyFrequency` is
/// what supplies the stated default (3) when no row exists yet, following
/// `loadCalibrationBaseline`'s "never return a blank state" discipline rather than baking a
/// default into this model.
@Model
public final class WorkoutPreferenceRecord {
    public var weeklyFrequency: Int
    public var hasCompletedPreAssessment: Bool
    public var routeComparisonOptIn: Bool

    public init(
        weeklyFrequency: Int,
        hasCompletedPreAssessment: Bool = false,
        routeComparisonOptIn: Bool = false
    ) {
        self.weeklyFrequency = weeklyFrequency
        self.hasCompletedPreAssessment = hasCompletedPreAssessment
        self.routeComparisonOptIn = routeComparisonOptIn
    }
}
