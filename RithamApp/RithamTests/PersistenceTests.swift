import Foundation
import SwiftData
import Testing
import RithamCore
@testable import Ritham

@Suite("PersistenceTests")
struct PersistenceTests {

    /// A fresh in-memory container/context per test — no shared state, so tests can run
    /// concurrently (Swift Testing's default) without ordering dependencies.
    private func makeContext() throws -> ModelContext {
        let schema = Schema([UserProfile.self, ConditionTagRecord.self, CalibrationBaselineRecord.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return ModelContext(container)
    }

    private let calendar = Calendar(identifier: .gregorian)

    // MARK: - Round-trip

    @Test("UserProfile round-trips through save and fetch")
    func userProfileRoundTrips() throws {
        let context = try makeContext()
        let now = Date()
        let profile = UserProfile(
            age: 30,
            explanationRegisterRaw: ExplanationRegister.technical.rawValue,
            dietaryPatternRaw: DietaryPattern.vegan.rawValue,
            edScreenOutcomeRaw: ConditionTag.eatingDisorderSelfReportedNegativeScreen.rawValue,
            createdAt: now,
            updatedAt: now
        )
        context.insert(profile)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<UserProfile>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.age == 30)
        #expect(fetched.first?.explanationRegister == .technical)
        #expect(fetched.first?.dietaryPattern == .vegan)
        #expect(fetched.first?.edScreenOutcome == .eatingDisorderSelfReportedNegativeScreen)
    }

    @Test("ConditionTagRecord round-trips through save and fetch")
    func conditionTagRecordRoundTrips() throws {
        let context = try makeContext()
        let now = Date()
        let record = ConditionTagRecord(tagRaw: ConditionTag.osteoarthritis.rawValue, recordedAt: now)
        context.insert(record)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<ConditionTagRecord>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.tag == .osteoarthritis)
        #expect(fetched.first?.recordedAt == now)
    }

