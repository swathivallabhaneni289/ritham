// CROSSGEN-05 forbids any age-based navigation fork: no separate under-18 "kid mode", no
// senior-mode screen, no parallel step hierarchy of any kind. There is exactly ONE step
// enum in this product, covering every screen for every user regardless of age. Do not
// introduce a second step-like enum, a nested variant, or an associated value carrying a
// "mode" — age changes *which case comes next* (see OnboardingRouter), never *which
// hierarchy the user is in*.
//
// `ageIneligible` is an ordinary case every user's enum contains. It is not a structural
// fork — it is simply unreachable for anyone who enters an age of 13 or older on their
// first try, which is a routing outcome (OnboardingRouter.nextStep), not a type-level
// difference. Per D-14, Ritham has a permanent 13+ floor with no tiered gated-consent flow
// of any kind: there is no case for a parent-approval step and no case for a partial-access
// notice shown between the floor and adulthood, not even as an unreachable one — those
// steps do not exist rather than existing-but-unused.
//
// Conforms to `Codable` so an interrupted onboarding can resume at the same step. The raw
// values are the persisted form — treat them as stable identifiers and do not rename them
// casually.

/// The single shared step vocabulary every onboarding user's flow is built from.
public enum OnboardingStep: String, CaseIterable, Sendable, Hashable, Codable {
    case welcome
    case explanationRegister
    case age
    case ageIneligible
    case dietaryPattern
    case privacyExplainer
    case calibrationIntro
    case calibrationSession
    case calibrationComplete
    case screeningOpeningDisclaimer
    case gateSection
    case clearanceInterstitial
    case conditionChecklist
    case severityFollowUps
    case scoffFollowUp
    case universalFollowUp
    case screeningComplete
    case home
}
