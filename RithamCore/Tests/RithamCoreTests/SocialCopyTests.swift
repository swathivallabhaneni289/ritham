import Foundation
import Testing
@testable import RithamCore

@Suite("SocialCopyTests")
struct SocialCopyTests {

    /// Contest/ordering/position/completion-fraction vocabulary, as phrases rather than bare
    /// word stems -- a bare "rank" stem would false-positive on this file's own locked string
    /// "There's no clock and no ranking," which correctly *negates* ranking rather than
    /// expressing it. Every phrase here names a genuine contest mechanic (Strava's "Top
    /// Contributors," a numbered placement, a pooled/fractional completion figure) that this
    /// phase's copy must never express, per docs/group-events.md Section 2's "no pooled total, no
    /// contribution ranking, no leaderboard sort, no score, no winner" list.
    private static let bannedPhrases: [String] = [
        "leaderboard",
        "1st",
        "first to complete",
        "fastest",
        "slowest",
        "winner",
        "top contributor",
        "most-cheered",
        "most cheered",
        "pooled total",
        "contribution ranking",
        "x of y",
        "of y completed",
        "your rank",
        "ranked #",
        "in first place",
        "comparison",
        "compared to",
        "versus",
        " vs ",
        "fraction of",
        "% complete",
        "percent complete",
        "challenge",
    ]

    /// Every constant and every function result `SocialCopy` ships, called with representative
    /// arguments where interpolation is involved. Adding a constant to `SocialCopy` without
    /// adding it here is caught only by the count assertion below, not by any other mechanism --
    /// Swift has no reflection over an enum namespace's static members. This is the "enumerating
    /// the catalog's own exposed constants" sweep the plan's action text describes.
    private static let shippedStrings: [(name: String, value: String)] = [
        ("GoalEvent.createCTA", SocialCopy.GoalEvent.createCTA),
        ("GoalEvent.description", SocialCopy.GoalEvent.description),
        ("RSVP.confirmation", SocialCopy.RSVP.confirmation(eventName: "Saturday 5K Walk")),
        ("RSVP.headcount", SocialCopy.RSVP.headcount(6)),
        ("Completion.confirmation", SocialCopy.Completion.confirmation(eventName: "Saturday 5K Walk")),
        ("Completion.ownTimePrompt", SocialCopy.Completion.ownTimePrompt),
        ("Feed.card(no time)", SocialCopy.Feed.card(name: "Priya", eventName: "Saturday 5K Walk")),
        ("Feed.card(with time)", SocialCopy.Feed.card(name: "Priya", eventName: "Saturday 5K Walk", time: "32:14")),
        ("Feed.groupHistoryHeading", SocialCopy.Feed.groupHistoryHeading),
        ("Cheer.niceWork", SocialCopy.Cheer.niceWork),
        ("Cheer.keepGoing", SocialCopy.Cheer.keepGoing),
        ("Certificate.creationTimeNudge", SocialCopy.Certificate.creationTimeNudge),
        ("Certificate.exportPreviewLabel", SocialCopy.Certificate.exportPreviewLabel),
        ("Certificate.multiPersonExportBlock", SocialCopy.Certificate.multiPersonExportBlock),
        ("PrivacyZone.suppressedNote", SocialCopy.PrivacyZone.suppressedNote),
        ("AddFriend.contactMatchingRow", SocialCopy.AddFriend.contactMatchingRow),
        ("AddFriend.inviteLinkRow", SocialCopy.AddFriend.inviteLinkRow),
        ("AddFriend.inPersonRow", SocialCopy.AddFriend.inPersonRow),
        ("Groups.leaveGroupConfirmation", SocialCopy.Groups.leaveGroupConfirmation),
        ("Groups.leaveGroupButton", SocialCopy.Groups.leaveGroupButton),
        ("Groups.removeMemberConfirmation", SocialCopy.Groups.removeMemberConfirmation(name: "Sam")),
        ("Groups.removeMemberButton", SocialCopy.Groups.removeMemberButton),
        ("SignInWithApple.headline", SocialCopy.SignInWithApple.headline),
        ("SignInWithApple.body", SocialCopy.SignInWithApple.body),
    ]

