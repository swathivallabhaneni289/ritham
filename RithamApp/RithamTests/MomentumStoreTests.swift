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
    }
}
