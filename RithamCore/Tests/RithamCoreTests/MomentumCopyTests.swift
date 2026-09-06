import Foundation
import Testing
@testable import RithamCore

@Suite("MomentumCopyTests")
struct MomentumCopyTests {

    /// Transcribed, one entry per token, from 03-UI-SPEC.md's Copywriting Contract
    /// banned-lexicon table, splitting each slash-separated row into its individual tokens.
    /// The exclamation-point row is its own single-character entry. The final row
    /// (accusatory second-person framing of a miss) is a pattern, not a token, and is
    /// covered by its own dedicated test below instead of appearing in this list.
    private static let bannedTokens: [String] = [
        "lost",
        "you lost",
        "broken",
        "don't lose",
        "don't break",
        "reset",
        "zero",
        "failed",
        "failure",
        "expire",
        "expires",
        "expired",
        "countdown",
        "!",
    ]

    /// Every constant and every function result `MomentumCopy` ships, called with
    /// representative arguments where interpolation is involved. Adding a constant to
    /// `MomentumCopy` without adding it here is caught only by the count assertion in
    /// `everyShippedStringIsAccountedFor` below, not by any other mechanism -- Swift has no
    /// reflection over an enum namespace's static members.
    private static let shippedStrings: [(name: String, value: String)] = [
        ("Progress.weekly", MomentumCopy.Progress.weekly(count: 2, target: 3)),
        ("Progress.weeklyAccessibility", MomentumCopy.Progress.weeklyAccessibility(count: 2, target: 3)),
        ("Streak.streak", MomentumCopy.Streak.streak(weeks: 5)),
        // weeks: 0 is the one interpolation case in this catalog that can produce a literal
        // "0" digit, the exact quantity the banned-lexicon table's "zero" row is about (it
        // forbids "zero" *describing the user's own count going back to it", not the digit
        // itself as a token match, but it is the case worth gating explicitly).
        ("Streak.streak(weeks: 0)", MomentumCopy.Streak.streak(weeks: 0)),
        ("Streak.rebuiltStreak", MomentumCopy.Streak.rebuiltStreak),
        ("Shields.shields", MomentumCopy.Shields.shields(earned: 2)),
        ("Comeback.headline", MomentumCopy.Comeback.headline),
        ("Comeback.body", MomentumCopy.Comeback.body(deadline: "Monday, September 14")),
        ("Comeback.button", MomentumCopy.Comeback.button),
        ("Milestones.week4", MomentumCopy.Milestones.week4),
        ("Milestones.week12", MomentumCopy.Milestones.week12),
        ("Milestones.week26", MomentumCopy.Milestones.week26),
        ("Milestones.week52", MomentumCopy.Milestones.week52),
        ("Milestones.bonusShieldNote", MomentumCopy.Milestones.bonusShieldNote),
        ("RecoveryWeek.flagButton", MomentumCopy.RecoveryWeek.flagButton),
        ("RecoveryWeek.alertTitle", MomentumCopy.RecoveryWeek.alertTitle),
        ("RecoveryWeek.alertBody", MomentumCopy.RecoveryWeek.alertBody),
        ("RecoveryWeek.confirmButton", MomentumCopy.RecoveryWeek.confirmButton),
        ("Injury.flagButton", MomentumCopy.Injury.flagButton),
        ("Injury.alertTitle", MomentumCopy.Injury.alertTitle),
        ("Injury.alertBody", MomentumCopy.Injury.alertBody),
        ("Injury.confirmButton", MomentumCopy.Injury.confirmButton),
        ("Injury.clearButton", MomentumCopy.Injury.clearButton),
        ("Injury.clearAlertTitle", MomentumCopy.Injury.clearAlertTitle),
        ("Sleep.headline", MomentumCopy.Sleep.headline),
        ("Sleep.optionGreat", MomentumCopy.Sleep.optionGreat),
        ("Sleep.optionOK", MomentumCopy.Sleep.optionOK),
        ("Sleep.optionPoor", MomentumCopy.Sleep.optionPoor),
        ("Sleep.noteFieldLabel", MomentumCopy.Sleep.noteFieldLabel),
        ("Plan.banner", MomentumCopy.Plan.banner),
        ("Plan.showOriginalCTA", MomentumCopy.Plan.showOriginalCTA),
        ("Plan.showLighterCTA", MomentumCopy.Plan.showLighterCTA),
        ("Snapshot.toggleLabel", MomentumCopy.Snapshot.toggleLabel),
        ("Snapshot.toggleHelper", MomentumCopy.Snapshot.toggleHelper),
        ("Snapshot.toggleOptionOn", MomentumCopy.Snapshot.toggleOptionOn),
        ("Snapshot.toggleOptionOff", MomentumCopy.Snapshot.toggleOptionOff),
        ("Target.pickerPrompt", MomentumCopy.Target.pickerPrompt),
        ("Target.pickerHelper", MomentumCopy.Target.pickerHelper),
        ("Empty.noSessionsHeadline", MomentumCopy.Empty.noSessionsHeadline),
        ("Empty.noSessionsBody", MomentumCopy.Empty.noSessionsBody),
        ("Empty.noShieldsHeadline", MomentumCopy.Empty.noShieldsHeadline),
        ("Empty.noShieldsBody", MomentumCopy.Empty.noShieldsBody),
        ("Empty.noMilestonesHeadline", MomentumCopy.Empty.noMilestonesHeadline),
        ("Empty.noMilestonesBody", MomentumCopy.Empty.noMilestonesBody),
        ("Empty.noSnapshotEntriesHeadline", MomentumCopy.Empty.noSnapshotEntriesHeadline),
        ("Empty.noSnapshotEntriesBody", MomentumCopy.Empty.noSnapshotEntriesBody),
        ("Verification.sensorVerified", MomentumCopy.Verification.sensorVerified),
        ("Verification.manuallyEntered", MomentumCopy.Verification.manuallyEntered),
    ]

