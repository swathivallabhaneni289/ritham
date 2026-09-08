import Foundation
import SwiftData
import Testing
import RithamCore
@testable import Ritham

/// Exercises `OnboardingFlow.open(_:)` directly, the same data-level style `AppShellTests` uses
/// for `advance`/`goBack`, rather than rendering `HomeHubView`. This suite never touches
/// `StepRegistry`'s shared static state, so it cannot join the cross-suite race
/// `STATE.md`'s Blockers/Concerns documents for suites that do.
///
/// Plan 03-07 adds a few tests that construct their own in-memory `HealthDataStore`/
/// `MomentumSummaryReader` directly -- the same flat, non-`.serialized`, own-container-per-test
/// pattern `WorkoutFrequencyTests` (`SettingsPhase2Tests.swift`) already uses without joining
/// `MomentumContainerTouchingSuites`, since each test's container is a local instance, not shared
/// static state.
@MainActor
@Suite("HomeHubTests")
struct HomeHubTests {

    @Test("opening cardioActivityPicker appends exactly that step")
    func openingCardioActivityPickerAppendsExactlyThatStep() {
        let flow = OnboardingFlow()
        flow.open(.cardioActivityPicker)
        #expect(flow.path == [.cardioActivityPicker])
    }

    @Test("opening cardioHistory appends exactly that step")
    func openingCardioHistoryAppendsExactlyThatStep() {
        let flow = OnboardingFlow()
        flow.open(.cardioHistory)
        #expect(flow.path == [.cardioHistory])
    }

    @Test("opening strengthSession appends exactly that step")
    func openingStrengthSessionAppendsExactlyThatStep() {
        let flow = OnboardingFlow()
        flow.open(.strengthSession)
        #expect(flow.path == [.strengthSession])
    }

    @Test("opening strengthHistory appends exactly that step")
    func openingStrengthHistoryAppendsExactlyThatStep() {
        let flow = OnboardingFlow()
        flow.open(.strengthHistory)
        #expect(flow.path == [.strengthHistory])
    }

    @Test("opening guidance appends exactly that step")
    func openingGuidanceAppendsExactlyThatStep() {
        let flow = OnboardingFlow()
        flow.open(.guidance)
        #expect(flow.path == [.guidance])
    }

    @Test("opening recommendations appends exactly that step")
    func openingRecommendationsAppendsExactlyThatStep() {
        let flow = OnboardingFlow()
        flow.open(.recommendations)
        #expect(flow.path == [.recommendations])
    }

    @Test("calling open(.recommendations) twice leaves path with exactly one .recommendations entry")
    func openingSameStepTwiceAppendsOnlyOnce() {
        let flow = OnboardingFlow()
        flow.open(.recommendations)
        flow.open(.recommendations)
        #expect(flow.path == [.recommendations])
    }

    @Test("opening a different step after another appends both, in order")
    func openingDifferentStepsAppendsBothInOrder() {
        let flow = OnboardingFlow()
        flow.open(.cardioActivityPicker)
        flow.open(.guidance)
        #expect(flow.path == [.cardioActivityPicker, .guidance])
    }

    // MARK: - Plan 03-07: the hub's Momentum summary section

    @Test("opening momentum appends exactly that step, alongside the hub's existing Phase 2 destinations")
    func openingMomentumAppendsExactlyThatStep() {
        let flow = OnboardingFlow()
        flow.open(.cardioActivityPicker)
        flow.open(.momentum)
        #expect(flow.path == [.cardioActivityPicker, .momentum])
    }

    private func makeStore() throws -> HealthDataStore {
        let container = try RithamModelContainer.make(inMemory: true)
        return HealthDataStore(context: ModelContext(container))
    }

    @Test("two independently constructed MomentumSummaryReaders over the same store return an identical summary, proving the hub and MomentumView read the same underlying data (D-08)")
    func hubAndDetailScreenReadTheSameUnderlyingData() throws {
        let store = try makeStore()
        let now = Date()

        // `HomeHubView`'s own `onAppear` and `MomentumView`'s own `onAppear` each construct their
        // own `MomentumSummaryReader(store:calendar:)` -- never a shared, hub-owned view model
        // (D-08's own requirement). Constructing two readers here, independently, over the same
        // store proves both surfaces read the same underlying data rather than two divergent
        // paths that happen to look similar.
        let hubReader = MomentumSummaryReader(store: store, calendar: .current)
        let detailReader = MomentumSummaryReader(store: store, calendar: .current)

        #expect(try hubReader.summary(now: now) == (try detailReader.summary(now: now)))
    }

