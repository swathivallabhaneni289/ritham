// EXPLAIN-01: the user picks an explanation register (plain-language or technical) once at
// onboarding, and can change it anytime from Settings. No code anywhere may derive a
// register from age, an age-derived eligibility category, or any other profile attribute —
// there is no such thing as an "age-appropriate" register. Register selection and
// MINOR-01's 13+ eligibility floor are two completely independent axes; conflating them
// would reintroduce exactly the kind of age-based fork CROSSGEN-05 forbids.

/// The two explanation registers EXPLAIN-01 lets a user choose between for technical terms
/// (e.g. "grade-adjusted pace" vs. "1RM") that appear throughout the app's copy.
public enum ExplanationRegister: String, CaseIterable, Sendable, Codable {
    case plainLanguage
    case technical

    /// The user-facing option label shown on the register-selection screen, sourced from the
    /// locked `OnboardingCopy.Register` catalog rather than re-transcribed here.
    public var optionLabel: String {
        switch self {
        case .plainLanguage:
            return OnboardingCopy.Register.optionPlain
        case .technical:
            return OnboardingCopy.Register.optionTechnical
        }
    }
}

/// One glossary term, with a definition written in both registers. EXPLAIN-01's tap-to-expand
/// behavior looks a term up and renders whichever register the user currently has selected.
public struct GlossaryEntry: Sendable, Equatable {
    public let term: String
    public let plainLanguageDefinition: String
    public let technicalDefinition: String

    public init(term: String, plainLanguageDefinition: String, technicalDefinition: String) {
        self.term = term
        self.plainLanguageDefinition = plainLanguageDefinition
        self.technicalDefinition = technicalDefinition
    }

    /// The definition text for the given register. Every definition is written to be plain,
    /// non-diagnostic, and consistent with the product's guideline-based framing — neither
    /// register ever states a number Ritham computed specifically for one user, and neither
    /// implies a diagnosis or a score.
    public func definition(for register: ExplanationRegister) -> String {
        switch register {
        case .plainLanguage:
            return plainLanguageDefinition
        case .technical:
            return technicalDefinition
        }
    }
}

/// The glossary EXPLAIN-01's tap-to-expand behavior looks terms up in. Seeded with the
/// technical terms that appear in this phase's copy and in EXPLAIN-01's own named examples.
public enum Glossary {
    public static let entries: [String: GlossaryEntry] = {
        let all: [GlossaryEntry] = [
            GlossaryEntry(
                term: "Grade-adjusted pace",
                plainLanguageDefinition: "Your walking or running pace, adjusted for hills — so a slower pace uphill and a faster pace downhill can be compared fairly to a flat-ground pace.",
                technicalDefinition: "Pace normalized for the metabolic cost of incline/decline (grade), expressed as an equivalent flat-ground pace."
            ),
            GlossaryEntry(
                term: "One-rep max",
                plainLanguageDefinition: "The most weight you could lift one time for a given exercise, with good form. Ritham estimates this — it's never something you need to actually test.",
                technicalDefinition: "1RM: the maximum load that can be lifted for a single repetition with correct technique, typically estimated from submaximal-set performance rather than tested directly."
            ),
            GlossaryEntry(
                term: "HRV",
                plainLanguageDefinition: "A measure of the small variations in time between your heartbeats. It's one general signal of how recovered your body is — not a diagnosis of anything.",
                technicalDefinition: "Heart rate variability: the variation in time intervals between consecutive heartbeats, used here only as a general, guideline-based recovery signal from a paired device — never as a diagnostic measure."
            ),
            GlossaryEntry(
                term: "RPE",
                plainLanguageDefinition: "How hard an activity feels to you, on a simple scale — a way to set intensity based on your own effort instead of a number from a device.",
                technicalDefinition: "Rate of Perceived Exertion: a subjective effort scale (e.g. 1-10) used to set or describe training intensity independent of heart-rate-zone data."
            ),
            GlossaryEntry(
                term: "The talk test",
                plainLanguageDefinition: "A simple way to gauge intensity: if you can talk but not sing, that's moderate effort; if you can only say a few words at a time, that's vigorous effort.",
                technicalDefinition: "A ventilatory-threshold proxy: the ability to comfortably converse (moderate intensity) versus speak only in short phrases (vigorous intensity) during activity."
            ),
            GlossaryEntry(
                term: "Working set",
                plainLanguageDefinition: "A set that actually counts toward your training — not a warm-up set used just to get ready.",
                technicalDefinition: "A resistance-training set performed at a training load/intensity intended to drive adaptation, as distinct from a warm-up set."
            ),
            GlossaryEntry(
                term: "Pace zone",
                plainLanguageDefinition: "A comfortable range of paces, not a single target number — Ritham always gives you a range to work within rather than one exact figure to hit.",
                technicalDefinition: "A pace interval (seconds per kilometer) bounding a target training effort, expressed as a range rather than a single value to avoid a single-number performance target."
            ),
        ]
        return Dictionary(uniqueKeysWithValues: all.map { ($0.term, $0) })
    }()

    /// Looks up a glossary entry by its exact `term` string.
    public static func entry(for term: String) -> GlossaryEntry? {
        entries[term]
    }
}
