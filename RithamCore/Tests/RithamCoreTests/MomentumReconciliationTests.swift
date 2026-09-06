import Testing
@testable import RithamCore
import Foundation

@Suite("MomentumReconciliationTests")
struct MomentumReconciliationTests {

    // MARK: - Fixture helpers

    private static func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private static func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 3, _ min: Int = 0) -> Date {
        var components = DateComponents()
        components.year = y
        components.month = m
        components.day = d
        components.hour = h
        components.minute = min
        return utcCalendar().date(from: components)!
    }

    /// A Monday 03:00 UTC week start, matching `MomentumWeek`'s boundary shape.
    private static func weekStart(_ y: Int, _ m: Int, _ d: Int) -> Date {
        date(y, m, d, 3, 0)
    }

    private static func weekInput(
        weekStart: Date,
        cardio: [CardioSession] = [],
        lift: [LiftSession] = [],
        endowedCredit: Int = 0
    ) -> MomentumWeekInput {
        let calendar = utcCalendar()
        let weekEnd = MomentumWeek.weekEnd(startingAt: weekStart, calendar: calendar)
        return MomentumWeekInput(
            weekStart: weekStart,
            weekEnd: weekEnd,
            cardio: cardio,
            lift: lift,
            endowedCredit: endowedCredit
        )
    }

    /// A cardio session whose progress clears `CardioQualification.evaluate` (>= qualifying
    /// duration).
    private static func qualifyingCardioSession(startedAt: Date) -> CardioSession {
        let progress = CardioProgress(continuousDuration: CalibrationThreshold.qualifyingWalkDuration + 60)
        return CardioSession(
            activityType: .walk,
            source: .manualStopwatch,
            startedAt: startedAt,
            endedAt: startedAt.addingTimeInterval(CalibrationThreshold.qualifyingWalkDuration + 60),
            progress: progress
        )
    }

    /// A cardio session whose progress does NOT clear `CardioQualification.evaluate`.
    private static func nonQualifyingCardioSession(startedAt: Date) -> CardioSession {
        let progress = CardioProgress(continuousDuration: 60)
        return CardioSession(
            activityType: .walk,
            source: .manualStopwatch,
            startedAt: startedAt,
            endedAt: startedAt.addingTimeInterval(60),
            progress: progress
        )
    }

    /// A lift session whose sets clear `LiftQualification.evaluate` (enough working sets across
    /// enough distinct exercises).
    private static func qualifyingLiftSession(startedAt: Date) -> LiftSession {
        var sets: [LiftSet] = []
        let exerciseCount = max(CalibrationThreshold.qualifyingExercises, 1)
        let setsPerExercise = max(1, (CalibrationThreshold.qualifyingWorkingSets + exerciseCount - 1) / exerciseCount)
        var orderIndex = 0
        for exerciseIndex in 0..<exerciseCount {
            for _ in 0..<setsPerExercise {
                sets.append(LiftSet(
                    exerciseIdentifier: "exercise-\(exerciseIndex)",
                    weightKg: 20,
                    reps: 8,
                    orderIndex: orderIndex,
                    completedAt: startedAt
                ))
                orderIndex += 1
            }
        }
        return LiftSession(startedAt: startedAt, sets: sets)
    }

    /// A lift session whose sets do NOT clear `LiftQualification.evaluate`.
    private static func nonQualifyingLiftSession(startedAt: Date) -> LiftSession {
        LiftSession(startedAt: startedAt, sets: [
            LiftSet(exerciseIdentifier: "exercise-0", weightKg: 20, reps: 8, orderIndex: 0, completedAt: startedAt),
        ])
    }

    private static func freshLedger(
        weeklyTarget: Int = MomentumTarget.defaultTarget,
        lastReconciledWeekStart: Date? = nil,
        currentStreak: Int = 0,
        shieldCount: Int = 0
    ) -> MomentumLedger {
        var ledger = MomentumLedger.empty
        ledger.weeklyTarget = weeklyTarget
        ledger.lastReconciledWeekStart = lastReconciledWeekStart
        ledger.currentStreak = currentStreak
        ledger.shieldCount = shieldCount
        return ledger
    }

    private static func noGuardrails() -> MomentumGuardrails {
        MomentumGuardrails(recoveryWeeks: [], injuryFreezes: [], streakLossProtected: false)
    }

    // MARK: - qualifyingSessionCount

    @Test("qualifyingSessionCount counts a qualifying cardio session")
    func qualifyingSessionCountCountsQualifyingCardio() {
        let session = Self.qualifyingCardioSession(startedAt: Self.date(2026, 1, 5))
        #expect(MomentumReconciliation.qualifyingSessionCount(cardio: [session], lift: []) == 1)
    }

    @Test("qualifyingSessionCount does not count a non-qualifying cardio session")
    func qualifyingSessionCountExcludesNonQualifyingCardio() {
        let session = Self.nonQualifyingCardioSession(startedAt: Self.date(2026, 1, 5))
        #expect(MomentumReconciliation.qualifyingSessionCount(cardio: [session], lift: []) == 0)
    }

    @Test("qualifyingSessionCount counts a qualifying lift session")
    func qualifyingSessionCountCountsQualifyingLift() {
        let session = Self.qualifyingLiftSession(startedAt: Self.date(2026, 1, 5))
        #expect(MomentumReconciliation.qualifyingSessionCount(cardio: [], lift: [session]) == 1)
    }

    @Test("qualifyingSessionCount does not count a non-qualifying lift session")
    func qualifyingSessionCountExcludesNonQualifyingLift() {
        let session = Self.nonQualifyingLiftSession(startedAt: Self.date(2026, 1, 5))
        #expect(MomentumReconciliation.qualifyingSessionCount(cardio: [], lift: [session]) == 0)
    }

    @Test("a qualifying cardio session and a qualifying lift session in one week produce a count of 2")
    func qualifyingSessionCountWeighsCardioAndLiftEqually() {
        let cardio = Self.qualifyingCardioSession(startedAt: Self.date(2026, 1, 5))
        let lift = Self.qualifyingLiftSession(startedAt: Self.date(2026, 1, 6))
        #expect(MomentumReconciliation.qualifyingSessionCount(cardio: [cardio], lift: [lift]) == 2)
    }

    // MARK: - isStreakLossProtected

    @Test("isStreakLossProtected is true for a tag set containing a never-triggers tag")
    func isStreakLossProtectedTrueForProtectedTag() {
        #expect(MomentumReconciliation.isStreakLossProtected(tags: [.heartDiseaseRecentEventOrSymptomatic]) == true)
    }

    @Test("isStreakLossProtected is false for a tag set of other tags")
    func isStreakLossProtectedFalseForOtherTags() {
        #expect(MomentumReconciliation.isStreakLossProtected(tags: [.hypertensionManaged]) == false)
    }

    @Test("isStreakLossProtected is false for an empty tag set")
    func isStreakLossProtectedFalseForEmptySet() {
        #expect(MomentumReconciliation.isStreakLossProtected(tags: []) == false)
    }

    // MARK: - outcome(for:ledger:guardrails:) precedence

    @Test("a Recovery-Week-flagged week produces paused")
    func recoveryWeekFlagProducesPaused() {
        let start = Self.weekStart(2026, 1, 5)
        let week = Self.weekInput(weekStart: start)
        let ledger = Self.freshLedger()
        let guardrails = MomentumGuardrails(
            recoveryWeeks: [RecoveryWeekPeriod(id: UUID(), weekStart: start, flaggedAt: start)],
            injuryFreezes: [],
            streakLossProtected: false
        )
        #expect(MomentumReconciliation.outcome(for: week, ledger: ledger, guardrails: guardrails) == .paused)
    }

    @Test("a week overlapping an open-ended injury freeze produces frozen")
    func openEndedInjuryFreezeProducesFrozen() {
        let start = Self.weekStart(2026, 1, 5)
        let week = Self.weekInput(weekStart: start)
        let ledger = Self.freshLedger()
        let guardrails = MomentumGuardrails(
            recoveryWeeks: [],
            injuryFreezes: [InjuryFreezePeriod(id: UUID(), startedAt: start, endedAt: nil)],
            streakLossProtected: false
        )
        #expect(MomentumReconciliation.outcome(for: week, ledger: ledger, guardrails: guardrails) == .frozen)
    }

    @Test("a week overlapping a closed injury freeze that intersects it produces frozen")
    func closedInjuryFreezeIntersectingWeekProducesFrozen() {
        let start = Self.weekStart(2026, 1, 5)
        let week = Self.weekInput(weekStart: start)
        let ledger = Self.freshLedger()
        let guardrails = MomentumGuardrails(
            recoveryWeeks: [],
            injuryFreezes: [InjuryFreezePeriod(id: UUID(), startedAt: start, endedAt: start.addingTimeInterval(86_400))],
            streakLossProtected: false
        )
        #expect(MomentumReconciliation.outcome(for: week, ledger: ledger, guardrails: guardrails) == .frozen)
    }

    @Test("a week overlapping a closed injury freeze that does not intersect it does not produce frozen")
    func closedInjuryFreezeNotIntersectingWeekDoesNotProduceFrozen() {
        let start = Self.weekStart(2026, 1, 5)
        let week = Self.weekInput(weekStart: start)
        let ledger = Self.freshLedger()
        let farPast = Self.date(2025, 1, 1)
        let guardrails = MomentumGuardrails(
            recoveryWeeks: [],
            injuryFreezes: [InjuryFreezePeriod(id: UUID(), startedAt: farPast, endedAt: farPast.addingTimeInterval(86_400))],
            streakLossProtected: false
        )
        #expect(MomentumReconciliation.outcome(for: week, ledger: ledger, guardrails: guardrails) != .frozen)
    }

    @Test("a week meeting its required session count produces met")
    func meetingTargetProducesMet() {
        let start = Self.weekStart(2026, 1, 5)
        let cardio = (0..<3).map { Self.qualifyingCardioSession(startedAt: start.addingTimeInterval(Double($0) * 3600)) }
        let week = Self.weekInput(weekStart: start, cardio: cardio)
        let ledger = Self.freshLedger(weeklyTarget: 3)
        #expect(MomentumReconciliation.outcome(for: week, ledger: ledger, guardrails: Self.noGuardrails()) == .met)
    }

    @Test("a week missing its required count with streak-loss protection produces protectedMiss")
    func missingTargetWithProtectionProducesProtectedMiss() {
        let start = Self.weekStart(2026, 1, 5)
        let week = Self.weekInput(weekStart: start)
        let ledger = Self.freshLedger(weeklyTarget: 3)
        let guardrails = MomentumGuardrails(recoveryWeeks: [], injuryFreezes: [], streakLossProtected: true)
        #expect(MomentumReconciliation.outcome(for: week, ledger: ledger, guardrails: guardrails) == .protectedMiss)
    }

    @Test("a week missing its required count with a shield available produces shielded")
    func missingTargetWithShieldProducesShielded() {
        let start = Self.weekStart(2026, 1, 5)
        let week = Self.weekInput(weekStart: start)
        let ledger = Self.freshLedger(weeklyTarget: 3, shieldCount: 1)
        #expect(MomentumReconciliation.outcome(for: week, ledger: ledger, guardrails: Self.noGuardrails()) == .shielded)
    }

    @Test("a week missing its required count with no guardrail and no shield produces missed")
    func missingTargetWithNoShieldProducesMissed() {
        let start = Self.weekStart(2026, 1, 5)
        let week = Self.weekInput(weekStart: start)
        let ledger = Self.freshLedger(weeklyTarget: 3, shieldCount: 0)
        #expect(MomentumReconciliation.outcome(for: week, ledger: ledger, guardrails: Self.noGuardrails()) == .missed)
    }

    @Test("recoveryWeekFlagIsHonouredBeforeAnyShieldIsConsidered")
    func recoveryWeekFlagIsHonouredBeforeAnyShieldIsConsidered() {
        let start = Self.weekStart(2026, 1, 5)
        // Week is short of target (zero qualifying sessions against a target of 3).
        let week = Self.weekInput(weekStart: start)
        var ledger = Self.freshLedger(weeklyTarget: 3, shieldCount: 2)
        let guardrails = MomentumGuardrails(
            recoveryWeeks: [RecoveryWeekPeriod(id: UUID(), weekStart: start, flaggedAt: start)],
            injuryFreezes: [],
            streakLossProtected: false
        )

        let resultOutcome = MomentumReconciliation.outcome(for: week, ledger: ledger, guardrails: guardrails)
        #expect(resultOutcome == .paused)

        let resultLedger = MomentumReconciliation.reconcile(
            ledger: ledger,
            elapsedWeeks: [week],
            currentWeek: Self.weekInput(weekStart: MomentumWeek.nextWeekStart(after: start, calendar: Self.utcCalendar())),
            guardrails: guardrails,
            now: start.addingTimeInterval(8 * 86_400),
            calendar: Self.utcCalendar()
        )
        #expect(resultLedger.shieldCount == 2)
        ledger.shieldCount = 2
    }

    // MARK: - reconcile: ordering, anchor skip, met increments streak

    @Test("weeks are folded in ascending week-start order and streak increments once per met week")
    func weeksAreFoldedInAscendingOrder() {
        let calendar = Self.utcCalendar()
        let week1Start = Self.weekStart(2026, 1, 5)
        let week2Start = Self.weekStart(2026, 1, 12)
        let cardio1 = (0..<3).map { Self.qualifyingCardioSession(startedAt: week1Start.addingTimeInterval(Double($0) * 3600)) }
        let cardio2 = (0..<3).map { Self.qualifyingCardioSession(startedAt: week2Start.addingTimeInterval(Double($0) * 3600)) }
        let week1 = Self.weekInput(weekStart: week1Start, cardio: cardio1)
        let week2 = Self.weekInput(weekStart: week2Start, cardio: cardio2)
        let ledger = Self.freshLedger(weeklyTarget: 3)

        let result = MomentumReconciliation.reconcile(
            ledger: ledger,
            // Passed out of order deliberately.
            elapsedWeeks: [week2, week1],
            currentWeek: Self.weekInput(weekStart: MomentumWeek.nextWeekStart(after: week2Start, calendar: calendar)),
            guardrails: Self.noGuardrails(),
            now: week2Start.addingTimeInterval(8 * 86_400),
            calendar: calendar
        )

        #expect(result.currentStreak == 2)
        #expect(result.lastReconciledWeekStart == week2Start)
    }

    @Test("any week at or before the ledger's last-reconciled anchor is skipped entirely")
    func weeksAtOrBeforeAnchorAreSkipped() {
        let calendar = Self.utcCalendar()
        let week1Start = Self.weekStart(2026, 1, 5)
        let week2Start = Self.weekStart(2026, 1, 12)
        let cardio1 = (0..<3).map { Self.qualifyingCardioSession(startedAt: week1Start.addingTimeInterval(Double($0) * 3600)) }
        let week1 = Self.weekInput(weekStart: week1Start, cardio: cardio1)
        // Ledger already reconciled through week1.
        let ledger = Self.freshLedger(weeklyTarget: 3, lastReconciledWeekStart: week1Start, currentStreak: 1)

        let result = MomentumReconciliation.reconcile(
            ledger: ledger,
            elapsedWeeks: [week1],
            currentWeek: Self.weekInput(weekStart: MomentumWeek.nextWeekStart(after: week1Start, calendar: calendar)),
            guardrails: Self.noGuardrails(),
            now: week2Start.addingTimeInterval(86_400),
            calendar: calendar
        )

        // week1 must not be reprocessed, so streak stays at 1, not 2.
        #expect(result.currentStreak == 1)
        #expect(result.lastReconciledWeekStart == week1Start)
    }

    @Test("after folding, the last-reconciled anchor equals the last elapsed week processed and never advances past the in-progress week")
    func anchorAdvancesToLastElapsedWeekOnly() {
        let calendar = Self.utcCalendar()
        let week1Start = Self.weekStart(2026, 1, 5)
        let currentWeekStart = MomentumWeek.nextWeekStart(after: week1Start, calendar: calendar)
        let cardio1 = (0..<3).map { Self.qualifyingCardioSession(startedAt: week1Start.addingTimeInterval(Double($0) * 3600)) }
        let week1 = Self.weekInput(weekStart: week1Start, cardio: cardio1)
        let ledger = Self.freshLedger(weeklyTarget: 3)

        let result = MomentumReconciliation.reconcile(
            ledger: ledger,
            elapsedWeeks: [week1],
            currentWeek: Self.weekInput(weekStart: currentWeekStart),
            guardrails: Self.noGuardrails(),
            now: currentWeekStart.addingTimeInterval(3600),
            calendar: calendar
        )

        #expect(result.lastReconciledWeekStart == week1Start)
        #expect(result.lastReconciledWeekStart != currentWeekStart)
    }

    @Test("a paused week leaves streak, shield count, and shield-accrual counter unchanged and opens no comeback window")
    func pausedWeekIsANoOp() {
        let calendar = Self.utcCalendar()
        let start = Self.weekStart(2026, 1, 5)
        let week = Self.weekInput(weekStart: start)
        var ledger = Self.freshLedger(weeklyTarget: 3, currentStreak: 2, shieldCount: 1)
        ledger.weeksTowardNextShield = 2
        let guardrails = MomentumGuardrails(
            recoveryWeeks: [RecoveryWeekPeriod(id: UUID(), weekStart: start, flaggedAt: start)],
            injuryFreezes: [],
            streakLossProtected: false
        )

        let result = MomentumReconciliation.reconcile(
            ledger: ledger,
            elapsedWeeks: [week],
            currentWeek: Self.weekInput(weekStart: MomentumWeek.nextWeekStart(after: start, calendar: calendar)),
            guardrails: guardrails,
            now: start.addingTimeInterval(8 * 86_400),
            calendar: calendar
        )

        #expect(result.currentStreak == 2)
        #expect(result.shieldCount == 1)
        #expect(result.weeksTowardNextShield == 2)
        #expect(result.comebackWindows.isEmpty)
    }

    @Test("a frozen week leaves streak, shield count, and shield-accrual counter unchanged and opens no comeback window")
    func frozenWeekIsANoOp() {
        let calendar = Self.utcCalendar()
        let start = Self.weekStart(2026, 1, 5)
        let week = Self.weekInput(weekStart: start)
        var ledger = Self.freshLedger(weeklyTarget: 3, currentStreak: 2, shieldCount: 1)
        ledger.weeksTowardNextShield = 2
        let guardrails = MomentumGuardrails(
            recoveryWeeks: [],
            injuryFreezes: [InjuryFreezePeriod(id: UUID(), startedAt: start, endedAt: nil)],
            streakLossProtected: false
        )

        let result = MomentumReconciliation.reconcile(
            ledger: ledger,
            elapsedWeeks: [week],
            currentWeek: Self.weekInput(weekStart: MomentumWeek.nextWeekStart(after: start, calendar: calendar)),
            guardrails: guardrails,
            now: start.addingTimeInterval(8 * 86_400),
            calendar: calendar
        )

        #expect(result.currentStreak == 2)
        #expect(result.shieldCount == 1)
        #expect(result.weeksTowardNextShield == 2)
        #expect(result.comebackWindows.isEmpty)
    }

    @Test("a protectedMiss week leaves streak unchanged, consumes no shield, and opens no comeback window")
    func protectedMissWeekIsANoOp() {
        let calendar = Self.utcCalendar()
        let start = Self.weekStart(2026, 1, 5)
        let week = Self.weekInput(weekStart: start)
        let ledger = Self.freshLedger(weeklyTarget: 3, currentStreak: 2, shieldCount: 1)
        let guardrails = MomentumGuardrails(recoveryWeeks: [], injuryFreezes: [], streakLossProtected: true)

        let result = MomentumReconciliation.reconcile(
            ledger: ledger,
            elapsedWeeks: [week],
            currentWeek: Self.weekInput(weekStart: MomentumWeek.nextWeekStart(after: start, calendar: calendar)),
            guardrails: guardrails,
            now: start.addingTimeInterval(8 * 86_400),
            calendar: calendar
        )

        #expect(result.currentStreak == 2)
        #expect(result.shieldCount == 1)
        #expect(result.weeksTowardNextShield == 2)
        #expect(result.comebackWindows.isEmpty)
    }

    // MARK: - Task 2: shield accrual/consumption, milestones, idempotence

    /// `count` consecutive met weeks (each meeting `target` via qualifying cardio sessions),
    /// starting at `startWeek`.
    private static func consecutiveMetWeeks(count: Int, startingAt startWeek: Date, target: Int = 3) -> [MomentumWeekInput] {
        let calendar = Self.utcCalendar()
        var weeks: [MomentumWeekInput] = []
        var weekStart = startWeek
        for _ in 0..<count {
            let cardio = (0..<target).map { Self.qualifyingCardioSession(startedAt: weekStart.addingTimeInterval(Double($0) * 3600)) }
            weeks.append(Self.weekInput(weekStart: weekStart, cardio: cardio))
            weekStart = MomentumWeek.nextWeekStart(after: weekStart, calendar: calendar)
        }
        return weeks
    }

    @Test("four consecutive met weeks grant exactly one shield and reset the accrual counter to zero")
    func fourConsecutiveMetWeeksGrantOneShield() {
        let calendar = Self.utcCalendar()
        let start = Self.weekStart(2026, 1, 5)
        let weeks = Self.consecutiveMetWeeks(count: 4, startingAt: start)
        var ledger = Self.freshLedger(weeklyTarget: 3, currentStreak: 10)
        ledger.weeksTowardNextShield = 0
        ledger.shieldCount = 0
        let lastWeekStart = weeks.last!.weekStart

        let result = MomentumReconciliation.reconcile(
            ledger: ledger,
            elapsedWeeks: weeks,
            currentWeek: Self.weekInput(weekStart: MomentumWeek.nextWeekStart(after: lastWeekStart, calendar: calendar)),
            guardrails: Self.noGuardrails(),
            now: lastWeekStart.addingTimeInterval(8 * 86_400),
            calendar: calendar
        )

        #expect(result.currentStreak == 14)
        #expect(result.shieldCount == 1)
        #expect(result.weeksTowardNextShield == 0)
    }

    @Test("three consecutive met weeks grant no shield and leave the accrual counter at three")
    func threeConsecutiveMetWeeksGrantNoShield() {
        let calendar = Self.utcCalendar()
        let start = Self.weekStart(2026, 1, 5)
        let weeks = Self.consecutiveMetWeeks(count: 3, startingAt: start)
        var ledger = Self.freshLedger(weeklyTarget: 3, currentStreak: 10)
        ledger.weeksTowardNextShield = 0
        ledger.shieldCount = 0
        let lastWeekStart = weeks.last!.weekStart

        let result = MomentumReconciliation.reconcile(
            ledger: ledger,
            elapsedWeeks: weeks,
            currentWeek: Self.weekInput(weekStart: MomentumWeek.nextWeekStart(after: lastWeekStart, calendar: calendar)),
            guardrails: Self.noGuardrails(),
            now: lastWeekStart.addingTimeInterval(8 * 86_400),
            calendar: calendar
        )

        #expect(result.currentStreak == 13)
        #expect(result.shieldCount == 0)
        #expect(result.weeksTowardNextShield == 3)
    }

    @Test("shieldCountNeverExceedsThreeAcrossTwelveConsecutiveMetWeeks")
    func shieldCountNeverExceedsThreeAcrossTwelveConsecutiveMetWeeks() {
        let calendar = Self.utcCalendar()
        let start = Self.weekStart(2026, 1, 5)
        let weeks = Self.consecutiveMetWeeks(count: 12, startingAt: start)
        let ledger = Self.freshLedger(weeklyTarget: 3)
        let lastWeekStart = weeks.last!.weekStart

        let result = MomentumReconciliation.reconcile(
            ledger: ledger,
            elapsedWeeks: weeks,
            currentWeek: Self.weekInput(weekStart: MomentumWeek.nextWeekStart(after: lastWeekStart, calendar: calendar)),
            guardrails: Self.noGuardrails(),
            now: lastWeekStart.addingTimeInterval(8 * 86_400),
            calendar: calendar
        )

        #expect(result.currentStreak == 12)
        #expect(result.shieldCount == MomentumLedger.maxShields)
        #expect(result.weeksTowardNextShield == 0)
    }

    @Test("a shielded week decrements the shield count by exactly one, leaves the streak unchanged, and resets the accrual counter to zero")
    func shieldedWeekDecrementsShieldAndResetsAccrual() {
        let calendar = Self.utcCalendar()
        let start = Self.weekStart(2026, 1, 5)
        let week = Self.weekInput(weekStart: start)
        var ledger = Self.freshLedger(weeklyTarget: 3, currentStreak: 5, shieldCount: 2)
        ledger.weeksTowardNextShield = 2

        let result = MomentumReconciliation.reconcile(
            ledger: ledger,
            elapsedWeeks: [week],
            currentWeek: Self.weekInput(weekStart: MomentumWeek.nextWeekStart(after: start, calendar: calendar)),
            guardrails: Self.noGuardrails(),
            now: start.addingTimeInterval(8 * 86_400),
            calendar: calendar
        )

        #expect(result.currentStreak == 5)
        #expect(result.shieldCount == 1)
        #expect(result.weeksTowardNextShield == 0)
    }

    @Test("a protectedMiss week neither increments nor resets the accrual counter")
    func protectedMissWeekLeavesAccrualCounterUnchanged() {
        let calendar = Self.utcCalendar()
        let start = Self.weekStart(2026, 1, 5)
        let week = Self.weekInput(weekStart: start)
        var ledger = Self.freshLedger(weeklyTarget: 3, currentStreak: 2, shieldCount: 1)
        ledger.weeksTowardNextShield = 2
        let guardrails = MomentumGuardrails(recoveryWeeks: [], injuryFreezes: [], streakLossProtected: true)

        let result = MomentumReconciliation.reconcile(
            ledger: ledger,
            elapsedWeeks: [week],
            currentWeek: Self.weekInput(weekStart: MomentumWeek.nextWeekStart(after: start, calendar: calendar)),
            guardrails: guardrails,
            now: start.addingTimeInterval(8 * 86_400),
            calendar: calendar
        )

        #expect(result.weeksTowardNextShield == 2)
    }

    @Test("a streak reaching a milestone tier awards exactly one milestone plus one bonus shield")
    func streakReachingATierAwardsMilestoneAndBonusShield() {
        let calendar = Self.utcCalendar()
        for tier in MomentumMilestone.tiers {
            let start = Self.weekStart(2026, 1, 5)
            let week = Self.weekInput(weekStart: start, cardio: (0..<3).map {
                Self.qualifyingCardioSession(startedAt: start.addingTimeInterval(Double($0) * 3600))
            })
            let ledger = Self.freshLedger(weeklyTarget: 3, currentStreak: tier - 1, shieldCount: 0)

            let result = MomentumReconciliation.reconcile(
                ledger: ledger,
                elapsedWeeks: [week],
                currentWeek: Self.weekInput(weekStart: MomentumWeek.nextWeekStart(after: start, calendar: calendar)),
                guardrails: Self.noGuardrails(),
                now: start.addingTimeInterval(8 * 86_400),
                calendar: calendar
            )

            #expect(result.currentStreak == tier)
            #expect(result.milestones.count == 1)
            #expect(result.milestones.first?.weekCount == tier)
            #expect(result.shieldCount == 1)
        }
    }

    @Test("a milestone bonus shield still respects the cap of three")
    func milestoneBonusShieldRespectsCap() {
        let calendar = Self.utcCalendar()
        let start = Self.weekStart(2026, 1, 5)
        let week = Self.weekInput(weekStart: start, cardio: (0..<3).map {
            Self.qualifyingCardioSession(startedAt: start.addingTimeInterval(Double($0) * 3600))
        })
        let ledger = Self.freshLedger(weeklyTarget: 3, currentStreak: 3, shieldCount: MomentumLedger.maxShields)

        let result = MomentumReconciliation.reconcile(
            ledger: ledger,
            elapsedWeeks: [week],
            currentWeek: Self.weekInput(weekStart: MomentumWeek.nextWeekStart(after: start, calendar: calendar)),
            guardrails: Self.noGuardrails(),
            now: start.addingTimeInterval(8 * 86_400),
            calendar: calendar
        )

        #expect(result.currentStreak == 4)
        #expect(result.milestones.count == 1)
        #expect(result.shieldCount == MomentumLedger.maxShields)
    }

    @Test("aMilestoneAlreadyAwardedIsNeverAwardedASecondTime")
    func aMilestoneAlreadyAwardedIsNeverAwardedASecondTime() {
        let calendar = Self.utcCalendar()
        let start = Self.weekStart(2026, 1, 5)
        let week = Self.weekInput(weekStart: start, cardio: (0..<3).map {
            Self.qualifyingCardioSession(startedAt: start.addingTimeInterval(Double($0) * 3600))
        })
        var ledger = Self.freshLedger(weeklyTarget: 3, currentStreak: 3, shieldCount: 0)
        ledger.milestones = [MilestoneAward(id: UUID(), weekCount: 4, awardedAt: Self.date(2025, 1, 1))]

        let result = MomentumReconciliation.reconcile(
            ledger: ledger,
            elapsedWeeks: [week],
            currentWeek: Self.weekInput(weekStart: MomentumWeek.nextWeekStart(after: start, calendar: calendar)),
            guardrails: Self.noGuardrails(),
            now: start.addingTimeInterval(8 * 86_400),
            calendar: calendar
        )

        #expect(result.currentStreak == 4)
        #expect(result.milestones.count == 1)
        #expect(result.shieldCount == 0)
    }

    @Test("reconcilingTwiceWithIdenticalInputsProducesAnEqualLedger")
    func reconcilingTwiceWithIdenticalInputsProducesAnEqualLedger() {
        let calendar = Self.utcCalendar()
        let start = Self.weekStart(2026, 1, 5)
        let weeks = Self.consecutiveMetWeeks(count: 5, startingAt: start)
        let lastWeekStart = weeks.last!.weekStart
        let currentWeek = Self.weekInput(weekStart: MomentumWeek.nextWeekStart(after: lastWeekStart, calendar: calendar))
        let now = lastWeekStart.addingTimeInterval(8 * 86_400)
        let ledger = Self.freshLedger(weeklyTarget: 3)

        let result1 = MomentumReconciliation.reconcile(
            ledger: ledger,
            elapsedWeeks: weeks,
            currentWeek: currentWeek,
            guardrails: Self.noGuardrails(),
            now: now,
            calendar: calendar
        )

        let result2 = MomentumReconciliation.reconcile(
            ledger: result1,
            elapsedWeeks: weeks,
            currentWeek: currentWeek,
            guardrails: Self.noGuardrails(),
            now: now,
            calendar: calendar
        )

        #expect(result1 == result2)
    }

    @Test("reconciling a second time with an elapsed-week list already at or before the anchor processes none of them again")
    func reconcilingAgainOverAlreadyProcessedWeeksIsANoOp() {
        let calendar = Self.utcCalendar()
        let start = Self.weekStart(2026, 1, 5)
        let weeks = Self.consecutiveMetWeeks(count: 4, startingAt: start)
        let lastWeekStart = weeks.last!.weekStart
        let currentWeek = Self.weekInput(weekStart: MomentumWeek.nextWeekStart(after: lastWeekStart, calendar: calendar))
        let now = lastWeekStart.addingTimeInterval(8 * 86_400)
        let ledger = Self.freshLedger(weeklyTarget: 3)

        let result1 = MomentumReconciliation.reconcile(
            ledger: ledger,
            elapsedWeeks: weeks,
            currentWeek: currentWeek,
            guardrails: Self.noGuardrails(),
            now: now,
            calendar: calendar
        )

        // Passing the *same* (already-processed) weeks again must be a no-op.
        let result2 = MomentumReconciliation.reconcile(
            ledger: result1,
            elapsedWeeks: weeks,
            currentWeek: currentWeek,
            guardrails: Self.noGuardrails(),
            now: now,
            calendar: calendar
        )

        #expect(result2.shieldCount == result1.shieldCount)
        #expect(result2.currentStreak == result1.currentStreak)
        #expect(result2.milestones.count == result1.milestones.count)
    }
}