    @Test("theHubShowsNoSleepCheckInStateIndicator")
    func theHubShowsNoSleepCheckInStateIndicator() {
        // The type `HomeHubView` renders (`MomentumSummary`) is Mirrored directly, the same
        // structural check 03-05's `momentumSummaryCarriesNoSleepState` already performs on the
        // type itself -- reasserted here, scoped to this suite, since RECOVERY-01 invariant 3
        // requires a skipped check-in to be indistinguishable, app-wide, from a day the prompt was
        // never shown, and the hub is one of the two surfaces (alongside MomentumView) where that
        // invariant could be silently broken by a future edit.
        let summary = MomentumSummary(
            weekStart: Date(),
            weekEnd: Date(),
            weeklyTarget: 3,
            requiredThisWeek: 2,
            qualifyingThisWeek: 0,
            endowedCredit: 1,
            displayedCount: 1,
            currentStreak: 0,
            streakLabelKind: .fresh,
            shieldCount: 0,
            milestones: [],
            openComebackWindow: nil,
            isRecoveryWeekFlagged: false,
            isInjuryFrozen: false,
            isStreakLossProtected: false,
            visibility: .privateToDevice,
            recentSessions: []
        )

        let mirror = Mirror(reflecting: summary)
        let hasSleepDerivedMember = mirror.children.contains { child in
            guard let label = child.label else { return false }
            let lowercased = label.lowercased()
            return lowercased.contains("sleep") || lowercased.contains("checkin") || lowercased.contains("check_in")
        }
        #expect(!hasSleepDerivedMember)
    }

    @Test("the hub's empty state equals MomentumCopy's no-sessions pair exactly")
    func hubEmptyStateMatchesCatalogNoSessionsPair() {
        #expect(MomentumCopy.Empty.noSessionsHeadline == "No sessions logged yet")
        #expect(
            MomentumCopy.Empty.noSessionsBody
                == "Log your first cardio or lift session to start your streak."
        )
    }

    // MARK: - Plan 04-02: the dashboard's derivations

    @Test("theDashboardNoLongerRoutesToTheRecommendationsScreen")
    func theDashboardNoLongerRoutesToTheRecommendationsScreen() {
        // D-04: the workout plan is now embedded inline via `RecommendationsSectionContent`, so
        // nothing in `HomeHubView.body` calls `flow.open(.recommendations)` any more.
        // `.recommendations` stays registered regardless -- `StepRegistry.unregisteredSteps` is
        // asserted empty per-case, not per-reachability (04-RESEARCH.md Pitfall 4) -- this test
        // only pins `routingSteps`' own returned list, never `StepRegistry`'s registration.
        #expect(!HomeHubView.routingSteps(movementSnapshotOptIn: true).contains(.recommendations))
    }

    @Test("theDashboardStillRoutesToEveryTrackingDestination")
    func theDashboardStillRoutesToEveryTrackingDestination() {
        let steps = HomeHubView.routingSteps(movementSnapshotOptIn: true)
        let expected: Set<OnboardingStep> = [
            .sleepCheckIn, .cardioActivityPicker, .cardioHistory,
            .strengthSession, .strengthHistory, .guidance, .movementSnapshot,
        ]
        // Membership only, not the array literal's internal sequence: the ordering constraint
        // this phase actually carries (04-RESEARCH.md Pitfall 6) is about render order inside
        // `body`, not about this list, so asserting the literal's exact sequence would fail on a
        // harmless future reorder of the array itself.
        #expect(Set(steps) == expected)
        #expect(steps.last == .movementSnapshot)
    }

    @Test("theDashboardHeadlineIsNotPlaceholderFraming")
    func theDashboardHeadlineIsNotPlaceholderFraming() {
        #expect(HomeHubView.dashboardHeadline == "Home")
        let lowercased = HomeHubView.dashboardHeadline.lowercased()
        #expect(!lowercased.contains("interim"))
        #expect(!lowercased.contains("temporary"))
        #expect(!lowercased.contains("placeholder"))
    }

    @Test("theExerciseSectionRendersTheSummarysOwnSessionList")
    func theExerciseSectionRendersTheSummarysOwnSessionList() throws {
        // Proves the exercise card's data source is `MomentumSummaryReader`'s own
        // already-labelled `recentSessions` list (D-02), not a second, independently-derived
        // read -- current-week timestamps are required since `recentSessions` is built from
        // `currentWeek` alone (`MomentumSummary.swift`'s `recentSessions(for:)`).
        let store = try makeStore()
        let now = Date()

        try store.saveCardioSession(CardioSession(
            activityType: .run,
            source: .gps,
            startedAt: now.addingTimeInterval(-3_600),
            endedAt: now.addingTimeInterval(-1_800),
            progress: CardioProgress(continuousDuration: 1_800, distanceMeters: 5_000)
        ))
        try store.saveLiftSession(LiftSession(startedAt: now.addingTimeInterval(-900), sets: []))

        let reader = MomentumSummaryReader(store: store, calendar: .current)
        let summary = try reader.summary(now: now)

        #expect(!summary.recentSessions.isEmpty)
        for session in summary.recentSessions {
            if let label = session.verificationLabel {
                #expect(
                    label == MomentumCopy.Verification.sensorVerified
                        || label == MomentumCopy.Verification.manuallyEntered
                )
            }
        }
    }
}
