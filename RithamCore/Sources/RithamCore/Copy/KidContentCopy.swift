// These are locked product strings for the Kid Ideas screen, following this directory's existing
// `*Copy` namespace convention (ScreeningCopy.swift, SocialCopy.swift, OnboardingCopy.swift,
// MomentumCopy.swift).
//
// `Screen.disclaimer` is transcribed from docs/kid-content.md section 6 with one documented
// change: the source sentence's trailing parenthetical naming two internal requirement
// identifiers ("(see LAUNCH-02/LAUNCH-03)") is dropped, because a requirement ID is an internal
// planning reference and must never appear on a user-facing screen.
//
// Per D-03, no string here names a calorie, portion, serving size, BMI, or weight-management
// figure, and no string asks the parent for a child's age, weight, height, growth, or birthday.
//
// Per D-09, no string offers to save, favourite, or mark an idea, because the screen is
// read-only by design.
//
// No em dash and no en dash (the two Unicode dash characters, not a plain ASCII hyphen) appears
// anywhere in this file, comments included, matching this directory's house style. `KidContentCopyTests`
// asserts this with a hard zero, the same discipline `ScreeningCopy.swift`/`SocialCopy.swift`
// already enforce for themselves.
public enum KidContentCopy {

    // MARK: - Screen

    /// The one combined food-and-movement screen's own chrome (D-05): headline, intro, section
    /// titles, the section 6 disclaimer, the dismissal CTA, and the per-idea source line. Nothing
    /// here suggests two separate screens or a second entry point.
    public enum Screen {
        public static let headline = "Kid Ideas"

        /// Ritham-authored screen chrome, not source text -- a short lead-in sentence introducing
        /// the browsable idea library, distinct from the section 6 disclaimer below.
        public static let intro = "General food and movement ideas for a preteen, reproduced from published USDA and CDC guidance."

        public static let foodSectionTitle = "Food ideas"
        public static let movementSectionTitle = "Movement ideas"

        /// Transcribed verbatim from docs/kid-content.md section 6, with the source sentence's
        /// trailing parenthetical cross-reference to two internal requirement identifiers removed
        /// so the sentence ends after "final release". The word "above" in the second sentence
        /// stays as published; plan 04.2-04 renders this string below the idea lists so that
        /// reading is correct.
        public static let disclaimer = "These are general food-variety and movement ideas, not an individualized meal or exercise plan for your child, and not a substitute for your child's pediatrician or a registered dietitian. Every idea above is reproduced from a published USDA or CDC/HHS source, not written by Ritham. This content is pending clinical and legal review before final release."

        /// Matches every sibling Settings sub-screen's explicit dismissal action.
        public static let doneCTA = "Done"

        /// Takes the assembled attribution string `KidContentCitation.attribution` produces and
        /// returns it prefixed with "Source: ". Pure interpolation, no branching. Declared here so
        /// the citation label's wording is reviewable alongside the disclaimer rather than living
        /// inline in the view.
        public static func sourceLine(attribution: String) -> String {
            "Source: \(attribution)"
        }
    }

    // MARK: - Children

    /// The child-entry management strings KIDCONTENT-02 needs (D-07), written so they never ask
    /// for a name, an age, or anything about a specific child. Ordinal slots with an optional short
    /// nickname, per 04.2-CONTEXT.md's Claude's Discretion paragraph on multi-child labelling.
    public enum Children {
        public static let sectionTitle = "Your children"

        /// The one string in this file that names age, weight, and growth, and it names them to
        /// negate them. `KidContentCopyTests` treats this constant as the single named exception to
        /// the banned-term sweep and asserts positively that it still contains those words, so the
        /// exception can never silently widen to a second constant. If this string is ever reworded
        /// to no longer negate them, the exception must be deleted, not kept.
        public static let explainer = "Ritham stores nothing about your child except this entry. No age, no weight, no growth, and no activity history."

        public static let emptyState = "No children added yet."
        public static let addCTA = "Add a child"

        /// Returns "Child " interpolated with the entry's one-based place in creation order, e.g.
        /// "Child 1" for position 1. This function does no clamping and no zero handling -- callers
        /// pass a one-based position.
        public static func ordinalLabel(_ position: Int) -> String {
            "Child \(position)"
        }

        /// The word "optional" is load-bearing: a required name field is explicitly forbidden here
        /// (04.2-RESEARCH.md Pitfall 2). Changing this label to a bare name prompt is a design
        /// decision needing user confirmation, not a copy tweak.
        public static let nicknameFieldLabel = "Nickname (optional)"

        /// Mirrors `PrivacyZonesView`'s existing row controls so the two list screens read
        /// identically.
        public static let renameCTA = "Rename"
        public static let saveCTA = "Save"
        public static let cancelCTA = "Cancel"
        public static let deleteCTA = "Delete"

        public static let deleteConfirmation = "Remove this child entry?"

        /// Returns "Delete " interpolated with the passed row label, mirroring `PrivacyZonesView`'s
        /// existing per-row delete accessibility label.
        public static func deleteAccessibilityLabel(for label: String) -> String {
            "Delete \(label)"
        }

        public static let saveFailed = "That change could not be saved. Try again."
    }
}
