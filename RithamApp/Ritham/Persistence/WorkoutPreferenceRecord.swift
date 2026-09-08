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
///
/// `movementSnapshotOptIn` (MOMENTUM-07) defaults to `false`: the Daily Movement Snapshot is
/// optional and opt-in, never on by default. It lives on this general preference row rather than
/// on `MomentumStateRecord` deliberately -- D-09 requires the snapshot to carry no association
/// with streak, shield or target state, and putting its preference on the Momentum row would be
/// exactly that association. `WorkoutPreferenceRecord` has no relationship or foreign key to any
/// Momentum record, so this column keeps that separation intact.
///
/// `hasCompletedOnboarding` defaults to `false`, matching `hasCompletedPreAssessment`'s own
/// convention: a fresh install has not yet reached `.screeningComplete`. `OnboardingRootView`
/// reads this to decide whether the app's single navigation container should root at `.welcome`
/// or `.home` -- before this field existed there was no persisted signal at all, so every
/// relaunch re-ran onboarding from the very first screen regardless of completion state.
@Model
public final class WorkoutPreferenceRecord {
    public var weeklyFrequency: Int
    public var hasCompletedPreAssessment: Bool
    public var routeComparisonOptIn: Bool
    public var movementSnapshotOptIn: Bool
    public var hasCompletedOnboarding: Bool

    public init(
        weeklyFrequency: Int,
        hasCompletedPreAssessment: Bool = false,
        routeComparisonOptIn: Bool = false,
        movementSnapshotOptIn: Bool = false,
        hasCompletedOnboarding: Bool = false
    ) {
        self.weeklyFrequency = weeklyFrequency
        self.hasCompletedPreAssessment = hasCompletedPreAssessment
        self.routeComparisonOptIn = routeComparisonOptIn
        self.movementSnapshotOptIn = movementSnapshotOptIn
        self.hasCompletedOnboarding = hasCompletedOnboarding
    }
}
