import SwiftUI
import RithamCore

// §1.0/§4.1: this block is shown once, in full, before the first screening question. HEALTH-05
// requires it at exactly this touchpoint. `RithamScreen`'s `bodyText` slot has no fixed-height
// frame and no truncation (`.fixedSize`), so a Phase 5 legal revision to this copy's length
// tolerates without redesign, per 01-UI-SPEC.md's LAUNCH-01 constraint.
//
// Live-review feedback (2026-09-01): this screen had no headline (an empty header straight into
// a wall of body text) and used `DecorativeSurface.flat`, leaving that header region visually
// empty rather than dropped from layout. Fixed by adding a headline and switching to
// `.boundedHeaderOnly` -- the same treatment the Privacy explainer already uses. This screen is
// not one of the nine screens `DecorativeSurface.flat`'s own doc comment enumerates (it collects
// no data itself; the gate section right after it does), so this does not touch that locked set.
// The body copy itself is untouched -- it is pending-legal-review text (LAUNCH-01) and must not
// be edited for a presentation concern.
//
// "Shown once" is tracked via `OnboardingAnswers.completedSteps` (already designed for exactly
// this purpose, per its own doc comment) rather than a new persisted `UserProfile` column -- the
// linear onboarding router only ever reaches `.screeningOpeningDisclaimer` once per pass in the
// first place, and a durable "already shown" flag on the profile would anticipate plan 01-17's
// edit-answer re-entry routing, which this plan does not own. Recording it in-session here is the
// minimal, correctly-scoped mechanism; 01-17 can read `completedSteps` if it needs to skip this
// screen on a section-only re-screen.
struct ScreeningOpeningDisclaimerView: View, OnboardingStepPresenting {
    static let step: OnboardingStep = .screeningOpeningDisclaimer

    static func makeView(flow: OnboardingFlow) -> AnyView {
        AnyView(ScreeningOpeningDisclaimerView(flow: flow))
    }

    let flow: OnboardingFlow

    var body: some View {
        RithamScreen(
            surface: DecorativeSurface.boundedHeaderOnly,
            headline: ScreeningCopy.openingDisclaimerHeadline,
            bodyText: ScreeningCopy.openingDisclaimer
        ) {
            // No dedicated CTA copy exists for this screen (01-UI-SPEC.md's Copywriting Contract
            // has no row for it) -- reusing the already-locked "Continue" string established by
            // `OnboardingCopy.Age.cta`, matching the pattern `CalibrationCompleteView` already
            // sets for this exact situation.
            PrimaryCTAButton(title: OnboardingCopy.Age.cta) {
                flow.answers.completedSteps.insert(.screeningOpeningDisclaimer)
                flow.advance(from: .screeningOpeningDisclaimer)
            }
        }
    }
}