    @Test("every shipped string in this suite's array is accounted for")
    func everyShippedStringIsAccountedFor() {
        // Guards the array above, not the catalog itself: Swift has no reflection over an
        // enum namespace's static members, so this cannot mechanically detect a new
        // MomentumCopy constant that was never added to shippedStrings. It does catch an
        // accidental duplicate or removal within this file.
        #expect(Self.shippedStrings.count == 48)
    }

    @Test("no shipped Momentum or Recovery string contains a banned framing token")
    func noShippedStringContainsBannedToken() {
        for entry in Self.shippedStrings {
            let lowered = entry.value.lowercased()
            for token in Self.bannedTokens {
                #expect(
                    !lowered.contains(token.lowercased()),
                    "\(entry.name) contains banned token \"\(token)\": \"\(entry.value)\""
                )
            }
        }
    }

    @Test("no shipped string uses accusatory second-person framing of a miss, and the comeback body uses a plain deadline statement instead of expiry framing")
    func noAccusatoryMissFramingAndComebackUsesDeadlineFraming() {
        for entry in Self.shippedStrings {
            #expect(
                !entry.value.lowercased().contains("you missed it"),
                "\(entry.name) contains accusatory framing: \"\(entry.value)\""
            )
        }

        let comebackBody = MomentumCopy.Comeback.body(deadline: "Monday, September 14")
        #expect(comebackBody.contains("by "), "Comeback.body should use a plain \"by {date}\" statement")
        #expect(!comebackBody.lowercased().contains("expire"), "Comeback.body should never use expiry/countdown framing")
    }

    @Test("every milestone tier has exactly one line of competence-framed copy")
    func everyMilestoneTierHasExactlyOneLine() {
        let tiers = [4, 12, 26, 52]
        for tier in tiers {
            let line = MomentumCopy.Milestones.line(forWeekCount: tier)
            #expect(line != nil, "tier \(tier) should return a non-nil line")
            #expect(!(line ?? "").isEmpty, "tier \(tier) should return a non-empty line")
        }
        #expect(MomentumCopy.Milestones.line(forWeekCount: 5) == nil)
        #expect(MomentumCopy.Milestones.line(forWeekCount: 13) == nil)
        #expect(MomentumCopy.Milestones.line(forWeekCount: 0) == nil)
    }

    @Test("the rebuilt-streak line frames a rebuild rather than an erasure")
    func rebuiltStreakLineFramesRebuild() {
        #expect(MomentumCopy.Streak.rebuiltStreak == "Week 1 of your rebuilt streak")
    }

    @Test("no shipped string is empty or whitespace-only")
    func noShippedStringIsEmptyOrWhitespace() {
        for entry in Self.shippedStrings {
            let trimmed = entry.value.trimmingCharacters(in: .whitespacesAndNewlines)
            #expect(!trimmed.isEmpty, "\(entry.name) is empty or whitespace-only")
        }
    }

    @Test("the Verification namespace's strings match CardioHistoryView's existing labels")
    func verificationStringsMatchCardioHistoryView() {
        #expect(MomentumCopy.Verification.sensorVerified == "Sensor-verified")
        #expect(MomentumCopy.Verification.manuallyEntered == "Manually entered")
    }
}
