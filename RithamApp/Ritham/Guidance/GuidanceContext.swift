import Foundation
import SwiftData
import RithamCore

/// The shared, store-driven guidance loader every HEALTH-03/HEALTH-04 surface in this phase reads
/// from -- the inline banner on both session screens (Task 2) and the dedicated guidance screen
/// (Task 3) all construct one of these rather than each re-deriving a gate result of their own.
///
/// Copies `HealthProfileView`'s own store-driven reconstruction verbatim: reads the durably
/// persisted matched tags through `HealthDataStore.activeConditionTags(now:)`, then rebuilds a
/// `GateResolutionResult` via `GateEscalation.escalate(tags:answers:)` with an empty
/// `ScreeningAnswers` -- there is no `OnboardingFlow`-scoped `GateResolutionResult` still alive
/// once onboarding has ended, so this is the only way a post-onboarding screen can know what a
/// user is cleared for. See `HealthProfileView`'s own header comment for the one known gap this
/// re-derivation carries (§5 Rule 1, G2/G3 = Yes is answer-driven, not tag-driven, and cannot be
/// reconstructed from stored tags alone).
///
/// Reads tags only through `activeConditionTags`, never the stored profile's age: a tag's
/// lifecycle (expiry, the keep-applying-while-overdue rule, re-derivation at re-screen) already
/// lives entirely in the tag layer, and a second age-based derivation here would drift from it
/// (02-RESEARCH.md Pitfall 2, T-02-34).
@MainActor
@Observable
final class GuidanceContext {
    /// Every currently-applying condition tag, matching `activeConditionTags`' own
    /// active-or-expired-still-applied definition. Empty for an unscreened user -- see
    /// `isScreened` below for how that state is distinguished from a screened user whose
    /// checklist happened to match no condition (which is not actually possible: a screened user
    /// always carries at least `.noneOfTheAboveBaseline`).
    private(set) var matchedTags: Set<ConditionTag> = []

    /// `true` once a stored profile exists and its tags were read successfully. `false` for a
    /// user who has never completed the safety screening -- `activeConditionTags` throws
    /// `profileMissing` in that case, and this context treats that thrown error as "unscreened,"
    /// not as a crash or an empty-but-screened state.
    private(set) var isScreened = false

    private let store: HealthDataStore

    init(context: ModelContext) {
        self.store = HealthDataStore(context: context)
        load()
    }

    /// Re-reads the store. Called once at `init` and available to call again after a screening
    /// edit elsewhere in the app invalidates this context's snapshot.
    func load(now: Date = Date()) {
        guard let tags = try? store.activeConditionTags(now: now) else {
            matchedTags = []
            isScreened = false
            return
        }
        matchedTags = Set(tags)
        isScreened = true
    }

    /// The reconstructed gate result, handed to `ConditionDisclaimerTag` exactly as
    /// `HealthProfileView` hands it its own reconstruction. An empty `matchedTags` (unscreened,
    /// or -- impossible in practice, but not asserted against here -- a screened user with zero
    /// tags) resolves through `GateEscalation.escalate` to `.none` for both domains, same as any
    /// other empty-tag-set caller.
    var result: GateResolutionResult {
        GateResolutionResult(
            matchedTags: matchedTags,
            gates: GateEscalation.escalate(tags: matchedTags, answers: ScreeningAnswers()),
            interstitial: .none,
            requiresIndependentAllergenVerification:
                GateEscalation.requiresIndependentAllergenVerification(tags: matchedTags)
        )
    }

    /// The single most restrictive content permission across every matched tag, for `domain`.
    /// Delegates entirely to `GuidanceCatalog.resolvedPermission(for:domain:)`, which already
    /// returns `.none` for an empty tag list -- an unscreened caller therefore resolves to the
    /// most restrictive permission without this context special-casing the unscreened state
    /// itself (T-02-13).
    func permission(for domain: GuidanceDomain) -> ContentPermission {
        GuidanceCatalog.resolvedPermission(for: Array(matchedTags), domain: domain)
    }

    /// The single tag among `matchedTags` whose content permission for `domain` is most
    /// restrictive -- the tag whose adjustment text `AdjustedGuidanceBanner` should show, per
    /// HEALTH-06's "single most restrictive gate always wins" principle applied at the content
    /// layer. Ties (two tags sharing the same most-restrictive permission) break on `displayName`
    /// so the result is deterministic rather than dependent on `Set`'s unstable iteration order.
    /// `nil` for an empty tag set -- there is no tag to select from.
    func governingTag(for domain: GuidanceDomain) -> ConditionTag? {
        matchedTags.min { lhs, rhs in
            let lhsPermission = GuidanceCatalog.contentPermission(for: lhs, domain: domain)
            let rhsPermission = GuidanceCatalog.contentPermission(for: rhs, domain: domain)
            if lhsPermission != rhsPermission {
                return lhsPermission < rhsPermission
            }
            return lhs.displayName < rhs.displayName
        }
    }
}
