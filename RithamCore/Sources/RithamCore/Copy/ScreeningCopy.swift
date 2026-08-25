// These strings are transcribed verbatim from docs/health-screening.md and
// 01-UI-SPEC.md's Copywriting Contract. They are pending LAUNCH-01 (counsel) review
// for the PAR-Q+-style gate wording and LAUNCH-02 (clinician) review for the SCOFF
// wording/scoring, per 01-UI-SPEC.md. They ship as-is for Phase 1 per the roadmap's
// own sequencing (Phase 5 gates the review, not Phase 1 build).
//
// Consumers must not impose fixed-height containers on these strings — a Phase 5
// revision to their length is expected, and the layout/interaction contract must
// tolerate string-length changes without redesign.

/// Namespace for the verbatim disclaimer, legal, and framing copy used throughout the
/// health screening flow (§1.2-1.4 and §4.1-4.7 of docs/health-screening.md).
public enum ScreeningCopy {

    // MARK: - §4.1 Questionnaire opening disclaimer (shown once, before Question 1)

    public static let openingDisclaimer = """
    Ritham asks a few questions about your health so we can show general, guideline-based workout and food suggestions that fit you better — not to diagnose or treat anything. This is a short screening questionnaire, not a medical exam, and your answers aren't reviewed by a doctor or dietitian.

    If you have a health condition, are pregnant, are recovering from an injury or surgery, or take medication, please talk to your doctor or another qualified professional before starting or changing an exercise or eating routine. If you think you might be having a medical emergency right now, stop and call 911 (or your local emergency number) instead of continuing this questionnaire.

    Every suggestion Ritham gives you afterward is a general starting point you can edit or turn off, and you can update these answers anytime in Settings.
    """

    // MARK: - §4.2 Routine clearance interstitial (any Gate G1-G7 = Yes, without G2/G3)

    public static let routineClearanceInterstitial = """
    **Let's have you check in with a professional first.**

    Based on what you told us, we'd like you to talk with a doctor or a qualified exercise/nutrition professional before we turn on personalized workout and food suggestions. This isn't Ritham judging your fitness — it's just that a few of your answers are outside what a general screening questionnaire can safely personalize on its own.

    You can still use Ritham to log workouts and meals manually, and see general (non-personalized) guidance, in the meantime. Once you've checked in with a professional, come back to Settings and let us know — we'll turn personalized suggestions back on.
    """

    public static let routineClearanceCTA = "Continue to the rest of the questions"

    // MARK: - §4.3 Urgent clearance interstitial (G2 or G3 = Yes)

    public static let urgentClearanceInterstitial = """
    **Before anything else: if you're currently experiencing chest pain, difficulty breathing, sudden severe dizziness, or think you may be having a medical emergency, stop and call 911 (or your local emergency number) right now. Don't wait to finish this questionnaire.**

    If that's not what's happening right now: based on your answers, please talk with a doctor before starting or changing an exercise routine. We'll hold off on personalized suggestions until you've done that.
    """

    public static let urgentClearanceCTA = "I understand — continue to the rest of the questions"

    // MARK: - §4.6 Required-blocking message

    public static let requiredBlockingMessage = """
    **We're holding off on personalized suggestions here.**

    Based on what you told us, this isn't something Ritham can safely tailor on its own — we'd like you to check with a doctor, registered dietitian, or other qualified professional first. You can still track your workouts and meals manually, and see general, non-personalized information.

    Once you've talked with a professional, come back to Settings to let us know, and we'll turn personalized suggestions back on for this area.
    """

    // MARK: - §4.7 Standing footer disclaimer

    public static let standingFooterDisclaimer = "Ritham is not a medical provider and does not diagnose, treat, cure, or prevent any disease or condition. Suggestions are general and guideline-based, not individualized medical or nutrition prescriptions. If something here conflicts with advice from your doctor or dietitian, follow their advice."

    // MARK: - §1.2 Gate section framing / pass affirmation

    public static let gateSectionFraming = "These next questions are the kind a doctor's office typically asks before starting a new activity program. A \"yes\" doesn't stop you from using Ritham — it just means we'll ask you to check in with a professional before we turn on personalized suggestions in that area."

    public static let gatePassAffirmation = "Good to know — you're clear to move on."

    // MARK: - §1.3 Condition checklist intro

    public static let conditionChecklistIntro = "Do any of these apply to you? Select all that apply. Choosing \"None of the above\" clears any other selections."

    // MARK: - §1.4 SCOFF intro

    public static let scoffIntro = "These next questions are a standard, widely-used screening tool, not a diagnosis. We ask so we can turn off calorie- and weight-focused features that could be unhelpful, not to judge or label anything. Your individual answers are never shown to us as a score or a label — only used to turn certain features on or off."

    // MARK: - §1.3 Rationale lines

    public static let pregnancyRationale = "We ask this because pregnancy and the months after birth change what activity and eating guidance is safe to personalize — not for any other reason."

    public static let eatingDisorderRationale = "We ask so we can turn off calorie- and weight-focused features that could be unhelpful for some people — not to label or judge anything."

    // MARK: - §4.4 Persistent compact disclaimer tag (parameterised — D-12)

    /// §4.4's compact, always-visible tag. Per D-12, when more than one condition tag is
    /// matched the tag lists ALL matched conditions, not only the one whose gate is
    /// currently binding.
    public static func compactDisclaimerTag(conditions: [String]) -> String {
        let joined = conditions.joined(separator: ", ")
        return "Adjusted for **\(joined)** · General guidance, not medical advice · Edit in Settings"
    }

    // MARK: - §4.5 Expanded disclaimer (behind a tap/expand on the compact tag)

    /// §4.5's expanded disclaimer. Per D-12, when more than one condition tag is matched
    /// the tag lists ALL matched conditions, not only the one whose gate is currently
    /// binding.
    public static func expandedDisclaimer(conditions: [String]) -> String {
        let joined = conditions.joined(separator: ", ")
        return "This suggestion reflects a general, guideline-based adjustment for **\(joined)**. It is not personalized medical or nutrition advice, not a diagnosis, and not a substitute for your doctor or a registered dietitian — no clinician has reviewed it for you individually. Using Ritham doesn't create a doctor-patient or dietitian-client relationship. Always check with your healthcare provider before changing your exercise or eating habits, especially if your condition, medications, or symptoms have changed since you last answered these questions."
    }
}
