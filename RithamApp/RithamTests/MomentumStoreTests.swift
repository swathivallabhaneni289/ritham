import Foundation
import SwiftData
import Testing
import RithamCore
@testable import Ritham

extension MomentumContainerTouchingSuites {
    @MainActor
    @Suite("MomentumStoreTests", .serialized)
    struct MomentumStoreTests {

        private let calendar = Calendar(identifier: .gregorian)

        /// Builds an in-memory container over the full `RithamModelContainer` model list -- the
        /// production schema, not a hand-picked subset -- so a model missing from that list would
        /// fail here at first fetch, exactly as it would in the running app.
        private func makeStore() throws -> (store: HealthDataStore, context: ModelContext) {
            let container = try RithamModelContainer.make(inMemory: true)
            let context = ModelContext(container)
            return (HealthDataStore(context: context, calendar: calendar), context)
        }

        // MARK: - Weekly target

        @Test(
            "saving each supported target and reloading returns the same value",
            arguments: [2, 3, 4, 5]
        )
        func savingSupportedTargetRoundTrips(_ target: Int) throws {
            let (store, _) = try makeStore()
            try store.saveMomentumTarget(target)
            #expect(try store.loadMomentumTarget() == target)
        }

        @Test(
            "saving an unsupported target throws and leaves the previously stored value unchanged",
            arguments: [0, 1, 6, 10, -1]
        )
        func savingUnsupportedTargetThrowsAndLeavesStoredValueUnchanged(_ target: Int) throws {
            let (store, _) = try makeStore()
            try store.saveMomentumTarget(4)

            #expect(throws: HealthDataStoreError.unsupportedMomentumTarget) {
                try store.saveMomentumTarget(target)
            }
            #expect(try store.loadMomentumTarget() == 4)
        }

        @Test("loadMomentumTarget on an empty store returns the default")
        func loadMomentumTargetDefaultsWhenEmpty() throws {
            let (store, _) = try makeStore()
            #expect(try store.loadMomentumTarget() == MomentumTarget.defaultTarget)
        }

        @Test("supportedMomentumTargets is sourced from and equal to MomentumTarget.supported")
        func supportedMomentumTargetsMatchesDomainConstant() {
            #expect(HealthDataStore.supportedMomentumTargets == MomentumTarget.supported)
        }

        // MARK: - Ledger round-trip

        @Test("a ledger with streak, shields, accrual, milestones, and a comeback window round-trips")
        func ledgerRoundTrips() throws {
            let (store, _) = try makeStore()
            let now = Date()
            let ledger = MomentumLedger(
                currentStreak: 6,
                streakLabelKind: .fresh,
                shieldCount: 2,
                weeksTowardNextShield: 1,
                lastReconciledWeekStart: now,
                weeklyTarget: 4,
                visibility: .privateToDevice,
                milestones: [
                    MilestoneAward(id: UUID(), weekCount: 4, awardedAt: now),
                    MilestoneAward(id: UUID(), weekCount: 12, awardedAt: now.addingTimeInterval(3_600)),
                ],
                comebackWindows: [
                    ComebackWindow(
                        id: UUID(),
                        missedWeekStart: now,
                        opensAt: now,
                        closesAt: now.addingTimeInterval(3 * 86_400),
                        claimedAt: nil,
                        claimingSessionID: nil,
                        streakBeforeMiss: 5
                    ),
                ]
            )

            try store.saveMomentumLedger(ledger)
            let loaded = try store.loadMomentumLedger()

            #expect(loaded == ledger)
        }

        @Test("saving the same ledger twice does not duplicate milestone or comeback rows")
        func savingSameLedgerTwiceDoesNotDuplicateRows() throws {
            let (store, context) = try makeStore()
            let now = Date()
            let ledger = MomentumLedger(
                currentStreak: 4,
                streakLabelKind: .fresh,
                shieldCount: 1,
                weeksTowardNextShield: 0,
                lastReconciledWeekStart: now,
                weeklyTarget: 3,
                visibility: .privateToDevice,
                milestones: [MilestoneAward(id: UUID(), weekCount: 4, awardedAt: now)],
                comebackWindows: [
                    ComebackWindow(
                        id: UUID(),
                        missedWeekStart: now,
                        opensAt: now,
                        closesAt: now.addingTimeInterval(3 * 86_400),
                        claimedAt: nil,
                        claimingSessionID: nil,
                        streakBeforeMiss: 3
                    ),
                ]
            )

            try store.saveMomentumLedger(ledger)
            try store.saveMomentumLedger(ledger)

            #expect(try context.fetch(FetchDescriptor<MilestoneAwardRecord>()).count == 1)
            #expect(try context.fetch(FetchDescriptor<ComebackWindowRecord>()).count == 1)
        }

