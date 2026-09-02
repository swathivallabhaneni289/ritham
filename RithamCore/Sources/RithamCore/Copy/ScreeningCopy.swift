// These strings are transcribed verbatim from docs/health-screening.md and
// 01-UI-SPEC.md's Copywriting Contract. They are pending LAUNCH-01 (counsel) review
// for the PAR-Q+-style gate wording and LAUNCH-02 (clinician) review for the SCOFF
// wording/scoring, per 01-UI-SPEC.md. They ship as-is for Phase 1 per the roadmap's
// own sequencing (Phase 5 gates the review, not Phase 1 build).
//
// Consumers must not impose fixed-height containers on these strings: a Phase 5
// revision to their length is expected, and the layout/interaction contract must
// tolerate string-length changes without redesign.
//
// No em dash and no en dash (the two Unicode dash characters, not a plain ASCII hyphen)
// appears anywhere in this file, comments included: this directory is the shipped string set,
// and a phase sign-off check greps it for a hard zero. Rewrite a sentence naturally (a comma,
// "and", a period splitting it in two, or parentheses) rather than reintroducing one here --
// this applies to the pending-review clinical wording too, since the dash rule is a house-style
// constraint, independent of LAUNCH-01/02's separate substance review.

/// Namespace for the verbatim disclaimer, legal, and framing copy used throughout the
/// health screening flow (§1.2-1.4 and §4.1-4.7 of docs/health-screening.md).
public enum ScreeningCopy {

    // MARK: - §4.1 Questionnaire opening disclaimer (shown once, before Question 1)

    /// Live-review feedback (2026-09-01): this screen had no headline at all, reading as an
    /// empty header followed straight into a wall of body text. New copy, not a re-transcription
    /// of locked wording -- 01-UI-SPEC.md's Copywriting Contract has no headline row for this
    /// screen (only "Body"), the same gap `OnboardingCopy.ScreeningComplete`'s headline already
    /// closed for its own screen. Kept deliberately plain and non-diagnostic, like that one.
    ///
    /// A first attempt, "About this health screening.", was itself flagged the same day as
    /// reading like a clinical section label rather than a natural lead-in to what's actually
    /// next (a few health questions) -- it named the screen instead of previewing the step ahead.
    /// This version previews the next step directly instead, matching the body's own opening
    /// sentence ("Ritham asks a few questions...") rather than restating it as a heading.
    public static let openingDisclaimerHeadline = "Just a few questions first."

    /// The emergency-instruction sentence in this string, `urgentClearanceInterstitial`, and
    /// `emergencyLine` was revised 2026-09-01 to drop the US-specific "911" carve-out entirely --
    /// Ritham ships to a global App Store audience, and naming one country's number read as
    /// US-centric even with the "or your local emergency number" fallback already present. All
    /// three occurrences say only "your local emergency number" now, everywhere. Like the rest of
    /// this file, this remains pending LAUNCH-01 legal review before Phase 5 -- this is a
    /// same-day product-feedback revision, not that review itself.
    public static let openingDisclaimer = """
    Ritham asks a few questions about your health so we can show general, guideline-based workout and food suggestions that fit you better, not to diagnose or treat anything. This is a short screening questionnaire, not a medical exam, and your answers aren't reviewed by a doctor or dietitian.

    If you have a health condition, are pregnant, are recovering from an injury or surgery, or take medication, please talk to your doctor or another qualified professional before starting or changing an exercise or eating routine. If you think you might be having a medical emergency right now, stop and call your local emergency number instead of continuing this questionnaire.

    Every suggestion Ritham gives you afterward is a general starting point you can edit or turn off, and you can update these answers anytime in Settings.
    """

    // MARK: - §4.2 Routine clearance interstitial (any Gate G1-G7 = Yes, without G2/G3)

    public static let routineClearanceInterstitial = """
    **Let's have you check in with a professional first.**

    Based on what you told us, we'd like you to talk with a doctor or a qualified exercise/nutrition professional before we turn on personalized workout and food suggestions. This isn't Ritham judging your fitness. It's just that a few of your answers are outside what a general screening questionnaire can safely personalize on its own.

    You can still use Ritham to log workouts and meals manually, and see general (non-personalized) guidance, in the meantime. Once you've checked in with a professional, come back to Settings and let us know, and we'll turn personalized suggestions back on.
    """

    public static let routineClearanceCTA = "Continue to the rest of the questions"

    // MARK: - §4.3 Urgent clearance interstitial (G2 or G3 = Yes)

    public static let urgentClearanceInterstitial = """
    **Before anything else: if you're currently experiencing chest pain, difficulty breathing, sudden severe dizziness, or think you may be having a medical emergency, stop and call your local emergency number right now. Don't wait to finish this questionnaire.**

    If that's not what's happening right now: based on your answers, please talk with a doctor before starting or changing an exercise routine. We'll hold off on personalized suggestions until you've done that.
    """

    public static let urgentClearanceCTA = "I understand, continue to the rest of the questions"

    // MARK: - §4.6 Required-blocking message

