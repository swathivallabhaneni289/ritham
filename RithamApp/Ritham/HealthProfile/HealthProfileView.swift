import SwiftUI
import SwiftData
import RithamCore

/// The health profile screen: the real, working home 01-UI-SPEC.md's empty-state copy already
/// describes, and the surface that gives D-11's transparency and D-12's multi-condition listing
/// somewhere to actually appear in this phase. `ConditionDisclaimerTag`, `RequiredBlockingMessageView`,
/// and `StandingFooterDisclaimer` are used here exactly as Phase 2's HEALTH-03/HEALTH-04
/// suggestion surfaces should reuse them later -- this comment records that intent so a later
/// phase composes these three components again rather than building a second set.
///
/// Deliberately store-driven, not `OnboardingFlow`-driven: this screen must be reachable from
/// Settings at any point after onboarding, long after the transient in-memory `OnboardingFlow`
/// object (scoped to a single onboarding pass) is gone. Its `GateResolutionResult` is
/// reconstructed from `HealthDataStore.conditionTagStatuses(now:)` -- the durably persisted
/// matched tags -- via `GateEscalation.escalate(tags:answers:)` with an empty `ScreeningAnswers`,
/// not from any raw answer state (none is persisted; see 01-11-SUMMARY.md and this plan's own
/// SUMMARY for the one known gap this re-derivation carries: §5 Rule 1, G2/G3 = Yes, is answer-
/// driven rather than tag-driven and cannot be reconstructed from stored tags alone).
///
/// Every confirmed 13+ user reaches this screen with identical access -- there is no parental-
/// approval or partial-gate state to special-case here (D-15); an empty profile means only that
/// the screening has not been completed yet.
struct HealthProfileView: View {
    /// Wired by whatever later screen presents this one (no `OnboardingStep`/`StepRegistry`
    /// entry exists for this screen yet -- it is a working component with a real surface, per
    /// this plan's objective, not yet threaded into app navigation). Defaults to a no-op so this
    /// view stays previewable on its own.
    var onStartScreening: () -> Void = {}

    @Environment(\.modelContext) private var modelContext
    @State private var statuses: [ConditionTagStatus] = []
    @State private var result: GateResolutionResult?
    @State private var clearancesNeedingReConfirmation: Set<ConditionTag> = []

