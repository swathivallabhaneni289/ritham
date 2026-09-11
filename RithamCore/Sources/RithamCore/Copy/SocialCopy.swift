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

        /// Plan 04.1-13's own planner-authored additions for the Create Goal-Event screen --
        /// `04.1-UI-SPEC.md`'s Copywriting Contract table has no dedicated rows for a form's field
        /// labels, only the locked CTA/description strings above. Plain, unhurried tone, no
        /// exclamation point, no em/en dash, matching every other "new strings needed this phase"
        /// entry in this file.
        public static let createHeadline = "New group goal"
        public static let nameFieldLabel = "Name"
        public static let nameFieldPlaceholder = "e.g. Saturday 5K Walk"
        public static let activityPrompt = "Activity type"
        public static let targetPrompt = "Add a target?"
        public static let targetHelper = "Optional. Everyone still logs their own time on their own schedule."
        public static let targetNoneOption = "No target"
        public static let targetDistanceOption = "Distance"
        public static let targetDurationOption = "Duration"
        public static let distanceFieldLabel = "Distance (km)"
        public static let durationFieldLabel = "Duration (minutes)"
        public static let startsLabel = "Starts"
        public static let endsLabel = "Ends"
    }

    // MARK: - RSVP

    public enum RSVP {
        /// The RSVP screen's own primary CTA label, quoted directly in `04.1-UI-SPEC.md`'s Layout
        /// & Screen Contract section -- distinct from `confirmation(eventName:)` below, which is
        /// the feedback shown once the viewer has responded, not the button itself.
        public static let cta = "I'm in"

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

        /// Plan 04.1-14's own planner-authored additions for the completion-logging screen --
        /// `04.1-UI-SPEC.md`'s Copywriting Contract has no dedicated rows for this screen's own
        /// button labels or field prompts beyond the two locked strings above. Plain, unhurried
        /// tone, no exclamation point beyond `confirmation(eventName:)`'s own locked one, no
        /// em/en dash, matching every other "new strings needed this phase" entry in this file.
        public static let logCTA = "Log completion"
        public static let addTimeCTA = "Add time"
        public static let skipCTA = "Skip"

        /// Backing out of the inline duration field specifically -- distinct from `skipCTA`
        /// above (which submits the completion with no own time at all), matching the plan's own
        /// "Skip/Never mind still reachable to back out" wording.
        public static let neverMindCTA = "Never mind"
        public static let saveTimeCTA = "Save"
        public static let durationFieldLabel = "Time (minutes)"

        public static let photoPrompt = "Attach a photo?"
        public static let photoOnOption = "Attach a photo"
        public static let photoOffOption = "No photo"
        public static let choosePhotoCTA = "Choose photo"
        public static let photoAttachedConfirmation = "Photo attached"
        public static let photoUploadFailed = "Couldn't attach that photo. Try a different one."

        public static let locationPrompt = "Share the general location?"
        public static let locationOnOption = "Share location"
        public static let locationOffOption = "Don't share"

        public static let noteFieldLabel = "Add a note (optional)"

        /// Source rewrite: `04.1-UI-SPEC.md`'s own suggested heading uses an em dash ("Just for
        /// you -- private"); replaced with a period split here, matching this file's house style.
        public static let privateSectionHeading = "Just for you. Private."
        public static let privateDistanceFieldLabel = "Distance (km)"
        public static let privateDurationFieldLabel = "Duration (minutes)"

        public static let logFailed = "Couldn't log this completion. Check your connection and try again."
        public static let retryCTA = "Try again"
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

        /// Plan 04.1-16's own planner-authored addition -- `04.1-UI-SPEC.md`'s Digital Certificate
        /// section names this exact button label ("`PrimaryCTAButton` 'Export.'") but the
        /// Copywriting Contract table above has no dedicated row for it. Reused verbatim for both
        /// the reveal screen's own CTA into the export flow and the export screen's final action.
        public static let exportCTA = "Export"

        /// The export screen's editable display-name field label -- plan 04.1-16's own
        /// planner-authored addition, following this file's "new strings needed this phase"
        /// convention.
        public static let displayNameFieldLabel = "Certificate name"

        /// Shown instead of the multi-person block when the exporter swaps to the branded default
        /// template, which needs no one else's consent at all (this file's own Certificate section
        /// header comment on why the default template closes the leak path structurally).
        public static let useDefaultTemplateCTA = "Use the default template instead"

        /// Shown when the export-consent check itself failed to complete (a transport failure --
        /// `SocialAPIError.transport` or similar) rather than when it completed and found consent
        /// genuinely outstanding. Distinct from `multiPersonExportBlock` on purpose: that string
        /// makes a specific claim about other people's consent state, which was never actually
        /// established here -- the real cause is that the check itself never finished. WR-01 fix.
        public static let exportGateCheckFailed = "Couldn't check whether this photo is ready to export. Check your connection and try again."

        /// The retry action paired with `exportGateCheckFailed` -- re-runs the same gate check
        /// rather than leaving the exporter stuck with no way forward but dismissing and reopening
        /// the whole export sheet. WR-01 fix.
        public static let retryExportGateCheckCTA = "Try again"
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

    /// `04.1-UI-SPEC.md`'s Copywriting Contract table has no "create a group" entry at all (the
    /// table's own "Start a Group Goal" string is the later goal-event-creation CTA, a different
    /// screen entirely -- see `GoalEvent.createCTA` above). The strings below are plan
    /// 04.1-11's own planner-authored additions, following the same "new strings needed this
    /// phase" convention as `AddFriend`'s three row labels: plain, unhurried tone, no exclamation
    /// point, no em/en dash.
    public enum Groups {
        /// Source rewrite: 04.1-UI-SPEC.md's own suggested wording uses an em dash before "your
        /// choice below"; replaced with a period split here, matching this file's house style.
        public static let leaveGroupConfirmation = "You'll lose access to this group's feed. Your past posts can stay or go. Your choice is below."
        public static let leaveGroupButton = "Leave group"

        /// Plain statement, no shaming language, never the word this comment itself must avoid
        /// using to stay grep-clean for `LeaveGroupSheet.swift`'s own acceptance check.
        public static func removeMemberConfirmation(name: String) -> String {
            "Remove \(name) from this group?"
        }
        public static let removeMemberButton = "Remove"

        public static let createCTA = "Create a group"
        public static let createHeadline = "New group"
        public static let nameFieldLabel = "Name"
        public static let nameFieldPlaceholder = "e.g. Saturday Crew"
        public static let noGroupsYet = "No groups yet. Create one below."
        public static let loadFailed = "Couldn't load your groups. Check your connection and try again."
        public static let inviteCTA = "Invite a friend"
        public static let noFriendsToInvite = "You have no friends to invite yet."

        /// The leave step's two-option chip pair, quoted directly in 04.1-UI-SPEC.md's own Groups
        /// section prose. Neither option is preselected -- see `LeaveGroupSheet.swift`'s own
        /// header comment for why a preselected chip would be exactly the unstated default
        /// `docs/group-events.md` §4 rules out.
        public static let keepPastPostsOption = "Keep my past posts"
        public static let removePastPostsOption = "Remove my past posts too"
        public static let pastPostsPrompt = "What should happen to your past posts?"

        /// Plain body text, per `04.1-UI-SPEC.md`'s own instruction: "If the group's removal
        /// policy needs explaining, it is stated as plain body text on the screen, never as a
        /// marker on one person's identity."
        public static let removalPolicyAnyMember = "Any member of this group can remove another member."
        public static let removalPolicyOrganizerOnly = "Only the person who created this group can remove another member."
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