    public static let requiredBlockingMessage = """
    **We're holding off on personalized suggestions here.**

    Based on what you told us, this isn't something Ritham can safely tailor on its own. We'd like you to check with a doctor, registered dietitian, or other qualified professional first. You can still track your workouts and meals manually, and see general, non-personalized information.

    Once you've talked with a professional, come back to Settings to let us know, and we'll turn personalized suggestions back on for this area.
    """

    // MARK: - §4.7 Standing footer disclaimer

    public static let standingFooterDisclaimer = "Ritham is not a medical provider and does not diagnose, treat, cure, or prevent any disease or condition. Suggestions are general and guideline-based, not individualized medical or nutrition prescriptions. If something here conflicts with advice from your doctor or dietitian, follow their advice."

    // MARK: - §1.2 Gate section framing / pass affirmation

    /// Live-review feedback (2026-09-01): this screen had no headline, and the framing paragraph
    /// read as denser than it needed to (three separate sentences for one idea). New headline,
    /// not a re-transcription of locked wording -- 01-UI-SPEC.md's Copywriting Contract has no
    /// headline row for this screen (only "Body", same gap the opening disclaimer's headline
    /// closed the same day). Kept deliberately plain, matching that one.
    public static let gateSectionHeadline = "A few health basics."

    /// Tightened from three sentences to two, same substance (doctor's-office framing, the
    /// explicit "doesn't stop you from using Ritham" reassurance, and what a "yes" actually
    /// triggers). Still pending LAUNCH-01 legal review, like the rest of this section -- a
    /// same-day product-feedback revision, not that review itself.
    public static let gateSectionFraming = "These are the kind of questions a doctor's office asks before starting something new. A \"yes\" answer here doesn't stop you from using Ritham, it just means checking in with a professional before we turn on personalized suggestions for that one area."

    public static let gatePassAffirmation = "Good to know, you're clear to move on."

    // MARK: - §1.3 Condition checklist intro

    public static let conditionChecklistIntro = "Do any of these apply to you? Select all that apply. Choosing \"None of the above\" clears any other selections."

    // MARK: - §1.4 SCOFF intro

    public static let scoffIntro = "These next questions are a standard, widely-used screening tool, not a diagnosis. We ask so we can turn off calorie- and weight-focused features that could be unhelpful, not to judge or label anything. Your individual answers are never shown to us as a score or a label, only used to turn certain features on or off."

    // MARK: - §1.3 Rationale lines

    public static let pregnancyRationale = "We ask this because pregnancy and the months after birth change what activity and eating guidance is safe to personalize, not for any other reason."

    public static let eatingDisorderRationale = "We ask so we can turn off calorie- and weight-focused features that could be unhelpful for some people, not to label or judge anything."