    var body: some View {
        RithamScreen(surface: DecorativeSurface.flat) {
            if let result, !statuses.isEmpty {
                completeContent(result: result)
            } else {
                emptyState
            }
        }
        .onAppear(perform: load)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: RithamSpacing.md) {
            Text(OnboardingCopy.HealthProfile.emptyStateHeading)
                .font(RithamType.display)
                .foregroundStyle(RithamColor.paper)
                .fixedSize(horizontal: false, vertical: true)

            Text(OnboardingCopy.HealthProfile.emptyStateBody)
                .font(RithamType.body)
                .foregroundStyle(RithamColor.paper)
                .fixedSize(horizontal: false, vertical: true)

            PrimaryCTAButton(title: OnboardingCopy.HealthProfile.emptyStateCTA, action: onStartScreening)
        }
    }

    // MARK: - Complete state

    @ViewBuilder
    private func completeContent(result: GateResolutionResult) -> some View {
        VStack(alignment: .leading, spacing: RithamSpacing.lg) {
            ForEach(statuses.sorted(by: { $0.tag.displayName < $1.tag.displayName }), id: \.tag) { status in
                conditionRow(status)
            }
        }

        VStack(alignment: .leading, spacing: RithamSpacing.xl) {
            domainSection(.workout, result: result)
            domainSection(.nutrition, result: result)
        }

        StandingFooterDisclaimer()
    }

    /// One condition tag row. Per D-08, a tag past twelve months is still listed here and still
    /// applying -- rendered as "due for re-screen," never as inactive, greyed, or removed.
    /// Hiding or greying an overdue tag out would misrepresent the app's actual behaviour, which
    /// is to keep applying it until the user actually re-screens (T-01-104).
    private func conditionRow(_ status: ConditionTagStatus) -> some View {
        VStack(alignment: .leading, spacing: RithamSpacing.xs) {
            HStack(spacing: RithamSpacing.xs) {
                GlossaryTerm(term: "Condition tag")
                Text(status.tag.displayName)
                    .font(RithamType.body)
                    .foregroundStyle(RithamColor.paper)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if status.validity == .expiredStillApplied {
                Text("Due for re-screen — still applying until you re-screen")
                    .font(RithamType.label)
                    .foregroundStyle(RithamColor.hot)
            }

            professionalClearanceControl(for: status)
        }
    }

    /// §1.6: the "I've talked to a professional" toggle is not a permanent unlock -- it
    /// re-prompts at each re-screen point. `clearancesNeedingReConfirmation` is surfaced
    /// explicitly here rather than the clearance silently continuing to apply, and nothing in
    /// this control ever removes the underlying condition tag -- only the clearance date.
    @ViewBuilder
    private func professionalClearanceControl(for status: ConditionTagStatus) -> some View {
        if clearancesNeedingReConfirmation.contains(status.tag) {
            Text("Has anything changed since you last checked in about this?")
                .font(RithamType.label)
                .foregroundStyle(RithamColor.paper)
            SecondaryCTAButton(title: "Re-confirm cleared by a professional") {
                recordClearance(for: status.tag)
            }
        } else if status.professionalClearanceGrantedAt != nil {
            Text("Cleared by a professional")
                .font(RithamType.label)
                .foregroundStyle(RithamColor.paper)
        } else {
            SecondaryCTAButton(title: "I've talked to a professional about this") {
                recordClearance(for: status.tag)
            }
        }
    }

    /// Per-domain gate display. Where a domain resolves to required-blocking,
    /// `RequiredBlockingMessageView` takes that domain's place while the other domain and the
    /// rest of the screen stay fully usable -- §5's third governing principle made visible.
    /// `ConditionDisclaimerTag` attaches wherever the domain shows adjusted (non-`.none`) state.
    @ViewBuilder
    private func domainSection(_ domain: GuidanceDomain, result: GateResolutionResult) -> some View {
        VStack(alignment: .leading, spacing: RithamSpacing.sm) {
            HStack(spacing: RithamSpacing.xs) {
                GlossaryTerm(term: "Clearance gate")
                Text(domainTitle(domain))
                    .font(RithamType.heading)
                    .foregroundStyle(RithamColor.paper)
            }

            if result.blocksPersonalization(in: domain) {
                RequiredBlockingMessageView()
            } else {
                Text(gateDescription(result.gates[domain]))
                    .font(RithamType.body)
                    .foregroundStyle(RithamColor.paper)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if result.gates[domain] != .none {
                ConditionDisclaimerTag(result: result)
            }
        }
    }

    private func domainTitle(_ domain: GuidanceDomain) -> String {
        switch domain {
        case .workout: return "Workout"
        case .nutrition: return "Nutrition"
        }
    }

    private func gateDescription(_ gate: ClearanceGate) -> String {
        switch gate {
        case .none: return "Shown normally, personalized to you."
        case .recommended: return "Shown, with a note to check in with a professional first."
        case .requiredBlocking: return "Held back until you've checked in with a professional."
        }
    }

    /// Records today as the professional-clearance date for `tag`, then reloads so the row
    /// reflects it immediately. Never removes `tag` from `statuses` -- clearance is content
    /// about the tag, not a way to discharge it.
    private func recordClearance(for tag: ConditionTag) {
        let store = HealthDataStore(context: modelContext)
        try? store.recordProfessionalClearance(for: tag, at: Date())
        load()
    }

    // MARK: - Loading

    private func load() {
        let store = HealthDataStore(context: modelContext)
        let now = Date()
        guard let statuses = try? store.conditionTagStatuses(now: now) else {
            self.statuses = []
            self.result = nil
            return
        }

        self.statuses = statuses
        let tags = Set(statuses.map(\.tag))
        self.result = GateResolutionResult(
            matchedTags: tags,
            gates: GateEscalation.escalate(tags: tags, answers: ScreeningAnswers()),
            interstitial: .none,
            requiresIndependentAllergenVerification: GateEscalation.requiresIndependentAllergenVerification(tags: tags)
        )
        self.clearancesNeedingReConfirmation = Set((try? store.clearancesNeedingReConfirmation(now: now)) ?? [])
    }
}
