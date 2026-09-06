import Foundation
import SwiftData
import Testing
import RithamCore
@testable import Ritham

extension MomentumContainerTouchingSuites {
    @MainActor
    @Suite("MomentumSummaryTests", .serialized)
    struct MomentumSummaryTests {

        /// A fixed UTC calendar, not the environment's default -- every fixture date below is
        /// constructed against this same calendar, and passed to both `HealthDataStore` and
        /// `MomentumSummaryReader`, so week-boundary math is fully deterministic regardless of
        /// the machine running the test.
        private let calendar: Calendar = {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: "UTC")!
            return calendar
        }()

        private func makeStore() throws -> (store: HealthDataStore, context: ModelContext) {
            let container = try RithamModelContainer.make(inMemory: true)
            let context = ModelContext(container)
            return (HealthDataStore(context: context, calendar: calendar), context)
        }

        private func reader(for store: HealthDataStore) -> MomentumSummaryReader {
            MomentumSummaryReader(store: store, calendar: calendar)
        }

        /// 2024-01-08 is a Monday, matching `MomentumWeek`'s anchor weekday, so `date(2024, 1, 8)`
        /// falls inside the Momentum week whose boundary is `MomentumWeek.weekStart(containing:)`
        /// of that same instant.
        private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
            var components = DateComponents()
            components.year = y
            components.month = m
            components.day = d
            components.hour = h
            return calendar.date(from: components)!
        }

        private func qualifyingCardio(startedAt: Date) -> CardioSession {
            let duration = CalibrationThreshold.qualifyingWalkDuration + 60
            return CardioSession(
                activityType: .walk,
                source: .manualStopwatch,
                startedAt: startedAt,
                endedAt: startedAt.addingTimeInterval(duration),
                progress: CardioProgress(continuousDuration: duration)
            )
        }

        private func nonQualifyingCardio(startedAt: Date) -> CardioSession {
            CardioSession(
                activityType: .walk,
                source: .manualStopwatch,
                startedAt: startedAt,
                endedAt: startedAt.addingTimeInterval(60),
                progress: CardioProgress(continuousDuration: 60)
            )
        }

        // MARK: - Empty store

        @Test("an empty store yields a zeroed summary and does not throw")
        func emptyStoreYieldsZeroedSummaryAndDoesNotThrow() throws {
            let (store, _) = try makeStore()
            let summary = try reader(for: store).summary(now: Date())

            #expect(summary.currentStreak == 0)
            #expect(summary.shieldCount == 0)
            #expect(summary.milestones.isEmpty)
            #expect(summary.openComebackWindow == nil)
        }

        // MARK: - Endowed credit / target math

        @Test("a first-ever qualifying session in the current week applies the endowed credit")
        func firstSessionInCurrentWeekAppliesEndowedCredit() throws {
            let (store, _) = try makeStore()
            let now = date(2024, 1, 10)
            try store.saveCardioSession(qualifyingCardio(startedAt: now))

            let summary = try reader(for: store).summary(now: now)

            #expect(summary.weeklyTarget == 3)
            #expect(summary.qualifyingThisWeek == 1)
            #expect(summary.endowedCredit == 1)
            #expect(summary.displayedCount == 2)
        }

        @Test("the same fixture with the target set to 5 requires exactly 4 real qualifying sessions")
        func targetFiveRequiresFourRealSessions() throws {
            let (store, _) = try makeStore()
            try store.saveMomentumTarget(5)
            let now = date(2024, 1, 10)
            try store.saveCardioSession(qualifyingCardio(startedAt: now))

            let summary = try reader(for: store).summary(now: now)

            #expect(summary.requiredThisWeek == 4)
        }

        @Test("the endowed credit is zero for a week that is not the user's first session week")
        func endowedCreditIsZeroForANonFirstSessionWeek() throws {
            let (store, _) = try makeStore()
            let w1 = MomentumWeek.weekStart(containing: date(2024, 1, 8), calendar: calendar)
            try store.saveCardioSession(qualifyingCardio(startedAt: w1.addingTimeInterval(3_600)))

            let now = date(2024, 2, 5)
            let summary = try reader(for: store).summary(now: now)

            #expect(summary.endowedCredit == 0)
        }

        // MARK: - Elapsed-week reconciliation

        @Test("a fully elapsed week below target, with no guardrail and no shield, opens a comeback window")
        func missedElapsedWeekOpensComebackWindow() throws {
            let (store, _) = try makeStore()
            let w1 = MomentumWeek.weekStart(containing: date(2024, 1, 8), calendar: calendar)
            try store.saveCardioSession(nonQualifyingCardio(startedAt: w1.addingTimeInterval(3_600)))

            let weekEnd = MomentumWeek.weekEnd(startingAt: w1, calendar: calendar)
            let now = weekEnd.addingTimeInterval(86_400)

            let summary = try reader(for: store).summary(now: now)

            #expect(summary.openComebackWindow != nil)
        }

        @Test("a met elapsed week increments the current streak")
        func metElapsedWeekIncrementsCurrentStreak() throws {
            let (store, _) = try makeStore()
            let w1 = MomentumWeek.weekStart(containing: date(2024, 1, 8), calendar: calendar)
            // W1 is the first-session week (endowed credit 1); two real sessions clear its
            // required count of 2.
            try store.saveCardioSession(qualifyingCardio(startedAt: w1.addingTimeInterval(3_600)))
            try store.saveCardioSession(qualifyingCardio(startedAt: w1.addingTimeInterval(7_200)))

            let now = MomentumWeek.weekEnd(startingAt: w1, calendar: calendar).addingTimeInterval(86_400)
            let summary = try reader(for: store).summary(now: now)

            #expect(summary.currentStreak == 1)
        }

        @Test("four consecutive met weeks accrue a shield")
        func fourConsecutiveMetWeeksAccrueAShield() throws {
            let (store, _) = try makeStore()
            let w1 = MomentumWeek.weekStart(containing: date(2024, 1, 8), calendar: calendar)
            let w2 = MomentumWeek.nextWeekStart(after: w1, calendar: calendar)
            let w3 = MomentumWeek.nextWeekStart(after: w2, calendar: calendar)
            let w4 = MomentumWeek.nextWeekStart(after: w3, calendar: calendar)

            try store.saveCardioSession(qualifyingCardio(startedAt: w1.addingTimeInterval(3_600)))
            try store.saveCardioSession(qualifyingCardio(startedAt: w1.addingTimeInterval(7_200)))
            for weekStart in [w2, w3, w4] {
                for offset in [3_600.0, 7_200.0, 10_800.0] {
                    try store.saveCardioSession(qualifyingCardio(startedAt: weekStart.addingTimeInterval(offset)))
                }
            }

            let now = MomentumWeek.weekEnd(startingAt: w4, calendar: calendar).addingTimeInterval(86_400)
            let summary = try reader(for: store).summary(now: now)

            #expect(summary.currentStreak == 4)
            // Streak-week accrual (4 consecutive weeks) and the week-4 milestone tier both grant
            // a bonus shield on the same fold -- two separate, documented grants, not a double
            // count of the same one (`MomentumReconciliation.reconcile`'s `.met` branch).
            #expect(summary.shieldCount == 2)
        }

        @Test("a milestone awarded at week 4 appears in the summary")
        func milestoneAwardedAtFourWeeksAppearsInSummary() throws {
            let (store, _) = try makeStore()
            let w1 = MomentumWeek.weekStart(containing: date(2024, 1, 8), calendar: calendar)
            let w2 = MomentumWeek.nextWeekStart(after: w1, calendar: calendar)
            let w3 = MomentumWeek.nextWeekStart(after: w2, calendar: calendar)
            let w4 = MomentumWeek.nextWeekStart(after: w3, calendar: calendar)

            try store.saveCardioSession(qualifyingCardio(startedAt: w1.addingTimeInterval(3_600)))
            try store.saveCardioSession(qualifyingCardio(startedAt: w1.addingTimeInterval(7_200)))
            for weekStart in [w2, w3, w4] {
                for offset in [3_600.0, 7_200.0, 10_800.0] {
                    try store.saveCardioSession(qualifyingCardio(startedAt: weekStart.addingTimeInterval(offset)))
                }
            }

            let now = MomentumWeek.weekEnd(startingAt: w4, calendar: calendar).addingTimeInterval(86_400)
            let summary = try reader(for: store).summary(now: now)

            #expect(summary.milestones.contains { $0.weekCount == 4 })
        }

        // MARK: - Idempotence

        @Test("readingTheSummaryTwiceLeavesTheStoredLedgerUnchanged")
        func readingTheSummaryTwiceLeavesTheStoredLedgerUnchanged() throws {
            let (store, context) = try makeStore()
            let w1 = MomentumWeek.weekStart(containing: date(2024, 1, 8), calendar: calendar)
            try store.saveCardioSession(nonQualifyingCardio(startedAt: w1.addingTimeInterval(3_600)))

            let now = MomentumWeek.weekEnd(startingAt: w1, calendar: calendar).addingTimeInterval(86_400)

            _ = try reader(for: store).summary(now: now)
            let ledgerAfterFirst = try store.loadMomentumLedger()
            let comebackCountAfterFirst = try context.fetch(FetchDescriptor<ComebackWindowRecord>()).count
            let milestoneCountAfterFirst = try context.fetch(FetchDescriptor<MilestoneAwardRecord>()).count

            _ = try reader(for: store).summary(now: now)
            let ledgerAfterSecond = try store.loadMomentumLedger()

            #expect(ledgerAfterSecond == ledgerAfterFirst)
            #expect(try context.fetch(FetchDescriptor<ComebackWindowRecord>()).count == comebackCountAfterFirst)
            #expect(try context.fetch(FetchDescriptor<MilestoneAwardRecord>()).count == milestoneCountAfterFirst)
        }

        // MARK: - No sleep member, no cross-domain effect

        @Test("momentumSummaryCarriesNoSleepState")
        func momentumSummaryCarriesNoSleepState() throws {
            let now = Date()

            let (storeWithoutCheckIn, _) = try makeStore()
            let summaryWithoutCheckIn = try reader(for: storeWithoutCheckIn).summary(now: now)

            let (storeWithCheckIn, _) = try makeStore()
            try storeWithCheckIn.saveSleepCheckIn(SleepCheckIn(day: now, quality: .poor, note: "bad night"))
            let summaryWithCheckIn = try reader(for: storeWithCheckIn).summary(now: now)

            #expect(summaryWithCheckIn == summaryWithoutCheckIn)

            let labels = Mirror(reflecting: summaryWithCheckIn).children.compactMap(\.label)
            #expect(labels.allSatisfy { !$0.lowercased().contains("sleep") })
        }

        // MARK: - Session entry label asymmetry

        @Test("aLiftSessionEntryCarriesNoVerificationLabel")
        func aLiftSessionEntryCarriesNoVerificationLabel() throws {
            let (store, _) = try makeStore()
            let now = date(2024, 1, 10)
            let liftSession = LiftSession(startedAt: now, sets: [])
            try store.saveLiftSession(liftSession)
            let cardioSession = qualifyingCardio(startedAt: now.addingTimeInterval(60))
            try store.saveCardioSession(cardioSession)

            let summary = try reader(for: store).summary(now: now)

            let liftEntry = summary.recentSessions.first { $0.id == liftSession.id }
            let cardioEntry = summary.recentSessions.first { $0.id == cardioSession.id }
            #expect(liftEntry?.verificationLabel == nil)
            #expect(cardioEntry?.verificationLabel == MomentumCopy.Verification.manuallyEntered)
        }

        @Test("recentSessions includes only the current week's sessions, sorted most-recent-first")
        func recentSessionsIncludesOnlyCurrentWeekSessionsSortedDescending() throws {
            let (store, _) = try makeStore()
            let now = date(2024, 1, 10)
            let currentWeekStart = MomentumWeek.weekStart(containing: now, calendar: calendar)

            let earlierThisWeek = qualifyingCardio(startedAt: currentWeekStart.addingTimeInterval(3_600))
            let laterThisWeek = qualifyingCardio(startedAt: currentWeekStart.addingTimeInterval(7_200))
            let previousWeekSession = qualifyingCardio(startedAt: currentWeekStart.addingTimeInterval(-3_600))
            try store.saveCardioSession(earlierThisWeek)
            try store.saveCardioSession(laterThisWeek)
            try store.saveCardioSession(previousWeekSession)

            let summary = try reader(for: store).summary(now: now)

            #expect(summary.recentSessions.map(\.id) == [laterThisWeek.id, earlierThisWeek.id])
        }
    }
}