    @Test("CalibrationBaselineRecord round-trips through save and fetch")
    func calibrationBaselineRecordRoundTrips() throws {
        let context = try makeContext()
        let now = Date()
        let record = CalibrationBaselineRecord(
            slowestSecondsPerKm: 840,
            fastestSecondsPerKm: 660,
            safeStartingWeightKg: 5,
            sourceRaw: BaselineSource.provisional.rawValue,
            establishedAt: now
        )
        context.insert(record)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<CalibrationBaselineRecord>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.baseline?.source == .provisional)
        #expect(fetched.first?.baseline?.safeStartingWeightKg == 5)
    }

    // MARK: - ConditionTagRecord validity / re-screen

    @Test("validity is .active before the twelve-month mark")
    func validityActiveBeforeTwelveMonths() throws {
        let now = Date()
        let recordedAt = calendar.date(byAdding: .month, value: -11, to: now)!
        let record = ConditionTagRecord(tagRaw: ConditionTag.hypertensionManaged.rawValue, recordedAt: recordedAt)
        #expect(record.validity(now: now, calendar: calendar) == .active)
        #expect(record.isReScreenDue(now: now, calendar: calendar) == false)
    }

    @Test("validity is .expiredStillApplied at and after the twelve-month mark")
    func validityExpiredAtTwelveMonths() throws {
        let now = Date()
        let recordedAtExactly = calendar.date(byAdding: .month, value: -12, to: now)!
        let recordedAtPast = calendar.date(byAdding: .month, value: -13, to: now)!

        let exactly = ConditionTagRecord(tagRaw: ConditionTag.hypertensionManaged.rawValue, recordedAt: recordedAtExactly)
        let past = ConditionTagRecord(tagRaw: ConditionTag.hypertensionManaged.rawValue, recordedAt: recordedAtPast)

        #expect(exactly.validity(now: now, calendar: calendar) == .expiredStillApplied)
        #expect(exactly.isReScreenDue(now: now, calendar: calendar) == true)
        #expect(past.validity(now: now, calendar: calendar) == .expiredStillApplied)
        #expect(past.isReScreenDue(now: now, calendar: calendar) == true)
    }

    @Test("a record with editedAt measures the window from the edit, not the original recordedAt")
    func editedAtMeasuresWindowFromEdit() throws {
        let now = Date()
        // Recorded 13 months ago (would be overdue on its own), but edited 1 month ago — the
        // window should measure from the edit and therefore still be active.
        let recordedAt = calendar.date(byAdding: .month, value: -13, to: now)!
        let editedAt = calendar.date(byAdding: .month, value: -1, to: now)!
        let record = ConditionTagRecord(tagRaw: ConditionTag.osteoarthritis.rawValue, recordedAt: recordedAt, editedAt: editedAt)

        #expect(record.validity(now: now, calendar: calendar) == .active)
        #expect(record.isReScreenDue(now: now, calendar: calendar) == false)
    }

    // MARK: - Computed enum accessors never trap on an unrecognised raw value

    @Test("UserProfile's computed enum accessors return nil rather than trapping for an unrecognised raw value")
    func userProfileComputedAccessorsReturnNilForUnrecognisedRawValue() throws {
        let now = Date()
        let profile = UserProfile(
            age: 40,
            explanationRegisterRaw: "not-a-real-register",
            dietaryPatternRaw: "not-a-real-pattern",
            edScreenOutcomeRaw: "not-a-real-tag",
            createdAt: now,
            updatedAt: now
        )
        #expect(profile.explanationRegister == nil)
        #expect(profile.dietaryPattern == nil)
        #expect(profile.edScreenOutcome == nil)
    }

    @Test("ConditionTagRecord.tag returns nil rather than trapping for an unrecognised raw value")
    func conditionTagRecordTagReturnsNilForUnrecognisedRawValue() throws {
        let record = ConditionTagRecord(tagRaw: "not-a-real-tag", recordedAt: Date())
        #expect(record.tag == nil)
    }

    @Test("CalibrationBaselineRecord.baseline returns nil rather than trapping for an unrecognised raw value")
    func calibrationBaselineRecordBaselineReturnsNilForUnrecognisedRawValue() throws {
        let record = CalibrationBaselineRecord(
            slowestSecondsPerKm: 840,
            fastestSecondsPerKm: 660,
            safeStartingWeightKg: 5,
            sourceRaw: "not-a-real-source",
            establishedAt: Date()
        )
        #expect(record.baseline == nil)
    }

    // MARK: - No property holds an individual eating-disorder answer (T-01-60)

    @Test("UserProfile has no property holding an individual eating-disorder answer")
    func userProfileHasNoIndividualEatingDisorderAnswerProperty() throws {
        let profile = UserProfile(age: 25, createdAt: Date(), updatedAt: Date())
        let labels = Mirror(reflecting: profile).children.compactMap(\.label)

        // Positive control: if Mirror can't see UserProfile's own stored properties at all
        // (SwiftData's @Model macro can rewrite stored properties into backing-storage-based
        // accessors that Mirror does not expose the same way it would a plain class), a check
        // for the *absence* of a label would pass vacuously and silently stop testing anything.
        // Fail loudly instead of shipping a test that can never catch T-01-60.
        let sawKnownStoredProperty = labels.contains { label in
            label.lowercased().contains("age") || label.lowercased().contains("dietarypattern")
        }
        #expect(sawKnownStoredProperty, "Mirror did not see UserProfile's own stored properties — this test's negative assertion below cannot be trusted until it does")

        // The five raw SCOFF answers this model must never persist (docs/health-screening.md
        // §1.4's ED-1 through ED-5). A label prefix check avoids false-triggering on
        // `edScreenOutcomeRaw`, which legitimately starts with "ed" but not "ed1"..."ed5".
        let forbiddenPrefixes = ["ed1", "ed2", "ed3", "ed4", "ed5"]
        let violatingLabels = labels.filter { label in
            forbiddenPrefixes.contains { label.lowercased().hasPrefix($0) }
        }
        #expect(violatingLabels.isEmpty, "UserProfile exposes an individual eating-disorder answer property: \(violatingLabels)")
    }
}
