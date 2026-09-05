import SwiftUI
import RithamCore

/// The reusable embedded card HEALTH-03/HEALTH-04's adjusted-guidance surfaces all compose:
/// `CardioSessionView`/`StrengthSessionView` (Task 2, workout domain) and
/// `NutritionGuidanceSection` (Task 3, nutrition domain) each embed one of these rather than
/// building their own gate-aware rendering.
///
/// Every string this view shows comes from a `GuidanceCatalog` presentable accessor --
/// `WorkoutGuidanceCatalog.presentableAdjustment(for:)` or
/// `NutritionGuidanceCatalog.presentableGuidance(for:)` -- which resolves the content permission
/// internally before returning any text. This view never computes visibility from a
/// `ClearanceGate` value itself; it only ever reads the already-resolved `ContentPermission` from
/// `GuidanceContext` to decide *which branch* to render, never to decide whether personalized
/// text is safe to show -- that decision is the catalog accessor's alone (ASVS V4, T-02-01).
///
/// Always an embedded card, never a modal or full-screen cover: `RequiredBlockingMessageView`
/// takes the adjustment's place in a required-blocking domain while the rest of the hosting
/// screen -- the other domain, manual logging, navigation -- stays fully usable (§5's governing
/// principle, HEALTH-03/HEALTH-06).
struct AdjustedGuidanceBanner: View {
    let context: GuidanceContext
    let domain: GuidanceDomain

    private var permission: ContentPermission {
        context.permission(for: domain)
    }

    private var governingTag: ConditionTag? {
        context.governingTag(for: domain)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: RithamSpacing.sm) {
            personalizedContent
            streakSafetyNote

            if context.isScreened, !context.matchedTags.isEmpty {
                ConditionDisclaimerTag(result: context.result)
            }

            StandingFooterDisclaimer()
        }
        .padding(RithamSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: RithamSpacing.sm)
                .stroke(RithamColor.paper.opacity(0.3), lineWidth: 1)
        )
    }

    /// Either this domain's permission-checked adjustment/guidance text (plus, for workout, its
    /// contraindicated list), or `RequiredBlockingMessageView` in its place when the resolved
    /// permission is `.none` or there is no tag to govern (the unscreened state, per
    /// `GuidanceContext.governingTag(for:)`'s own contract).
    @ViewBuilder
    private var personalizedContent: some View {
        if let governingTag, permission != .none {
            switch domain {
            case .workout:
                Text(WorkoutGuidanceCatalog.presentableAdjustment(for: governingTag))
                    .font(RithamType.body)
                    .foregroundStyle(RithamColor.paper)
                    .fixedSize(horizontal: false, vertical: true)

                if let contraindicated = WorkoutGuidanceCatalog.contraindicated(for: governingTag) {
                    Text("Avoid: \(contraindicated)")
                        .font(RithamType.label)
                        .foregroundStyle(RithamColor.paper)
                        .fixedSize(horizontal: false, vertical: true)
                }
            case .nutrition:
                Text(NutritionGuidanceCatalog.presentableGuidance(for: governingTag))
                    .font(RithamType.body)
                    .foregroundStyle(RithamColor.paper)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else {
            // Either no governing tag exists at all (the unscreened state --
            // `GuidanceContext.governingTag(for:)` returns `nil` for an empty tag set, and
            // `GuidanceCatalog.resolvedPermission` already resolves an empty set to `.none`,
            // T-02-13) or a governing tag exists but its own permission is zero-content -- both
            // cases show the same referral message, never personalized content.
            RequiredBlockingMessageView()
        }
    }

    /// HEALTH-03's five never-triggers-streak-loss tags read as safe rest, never as a missed
    /// target -- surfaced independently of `permission`, since one of the five
    /// (`heartDiseaseRecentEventOrSymptomatic`) carries a zero-content workout permission and
    /// would otherwise lose this framing entirely behind `RequiredBlockingMessageView`.
    /// `neverTriggersStreakLoss` is a boolean classification flag, not personalized advice text,
    /// so reading it directly (rather than through a presentable text accessor, which does not
    /// exist for it) carries none of `adjustment(for:)`'s bypass risk.
    @ViewBuilder
    private var streakSafetyNote: some View {
        if domain == .workout, let governingTag, WorkoutGuidanceCatalog.neverTriggersStreakLoss(governingTag) {
            Text("A rest day or modified session here is expected. It never breaks your streak and is never counted as a miss.")
                .font(RithamType.label)
                .foregroundStyle(RithamColor.paper)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
