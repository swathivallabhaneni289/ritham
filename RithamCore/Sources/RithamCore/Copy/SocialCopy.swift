// These strings are transcribed verbatim, character for character, from
// 04.1-UI-SPEC.md's Copywriting Contract "Locked verbatim strings" table, which itself
// transcribes docs/group-events.md Section 2's "Actual copy" table. Downstream view plans
// reference these identifiers rather than re-transcribing or drafting a second copy of any
// string.
//
// No em dash and no en dash (the two Unicode dash characters, not a plain ASCII hyphen) appears
// anywhere in this file, comments included, matching OnboardingCopy.swift/ScreeningCopy.swift/
// MomentumCopy.swift's house-style convention for this directory. The PRD's own Section 2 table
// uses an em dash in two of this file's locked strings -- "...no ranking -- log it whenever it
// works for you." and "...Saturday 5K Walk -- 32:14." -- and 04.1-UI-SPEC.md's Copywriting
// Contract already supplies the house-style rewrite for both (a comma before "log it," and "in"
// before the time value), carried verbatim here. A third, non-PRD string in this file
// (`Groups.leaveGroupConfirmation`, 04.1-UI-SPEC.md's own "Claude's Discretion" suggested wording)
// also used an em dash in its source; rewritten the same way, with a period split. Every
// substitution is called out at its declaration below, so a future editor does not "restore" a
// dash that was deliberately removed.
//
// "You did it! 🎉 Logged for the Saturday 5K Walk." carries the first emoji in any `*Copy`
// namespace in this project (see 04.1-UI-SPEC.md's Emoji note). It is preserved because
// 04.1-CONTEXT.md marks the full Section 2 table as locked verbatim, not paraphrased -- this is a
// sourced and locked decision, not a paste artifact to clean up.
//
// This phase adds no error string of any kind. Where an error or generic action string is
// eventually needed, reuse `OnboardingCopy.Errors.savingFailed` verbatim rather than drafting a
// second one, matching `MomentumCopy.swift`'s own stated reuse rule.
//
// Tone constraint for every string in this file, locked and new alike (04.1-UI-SPEC.md
// Copywriting Contract): plain, unhurried, never urgent or threat-framed; no exclamation point
// except where a locked string already has one (`Completion.confirmation`, above); no dashes.
public enum SocialCopy {

    // MARK: - Goal-Event creation

    public enum GoalEvent {
        public static let createCTA = "Start a Group Goal"

        /// Source table rewrite: the source em dash before "log it whenever it works for you" is
        /// replaced with a comma here, preserving the sentence's meaning without the excluded
        /// punctuation mark.
        public static let description = "Everyone does this together, on their own time. There's no clock and no ranking, so log it whenever it works for you."
    }

    // MARK: - RSVP

    public enum RSVP {
        public static func confirmation(eventName: String) -> String {
            "You're in for the \(eventName)."
        }

        /// Pre-event progress, RSVP screen only -- this number and this screen never appear again
        /// once the event has completions to show (04.1-UI-SPEC.md Non-Comparative Structural
        /// Visual Rules, Rule 2).
        public static func headcount(_ count: Int) -> String {
            "\(count) friends are in."
        }
    }

    // MARK: - Completion

    public enum Completion {
        public static func confirmation(eventName: String) -> String {
            "You did it! \u{1F389} Logged for the \(eventName)."
        }

        /// A skip action for this prompt must render exactly as prominent as the add-time action
        /// (04.1-UI-SPEC.md Spacing Scale's equal-prominence-pair rule) -- that layout constraint
        /// belongs to the view layer, not this copy catalog.
        public static let ownTimePrompt = "Want to add your time? Totally up to you."
    }

    // MARK: - Feed

    public enum Feed {
        public static func card(name: String, eventName: String) -> String {
            "\(name) completed the \(eventName)."
        }

        /// Source table rewrite: the source em dash before the time value is replaced with " in"
        /// here, preserving the sentence's meaning without the excluded punctuation mark. Renders
        /// identically to the no-time card except for this trailing clause -- no color or badge
        /// differentiates the two (04.1-UI-SPEC.md Color section).
        public static func card(name: String, eventName: String, time: String) -> String {
            "\(name) completed the \(eventName) in \(time)."
        }

        /// Group history heading, post-window. No count, no fraction, ever -- the completion
        /// cards are the summary (docs/group-events.md Section 2's "Actual copy" table).
        public static let groupHistoryHeading = "Completed by:"
    }

    // MARK: - Cheer

    /// The fixed, non-ranked cheer set's shipped copy, matching `RithamCore.Cheer.allCases`
    /// one-for-one. Transcribed verbatim from REQUIREMENTS.md's `HOUSEHOLD-01` wording.
    public enum Cheer {
        public static let niceWork = "Nice work"
        public static let keepGoing = "Keep going"
    }

    // MARK: - Certificate

    public enum Certificate {
        public static let creationTimeNudge = "This name will be visible on any exported certificate."
        public static let exportPreviewLabel = "This is what will be shared outside Ritham."
        public static let multiPersonExportBlock = "Everyone visible in this photo needs to approve sharing it outside Ritham before you can export it."
    }

    // MARK: - Privacy Zone

    public enum PrivacyZone {
        public static let suppressedNote = "This location is private and won't be shown."
    }

    // MARK: - Add Friend

    /// Row labels for the three closed-loop connection paths, matching
    /// `FriendConnectionPath.allCases` in spirit (not enumerated 1:1 here, since the opt-in
    /// toggle label and the row label are two different strings for the contact-matching path).
    public enum AddFriend {
        public static let contactMatchingRow = "Match contacts"
        public static let inviteLinkRow = "Invite link or QR code"
        public static let inPersonRow = "Share directly"
    }

    // MARK: - Groups

    public enum Groups {
        /// Source rewrite: 04.1-UI-SPEC.md's own suggested wording uses an em dash before "your
        /// choice below"; replaced with a period split here, matching this file's house style.
        public static let leaveGroupConfirmation = "You'll lose access to this group's feed. Your past posts can stay or go. Your choice is below."
        public static let leaveGroupButton = "Leave group"

        /// Plain statement, no shaming language, never "kicked."
        public static func removeMemberConfirmation(name: String) -> String {
            "Remove \(name) from this group?"
        }
        public static let removeMemberButton = "Remove"
    }

    // MARK: - Sign in with Apple

    public enum SignInWithApple {
        public static let headline = "Sign in to connect with friends"

        /// States explicitly: optional, not required for tracking, restores the friend graph,
        /// groups, and certificates on a new device (04.1-CONTEXT.md's Identity & Account
        /// Recovery decision).
        public static let body = "This is optional, and never required for core tracking. Signing in with Apple connects you with friends and groups, and restores your friend graph, groups, and certificates if you get a new device."
    }
}
