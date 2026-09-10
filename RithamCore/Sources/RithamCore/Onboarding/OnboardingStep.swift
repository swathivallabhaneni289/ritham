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
//
// Phase 2's eight surfaces (`cardioActivityPicker` through `preAssessment` below) are ordinary
// members of this same enum for the same CROSSGEN-05 reason as the paragraph above: exactly one
// step vocabulary and one navigation container for every user regardless of age. They are
// reached by explicit user choice from the interim hub (`.home`'s registered screen,
// `OnboardingFlow.open(_:)`), never by `OnboardingRouter` advancing into them — which is why the
// router treats every one of them as terminal, exactly like `.home` itself.
//
// Phase 3's new surfaces (`momentum`, `sleepCheckIn`, `movementSnapshot` below) are ordinary
// members of this same enum for the identical structural reason:
// exactly one step vocabulary and one navigation container for every user regardless of age.
// Like Phase 2's surfaces, they are reached by explicit user choice from the interim hub rather
// than by `OnboardingRouter` advancing into them, which is why the router treats them as terminal
// exactly like `.home` and Phase 2's surfaces.
//
// Phase 4.1's `signInWithApple` (below) is an ordinary member of this same enum for the same
// CROSSGEN-05 reason: this phase's social surfaces are reachable by explicit user choice from the
// dashboard, not by the router advancing into them, which is why the router treats this case as
// terminal too. ACCOUNT-01 requires that an account is created only the first time a user touches
// a social feature -- never mandatory, never reached during onboarding, never required for core
// tracking -- so this case has no place anywhere in `OnboardingRouter`'s `.welcome`-to-`.home`
// path, exactly like Phase 2 and Phase 3's own hub-reachable surfaces above.
//
// `privacyZones` (below, plan 04.1-07) is reached only from `SettingsView`'s own sheet
// presentation, never from `OnboardingRouter` or `OnboardingFlow.open(_:)` -- it exists as a step
// case solely so `StepRegistry` has a registry key to hang `PrivacyZonesView`'s registration on
// (`StepRegistry.unregisteredSteps` requires one for every case), the identical "registered for
// the registry, reached by a different path" shape `signInWithApple` above already established.
//
// `friendsList` and `addFriend` (below, plan 04.1-09) are ordinary members of this same enum for
// the identical CROSSGEN-05 reason as every other Phase 4.1 social surface: reached only by
// explicit user choice from the dashboard's signed-in social section (`friendsList`) or from
// that screen's own connect-a-friend entry point (`addFriend`), never by `OnboardingRouter`
// advancing into them -- terminal exactly like `signInWithApple`.

/// The single shared step vocabulary every onboarding user's flow is built from.
public enum OnboardingStep: String, CaseIterable, Sendable, Hashable, Codable {
    case welcome
    case age
    case ageIneligible
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
    case cardioActivityPicker
    case cardioSession
    case cardioHistory
    case strengthSession
    case strengthHistory
    case guidance
    case recommendations
    case preAssessment
    case momentum
    case sleepCheckIn
    case movementSnapshot
    case signInWithApple
    case privacyZones
    case friendsList
    case addFriend
}