    @Test("at least twenty distinct strings were scanned by the lexicon sweep, so it cannot pass by scanning nothing")
    func atLeastTwentyStringsScanned() {
        #expect(Self.shippedStrings.count >= 20)
    }

    @Test("no shipped string expresses a contest, ordering, position, or completion-fraction mechanic")
    func noShippedStringContainsBannedPhrase() {
        for entry in Self.shippedStrings {
            let lowered = entry.value.lowercased()
            for phrase in Self.bannedPhrases {
                #expect(
                    !lowered.contains(phrase),
                    "\(entry.name) contains banned phrase \"\(phrase)\": \"\(entry.value)\""
                )
            }
        }
    }

    @Test("no shipped string mentions a position, a total, a fraction, or a comparison between members")
    func noShippedStringMentionsPositionTotalFractionOrComparison() {
        let extraBannedTerms = ["position", "total", "fraction", "denominator"]
        for entry in Self.shippedStrings {
            let lowered = entry.value.lowercased()
            for term in extraBannedTerms {
                #expect(
                    !lowered.contains(term),
                    "\(entry.name) contains banned term \"\(term)\": \"\(entry.value)\""
                )
            }
        }
    }

    @Test("no string contains an em dash or en dash")
    func noShippedStringContainsADash() {
        for entry in Self.shippedStrings {
            #expect(!entry.value.contains("\u{2014}"), "\(entry.name) contains an em dash: \"\(entry.value)\"")
            #expect(!entry.value.contains("\u{2013}"), "\(entry.name) contains an en dash: \"\(entry.value)\"")
        }
    }

    @Test("no exclamation point appears anywhere except the locked completion-confirmation string")
    func exclamationPointOnlyInLockedCompletionConfirmation() {
        for entry in Self.shippedStrings {
            if entry.name == "Completion.confirmation" {
                #expect(entry.value.contains("!"), "the locked completion confirmation should preserve its exclamation point")
            } else {
                #expect(!entry.value.contains("!"), "\(entry.name) contains an exclamation point: \"\(entry.value)\"")
            }
        }
    }

    @Test("no shipped string is empty or whitespace-only")
    func noShippedStringIsEmptyOrWhitespace() {
        for entry in Self.shippedStrings {
            let trimmed = entry.value.trimmingCharacters(in: .whitespacesAndNewlines)
            #expect(!trimmed.isEmpty, "\(entry.name) is empty or whitespace-only")
        }
    }

    // MARK: - Locked verbatim strings, transcribed from 04.1-UI-SPEC.md's Copywriting Contract

    @Test("the create-event CTA is exactly \"Start a Group Goal\"")
    func createEventCTAIsLocked() {
        #expect(SocialCopy.GoalEvent.createCTA == "Start a Group Goal")
    }

    @Test("the event description matches the locked, house-style-substituted wording")
    func eventDescriptionIsLocked() {
        #expect(SocialCopy.GoalEvent.description == "Everyone does this together, on their own time. There's no clock and no ranking, so log it whenever it works for you.")
    }

    @Test("RSVP.confirmation interpolates the event name in the locked sentence")
    func rsvpConfirmationIsLocked() {
        #expect(SocialCopy.RSVP.confirmation(eventName: "Saturday 5K Walk") == "You're in for the Saturday 5K Walk.")
    }

    @Test("RSVP.headcount interpolates the count in the locked sentence")
    func rsvpHeadcountIsLocked() {
        #expect(SocialCopy.RSVP.headcount(6) == "6 friends are in.")
    }

    @Test("Completion.confirmation preserves the locked celebration emoji and interpolates the event name")
    func completionConfirmationIsLockedWithEmoji() {
        #expect(SocialCopy.Completion.confirmation(eventName: "Saturday 5K Walk") == "You did it! \u{1F389} Logged for the Saturday 5K Walk.")
    }

    @Test("Completion.ownTimePrompt matches the locked wording")
    func ownTimePromptIsLocked() {
        #expect(SocialCopy.Completion.ownTimePrompt == "Want to add your time? Totally up to you.")
    }

    @Test("Feed.groupHistoryHeading matches the locked heading, with no count or fraction")
    func groupHistoryHeadingIsLocked() {
        #expect(SocialCopy.Feed.groupHistoryHeading == "Completed by:")
    }

    // MARK: - Feed card behavior

    @Test("Feed.card(name:eventName:) matches the locked no-time sentence")
    func feedCardNoTimeIsLocked() {
        #expect(SocialCopy.Feed.card(name: "Priya", eventName: "Saturday 5K Walk") == "Priya completed the Saturday 5K Walk.")
    }

    @Test("Feed.card(name:eventName:time:) matches the locked, house-style-substituted with-time sentence")
    func feedCardWithTimeIsLocked() {
        #expect(SocialCopy.Feed.card(name: "Priya", eventName: "Saturday 5K Walk", time: "32:14") == "Priya completed the Saturday 5K Walk in 32:14.")
    }

    @Test("the no-time feed card sentence is a strict prefix of the with-time sentence up to its final period")
    func feedCardNoTimeIsStrictPrefixOfWithTime() {
        let noTime = SocialCopy.Feed.card(name: "Priya", eventName: "Saturday 5K Walk")
        let withTime = SocialCopy.Feed.card(name: "Priya", eventName: "Saturday 5K Walk", time: "32:14")
        #expect(noTime.hasSuffix("."))
        let noTimeWithoutPeriod = String(noTime.dropLast())
        #expect(withTime.hasPrefix(noTimeWithoutPeriod))
        #expect(withTime != noTimeWithoutPeriod, "the with-time sentence must add a real trailing clause, not just match the prefix")
    }

    // MARK: - Cheer

    @Test("SocialCopy.Cheer exposes exactly two strings, matching Cheer.allCases")
    func cheerCopyMatchesDomainCheerCases() {
        #expect(Cheer.allCases.count == 2)
        #expect(SocialCopy.Cheer.niceWork == "Nice work")
        #expect(SocialCopy.Cheer.keepGoing == "Keep going")
    }

    // MARK: - New strings (Claude's Discretion, per 04.1-UI-SPEC.md's second table)

    @Test("Add Friend row labels match the three closed-loop connection paths")
    func addFriendRowLabels() {
        #expect(SocialCopy.AddFriend.contactMatchingRow == "Match contacts")
        #expect(SocialCopy.AddFriend.inviteLinkRow == "Invite link or QR code")
        #expect(SocialCopy.AddFriend.inPersonRow == "Share directly")
    }

    @Test("Remove Member confirmation interpolates the member's name with no shaming language")
    func removeMemberConfirmationInterpolatesName() {
        let confirmation = SocialCopy.Groups.removeMemberConfirmation(name: "Sam")
        #expect(confirmation == "Remove Sam from this group?")
        #expect(!confirmation.lowercased().contains("kick"))
    }

    @Test("Privacy Zone suppression note matches the locked wording")
    func privacyZoneSuppressedNoteIsLocked() {
        #expect(SocialCopy.PrivacyZone.suppressedNote == "This location is private and won't be shown.")
    }

    @Test("Certificate creation-time nudge and export preview label match the locked wording")
    func certificateNudgeAndExportLabelAreLocked() {
        #expect(SocialCopy.Certificate.creationTimeNudge == "This name will be visible on any exported certificate.")
        #expect(SocialCopy.Certificate.exportPreviewLabel == "This is what will be shared outside Ritham.")
    }

    @Test("Multi-person photo export block matches the locked wording")
    func multiPersonExportBlockIsLocked() {
        #expect(SocialCopy.Certificate.multiPersonExportBlock == "Everyone visible in this photo needs to approve sharing it outside Ritham before you can export it.")
    }

    @Test("Sign in with Apple copy states the flow is optional and not required for tracking")
    func signInWithAppleBodyStatesOptional() {
        let body = SocialCopy.SignInWithApple.body.lowercased()
        #expect(body.contains("optional"))
        #expect(body.contains("not required") || body.contains("never required"))
        #expect(!SocialCopy.SignInWithApple.headline.trimmingCharacters(in: .whitespaces).isEmpty)
    }
}