        @Test("a stored milestone award survives a subsequent save whose ledger omits it")
        func storedMilestoneSurvivesOmission() throws {
            let (store, context) = try makeStore()
            let now = Date()
            let award = MilestoneAward(id: UUID(), weekCount: 4, awardedAt: now)

            var ledger = MomentumLedger.empty
            ledger.milestones = [award]
            try store.saveMomentumLedger(ledger)

            ledger.milestones = []
            try store.saveMomentumLedger(ledger)

            let stored = try context.fetch(FetchDescriptor<MilestoneAwardRecord>())
            #expect(stored.count == 1)
            #expect(stored.first?.id == award.id)
        }

        @Test("saving a ledger whose comeback window has become claimed updates the stored row in place")
        func claimingComebackWindowUpdatesInPlace() throws {
            let (store, context) = try makeStore()
            let now = Date()
            let windowID = UUID()
            var window = ComebackWindow(
                id: windowID,
                missedWeekStart: now,
                opensAt: now,
                closesAt: now.addingTimeInterval(3 * 86_400),
                claimedAt: nil,
                claimingSessionID: nil,
                streakBeforeMiss: 5
            )

            var ledger = MomentumLedger.empty
            ledger.comebackWindows = [window]
            try store.saveMomentumLedger(ledger)

            let claimingSessionID = UUID()
            let claimedAt = now.addingTimeInterval(3_600)
            window.claimedAt = claimedAt
            window.claimingSessionID = claimingSessionID
            ledger.comebackWindows = [window]
            try store.saveMomentumLedger(ledger)

            let stored = try context.fetch(FetchDescriptor<ComebackWindowRecord>())
            #expect(stored.count == 1)
            #expect(stored.first?.id == windowID)
            #expect(stored.first?.claimedAt == claimedAt)
            #expect(stored.first?.claimingSessionID == claimingSessionID)
        }

        @Test("MomentumVisibility persists and reloads as private-to-device")
        func visibilityPersistsAsPrivateToDevice() throws {
            let (store, _) = try makeStore()
            var ledger = MomentumLedger.empty
            ledger.visibility = .privateToDevice
            try store.saveMomentumLedger(ledger)

            let loaded = try store.loadMomentumLedger()
            #expect(loaded.visibility == .privateToDevice)
        }

        // MARK: - earliestSessionStart

        @Test("earliestSessionStart returns nil on an empty store")
        func earliestSessionStartNilWhenEmpty() throws {
            let (store, _) = try makeStore()
            #expect(try store.earliestSessionStart() == nil)
        }

        @Test("earliestSessionStart returns the earliest of a stored cardio and lift session")
        func earliestSessionStartReturnsEarliestAcrossModalities() throws {
            let (store, _) = try makeStore()
            let earlierDate = Date(timeIntervalSince1970: 1_000)
            let laterDate = Date(timeIntervalSince1970: 2_000)

            let cardioSession = CardioSession(
                activityType: .run,
                source: .gps,
                startedAt: laterDate,
                endedAt: laterDate.addingTimeInterval(1_800),
                progress: CardioProgress(continuousDuration: 1_800, distanceMeters: 5_000)
            )
            try store.saveCardioSession(cardioSession)

            let liftSession = LiftSession(startedAt: earlierDate, sets: [])
            try store.saveLiftSession(liftSession)

            #expect(try store.earliestSessionStart() == earlierDate)
        }

        // MARK: - Recovery Week and injury freeze periods

        @Test("appending a Recovery Week period and reloading it returns the same period")
        func recoveryWeekPeriodRoundTrips() throws {
            let (store, _) = try makeStore()
            let now = Date()
            let period = RecoveryWeekPeriod(id: UUID(), weekStart: now, flaggedAt: now)

            try store.appendRecoveryWeekPeriod(period)

            #expect(try store.loadRecoveryWeekPeriods() == [period])
        }

        @Test("appending the same Recovery Week twice stores exactly one row")
        func appendingSameRecoveryWeekTwiceStoresExactlyOneRow() throws {
            let (store, _) = try makeStore()
            let now = Date()

            try store.appendRecoveryWeekPeriod(RecoveryWeekPeriod(id: UUID(), weekStart: now, flaggedAt: now))
            try store.appendRecoveryWeekPeriod(
                RecoveryWeekPeriod(id: UUID(), weekStart: now, flaggedAt: now.addingTimeInterval(60))
            )

            #expect(try store.loadRecoveryWeekPeriods().count == 1)
        }

