// EXPLAIN-01: Ritham speaks to every user in one consistent voice. There is no user-chosen
// explanation register (plain-language vs. technical) anywhere in the product -- the product
// owner's direct feedback was that users don't want to choose a "register," so one
// well-written definition serves both a non-technical reader and a technical reader at once.
// The tap-to-expand mechanic itself is still EXPLAIN-01's contract: every technical term
// elsewhere is tap-to-expand into its definition here, just with no register choice gating
// which wording is shown.

/// One glossary term with a single definition, written to be plain enough for a first-time
/// reader and precise enough for a reader who already knows the term of art.
public struct GlossaryEntry: Sendable, Equatable {
    public let term: String
    public let definition: String

    public init(term: String, definition: String) {
        self.term = term
        self.definition = definition
    }
}

/// The glossary EXPLAIN-01's tap-to-expand behavior looks terms up in. Seeded with the
/// technical terms that appear in this phase's copy and in EXPLAIN-01's own named examples.
/// Every definition is written to be non-diagnostic and consistent with the product's
/// guideline-based framing -- none of them states a number Ritham computed specifically for
/// one user, and none implies a diagnosis or a score.
public enum Glossary {
    public static let entries: [String: GlossaryEntry] = {
        let all: [GlossaryEntry] = [
            GlossaryEntry(
                term: "Grade-adjusted pace",
                definition: "Your walking or running pace, adjusted for hills, so a slower pace uphill and a faster pace downhill can be compared fairly to a flat-ground pace."
            ),
            GlossaryEntry(
                term: "One-rep max",
                definition: "1RM, or one-rep max: the most weight you could lift one time for a given exercise, with good form. Ritham estimates this from your everyday sets, so it's never something you need to actually test."
            ),
            GlossaryEntry(
                term: "HRV",
                definition: "Heart rate variability: the variation in time between your heartbeats. Ritham uses it only as a general, guideline-based recovery signal from a paired device, never as a diagnosis of anything."
            ),
            GlossaryEntry(
                term: "RPE",
                definition: "RPE, or Rate of Perceived Exertion: how hard an activity feels to you on a simple scale (for example, 1 to 10), used to set training intensity based on your own effort instead of a number from a device."
            ),
            GlossaryEntry(
                term: "The talk test",
                definition: "A simple way to gauge intensity: if you can talk but not sing, that's moderate effort; if you can only say a few words at a time, that's vigorous effort. It's a practical stand-in for gauging your effort level without any equipment."
            ),
            GlossaryEntry(
                term: "Working set",
                definition: "A set that actually counts toward your training, performed at a load and intensity meant to drive real progress, as distinct from a warm-up set used just to get ready."
            ),
            GlossaryEntry(
                term: "Pace zone",
                definition: "A comfortable range of paces, not a single target number. Ritham always gives you a range to work within, rather than one exact figure to hit."
            ),
            // Plan 01-17's health profile screen: neither term is a diagnosis, and this
            // definition repeats that explicitly, matching the non-diagnostic framing every
            // other screening surface in this phase holds to.
            GlossaryEntry(
                term: "Condition tag",
                definition: "An internal label Ritham uses to remember something you told us in the screening, used only to select which guideline-based adjustment rules apply. It's not a diagnosis, just a way to adjust suggestions safely."
            ),
            GlossaryEntry(
                term: "Clearance gate",
                definition: "How much Ritham can safely personalize a suggestion for you right now: shown normally, shown with a check-with-a-professional note, or held back until you've checked in with one. It's computed from your matched condition tags and never averaged, blended, or softened when more than one applies."
            ),
            GlossaryEntry(
                term: "Professional clearance",
                definition: "A note that you've checked in with a doctor or other qualified professional about a condition. It isn't permanent: Ritham asks again at each re-screen, and it never removes the underlying condition tag."
            ),
        ]
        return Dictionary(uniqueKeysWithValues: all.map { ($0.term, $0) })
    }()

    /// Looks up a glossary entry by its exact `term` string.
    public static func entry(for term: String) -> GlossaryEntry? {
        entries[term]
    }
}