    // MARK: - §4.4 Persistent compact disclaimer tag (parameterised, D-12)

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
        return "This suggestion reflects a general, guideline-based adjustment for **\(joined)**. It is not personalized medical or nutrition advice, not a diagnosis, and not a substitute for your doctor or a registered dietitian. No clinician has reviewed it for you individually. Using Ritham doesn't create a doctor-patient or dietitian-client relationship. Always check with your healthcare provider before changing your exercise or eating habits, especially if your condition, medications, or symptoms have changed since you last answered these questions."
    }

    // MARK: - §5's closing section: the unconditional emergency line
    //
    // Until 2026-09-01 this section held a standalone `emergencyLine` constant, rendered at both
    // the gate section and (duplicated inline) the urgent clearance interstitial. The gate
    // section's callout was removed that day (product decision, live-review feedback -- see
    // `GateEscalation.showsEmergencyLine`'s doc comment for the full record), leaving the
    // constant with no remaining caller, so it was deleted rather than left as dead, silently
    // stale copy in a file the Phase 5 legal review will read closely. The rule's one surviving
    // instance is the bolded opening sentence of `urgentClearanceInterstitial` below (§4.3).

    // MARK: - §1.2 Gate questions (G1-G7) and their immediate MED-1/MED-2 follow-ups

    /// Plan 01-16's screen-building scope: docs/health-screening.md §1.2's seven gate questions
    /// verbatim, plus G3's parenthetical clarification and the two immediate MED-1/MED-2
    /// follow-ups revealed when G5 is "Yes". `ScreeningCopy.swift`'s original scope (plan 01-01)
    /// covered only the section-level framing/pass copy; the individual question prompts had no
    /// addressable home until this plan needed to render them, and centralizing them here (with
    /// everything else in `docs/health-screening.md` §1) keeps the whole PAR-Q+-style word set in
    /// the one file LAUNCH-01's counsel review will actually read.
    public enum Gate {
        public static let g1 = "Has a doctor ever told you that you have a heart condition or high blood pressure?"
        public static let g2 = "Do you feel chest pain or significant shortness of breath at rest, during your daily activities, or during exercise?"
        public static let g3 = "In the past 12 months, have you lost your balance because of dizziness, or lost consciousness?"
        public static let g3Clarification = "This doesn't include brief lightheadedness from breathing hard during a tough workout."
        public static let g4 = "Have you been diagnosed with any other ongoing medical condition not covered above (for example diabetes, kidney disease, cancer, an eating disorder, or another chronic condition)?"
        public static let g5 = "Are you currently taking a prescription medication for an ongoing health condition, or following a specific meal plan or nutrition targets given to you by a doctor or dietitian?"
        public static let g6 = "Do you currently have, or have you had in the last 12 months, a bone, joint, or soft-tissue problem that gets worse with physical activity?"
        public static let g7 = "Has a doctor ever told you that you should only do physical activity that is medically supervised?"
        public static let med1 = "Does this include a medication for your heart or blood pressure, such as a beta-blocker?"
        public static let med2 = "Is this a specific meal plan or nutrition targets from a doctor or dietitian (not just general advice)?"
    }

    // MARK: - §1.4 Severity/context follow-up questions, shown only for selected categories

    /// Verbatim §1.4 follow-up prompts and, where a follow-up's option list is not a plain
    /// Yes/No/Not-sure, its option labels too (the blood-pressure-control, surgical-clearance,
    /// and postpartum-weeks answer sets are themselves clinically-reviewable wording, same as
    /// the questions).
    public enum FollowUp {
        public static let cv1 = "In the last 6 weeks, have you had a heart attack, heart surgery, or a cardiac procedure (such as a stent, ablation, or pacemaker placement)?"
        public static let cv2 = "How would you describe your blood pressure right now?"
        public static let cv2OptionWellControlled = "Well-controlled with treatment"
        public static let cv2OptionNotSureOrNotChecked = "Not sure, or I haven't checked recently"
        public static let cv2OptionDoctorSaysHigh = "My doctor has told me it's high or not well-controlled"
        public static let cv2b = "Is your heart rhythm currently well-controlled with treatment?"
        public static let m1 = "Do you take insulin, or a medication that can cause low blood sugar (such as a sulfonylurea)?"
        public static let m2 = "Have you been told you have diabetes-related eye disease, nerve damage in your feet, or a current foot wound?"
        public static let msk1 = "Is this currently flaring up, or has it gotten noticeably worse in the last 2 weeks?"
        public static let msk2 = "Has your surgeon or physical therapist cleared you for regular exercise?"
        public static let msk2OptionFullyCleared = "Yes, fully cleared"
        public static let msk2OptionStillInRecoveryNotCleared = "Still in recovery, not yet cleared"
        public static let msk2OptionNotApplicable = "Not applicable"
        public static let pg1 = "Has your doctor told you about any pregnancy complications (for example high blood pressure, a placenta condition, preterm labor, bleeding, or a heart or lung condition)?"
        public static let pp1 = "Did you have a C-section, or were there any complications with your delivery?"
        public static let pp2 = "How many weeks postpartum are you?"
        public static let pp2OptionUnderSix = "Under 6 weeks"
        public static let pp2OptionSixToTwelve = "6 to 12 weeks"
        public static let pp2OptionOverTwelve = "Over 12 weeks"
        public static let kr1 = "Are you currently on dialysis?"
        public static let kr2 = "Has your doctor or dietitian given you specific limits on things like protein, potassium, phosphorus, or fluids?"
        public static let fa1 = "Is any of your allergies severe or life-threatening, for example could it cause anaphylaxis, or have you been prescribed an epinephrine auto-injector (like an EpiPen)?"
        public static let os1 = "Is this a new diagnosis, or a change in treatment, within the last 3 months?"
    }

    // MARK: - §1.4 Eating-disorder-history follow-up (SCOFF, ED-1 through ED-5)

    /// The five SCOFF questions verbatim. §1.5 forbids surfacing the computed score or a label:
    /// these five prompts are the entire user-visible content of the SCOFF screen besides
    /// `scoffIntro`; nothing here computes or names a result.
    public enum EatingPattern {
        public static let ed1 = "Do you make yourself sick because you feel uncomfortably full?"
        public static let ed2 = "Do you worry you have lost control over how much you eat?"
        public static let ed3 = "Have you recently lost more than about 14 lb (6.4 kg) in a 3-month period?"
        public static let ed4 = "Do you believe yourself to be fat when others say you are too thin?"
        public static let ed5 = "Would you say that food dominates your life?"
    }

    // MARK: - §1.4 Universal follow-up (U-1, shown to every user regardless of selection)

    // Live-review feedback (2026-09-01): the original wording asked "are you 65 or older, or
    // returning to exercise after being inactive for the last 3 months or more" as one yes/no --
    // two unrelated facts a user cannot answer with a single bit (a 70-year-old who has stayed
    // active the whole time, or a 30-year-old just back from a 3-month break, both have a real
    // "yes" and a real "no" buried in that one question). The 65-or-older half was always
    // redundant anyway: `ConditionTag.ageDerivedTags(forAge:)` already derives the identical
    // `.age65PlusOrDeconditioned` tag straight from Q0's age answer, unconditionally, before this
    // question is ever shown (see `TagDerivation`'s own comment). Asking it again here added
    // nothing but the compound-question bug. This now asks only the one fact nothing else
    // captures: recent inactivity.
    public static let universalFollowUp = "One more thing: are you returning to exercise after being inactive for the last 3 months or more?"
}