        @Test("appending an injury freeze while one is already open stores exactly one row")
        func appendingSecondInjuryFreezeWhileOpenStoresExactlyOneRow() throws {
            let (store, _) = try makeStore()
            let now = Date()

            try store.appendInjuryFreezePeriod(InjuryFreezePeriod(id: UUID(), startedAt: now, endedAt: nil))
            try store.appendInjuryFreezePeriod(
                InjuryFreezePeriod(id: UUID(), startedAt: now.addingTimeInterval(3_600), endedAt: nil)
            )

            #expect(try store.loadInjuryFreezePeriods().count == 1)
        }

        @Test("closing an open freeze sets its end and leaves the row present")
        func closingOpenFreezeSetsEndAndLeavesRowPresent() throws {
            let (store, _) = try makeStore()
            let now = Date()
            try store.appendInjuryFreezePeriod(InjuryFreezePeriod(id: UUID(), startedAt: now, endedAt: nil))

            let closeDate = now.addingTimeInterval(86_400)
            try store.closeOpenInjuryFreeze(at: closeDate)

            let loaded = try store.loadInjuryFreezePeriods()
            #expect(loaded.count == 1)
            #expect(loaded.first?.endedAt == closeDate)
        }

        @Test("closing when nothing is open is a no-op that throws nothing")
        func closingWhenNothingOpenIsANoOp() throws {
            let (store, _) = try makeStore()
            try store.closeOpenInjuryFreeze(at: Date())
            #expect(try store.loadInjuryFreezePeriods().isEmpty)
        }

        @Test("recoveryWeekAndInjuryFreezeShareNoStoredState")
        func recoveryWeekAndInjuryFreezeShareNoStoredState() throws {
            let (store, _) = try makeStore()
            let now = Date()

            try store.appendInjuryFreezePeriod(InjuryFreezePeriod(id: UUID(), startedAt: now, endedAt: nil))
            let injuryCountAfterFirstAppend = try store.loadInjuryFreezePeriods().count

            try store.appendRecoveryWeekPeriod(RecoveryWeekPeriod(id: UUID(), weekStart: now, flaggedAt: now))
            #expect(try store.loadInjuryFreezePeriods().count == injuryCountAfterFirstAppend)

            let recoveryCountAfterFirstAppend = try store.loadRecoveryWeekPeriods().count
            try store.appendInjuryFreezePeriod(
                InjuryFreezePeriod(id: UUID(), startedAt: now.addingTimeInterval(30 * 86_400), endedAt: nil)
            )
            #expect(try store.loadRecoveryWeekPeriods().count == recoveryCountAfterFirstAppend)
        }

        /// A guardrail case a manually maintained inventory entry can describe: which of the two
        /// D-03-independent guardrail record types (if any) a `HealthDataStore` method reads from
        /// storage, and which it writes to storage.
        private enum GuardrailAccess: Equatable {
            case recoveryWeek
            case injuryFreeze
            case none
        }

        private struct MethodGuardrailAccess {
            let name: String
            let reads: GuardrailAccess
            let writes: GuardrailAccess
        }

        /// A manually maintained, reviewer-facing inventory of every `HealthDataStore` method in
        /// the Recovery Week / injury freeze section, paired with which guardrail type (if any)
        /// it reads from storage and which it writes to storage. This stands in for a reflection
        /// trick 03-04-PLAN.md explicitly allows skipping: Swift Testing has no supported runtime
        /// API to enumerate a class's methods and inspect what each one reads/writes. A reviewer
        /// adding a new Momentum guardrail method is expected to add a matching row here; this
        /// test then re-checks the whole table's invariant, so a future method that both reads
        /// one guardrail type and writes the other fails this test the moment its row is added.
        private static let momentumGuardrailMethodInventory: [MethodGuardrailAccess] = [
            MethodGuardrailAccess(name: "loadRecoveryWeekPeriods", reads: .recoveryWeek, writes: .none),
            MethodGuardrailAccess(name: "appendRecoveryWeekPeriod", reads: .recoveryWeek, writes: .recoveryWeek),
            MethodGuardrailAccess(name: "loadInjuryFreezePeriods", reads: .injuryFreeze, writes: .none),
            MethodGuardrailAccess(name: "appendInjuryFreezePeriod", reads: .injuryFreeze, writes: .injuryFreeze),
            MethodGuardrailAccess(name: "closeOpenInjuryFreeze", reads: .injuryFreeze, writes: .injuryFreeze),
        ]

        @Test("momentumStoreExposesNoCrossMachineTransition")
        func momentumStoreExposesNoCrossMachineTransition() {
            for entry in Self.momentumGuardrailMethodInventory {
                let crossesMachines = entry.reads != .none
                    && entry.writes != .none
                    && entry.reads != entry.writes
                #expect(
                    !crossesMachines,
                    "\(entry.name) reads \(entry.reads) but writes \(entry.writes) -- a guardrail method must never read one machine and write the other (D-03)"
                )
            }
        }
    }
}
