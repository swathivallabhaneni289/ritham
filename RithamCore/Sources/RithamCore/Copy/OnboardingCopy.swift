// These strings are transcribed verbatim from 01-UI-SPEC.md's Copywriting Contract,
// the rows marked "Original app copy" / "Original app copy — locked, implement
// verbatim". Downstream view plans reference these identifiers rather than
// re-transcribing the locked copy.

/// Namespace for the onboarding screen copy, grouped by screen so call sites read as
/// the screen they belong to.
public enum OnboardingCopy {

    public enum Welcome {
        public static let headline = "Welcome to Ritham."
        public static let subhead = "Real training. Fair streaks. No comparison, ever."
        public static let cta = "Get Started"
    }

    public enum Register {
        public static let headline = "How should we talk to you?"
        public static let optionPlain = "Plain language"
        public static let optionTechnical = "Technical terms"
        public static let helper = "You can change this anytime in Settings."
        public static let cta = "Continue"
    }

    public enum Age {
        public static let headline = "What's your age?"
        public static let helper = "We ask so Ritham can keep things safe and age-appropriate — never to sort you into a different app."
        public static let cta = "Continue"
        public static let invalidAgeError = "Please enter a valid age (1–120)."
    }

    public enum Diet {
        public static let headline = "Any dietary pattern we should know?"
        public static let optionNone = "None"
        public static let optionVegetarian = "Vegetarian"
        public static let optionVegan = "Vegan"
        public static let helper = "This only affects example foods later — never your health screening."
    }

    /// Age blocking (under 13). There is a permanent 13+ floor and nothing else: no
    /// waiting state, no parental-consent copy of any kind, and no separate
    /// partially-gated notice for a 13-17-year-old. `cta` returns the user to Age to
    /// re-enter a different age; nothing entered is saved.
    public enum AgeGate {
        public static let headline = "Ritham is for ages 13+."
        public static let body = "You'll need to be 13 or older to use Ritham. Go back and double-check the age you entered — nothing you entered is saved."
        public static let cta = "Go back"
    }

    public enum Privacy {
        public static let headline = "Your privacy, in plain terms."
        public static let bulletNothingShared = "Nothing is shared or synced with anyone by default."
        public static let bulletAnswersPrivate = "Your health answers stay private — only used to adjust suggestions for you."
        public static let bulletYouChoose = "You choose if and when to share with household members, later."
        public static let cta = "Got it — continue"
    }

    public enum Calibration {
        public static let startHeadline = "Let's find your starting point."
        public static let startBody = "A short walk or light lift — no fitness dropdown, no guessing. This sets your real baseline."
        public static let startCTA = "Start calibration session"
        public static let completeHeadline = "Baseline set."
        public static let completeBody = "You're calibrated — Ritham will use this as your real starting point, not a guess."

        /// D-03 names this exact action "a 'Skip for now' action" -- transcribed verbatim from
        /// that locked decision, the same way every other constant here transcribes its source
        /// verbatim, even though 01-UI-SPEC.md's Copywriting Contract table (which enumerates
        /// only the headline/body/CTA rows) has no dedicated row for it.
        public static let skipCTA = "Skip for now"
    }

    public enum HealthProfile {
        public static let emptyStateHeading = "No health profile yet"
        public static let emptyStateBody = "Complete the safety screening to see your condition tags and adjusted guidance here."
        public static let emptyStateCTA = "Start screening"
    }

    /// `.screeningComplete` -- the acknowledgement shown immediately after the universal
    /// follow-up saves, before the flow reaches `.home`. No source doc names dedicated
    /// copy for this step (01-UI-SPEC.md's Copywriting Contract has no row for it); this
    /// constant is new copy added to close the registration gap `deferred-items.md`'s "From
    /// 01-17" entry flagged, kept deliberately plain and non-diagnostic like every other
    /// screening-adjacent screen in this phase.
    public enum ScreeningComplete {
        public static let headline = "Screening complete."
        public static let body = "Your answers are saved. Ritham will use them to keep your suggestions safe and appropriate for you."
        public static let cta = "Continue"
    }

    /// `.home` -- the flow's terminal step. Phase 1 is onboarding-only; the real home
    /// screen (a 3-item default view with progressive disclosure) is Phase 4's
    /// CROSSGEN/HOUSEHOLD work, not this phase's. This copy states plainly that onboarding
    /// finished without claiming to be that screen -- new copy, for the same reason
    /// `ScreeningComplete` above is new copy.
    public enum Home {
        public static let headline = "You're set up."
        public static let body = "Onboarding is complete. Ritham's tracking and Momentum screens arrive in a later update."
    }

    public enum Errors {
        public static let savingFailed = "Couldn't save your answer. Check your connection and try again — nothing you've entered so far is lost."
    }
}
