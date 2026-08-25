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
    }

    public enum HealthProfile {
        public static let emptyStateHeading = "No health profile yet"
        public static let emptyStateBody = "Complete the safety screening to see your condition tags and adjusted guidance here."
        public static let emptyStateCTA = "Start screening"
    }

    public enum Errors {
        public static let savingFailed = "Couldn't save your answer. Check your connection and try again — nothing you've entered so far is lost."
    }
}
