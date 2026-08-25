// The single public entry point the rest of the product asks "what is this user cleared for?"
// (docs/health-screening.md §1.2's branching, composed with `TagDerivation` and
// `GateEscalation`). HEALTH-01 forbids live AI-generated advice anywhere in this flow, and
// 01-RESEARCH.md's responsibility map assigns this logic to the client precisely so the app
// works offline immediately after screening.
//
// No future change may introduce a network call, a model call, or a non-deterministic input
// (e.g. `Date()`, `UUID()`, a random number) into `GateResolution.resolve` or anything it calls.
// This function's entire contract is: same answers in, same result out, every time, with no I/O.

/// The clearance interstitial variant shown after the gate section (§1.2), before the user
/// proceeds to the condition checklist. `.urgent` and `.routine` both lead to the checklist —
/// per §1.2, the interstitial never terminates the flow, it only changes which copy is shown
/// first.
public enum ClearanceInterstitial: Sendable, Equatable {
    case none
    case routine
    case urgent
}

/// The composed result of resolving a user's screening answers: every matched condition tag,
/// the per-domain clearance gates, which interstitial to show, and the standing allergen-
/// verification flag.
public struct GateResolutionResult: Sendable, Equatable {
    /// Every condition tag that matched, not pruned to the single tag governing the binding
    /// gate. Per D-12, when two or more tags apply but only the most restrictive gate binds,
    /// the disclaimer tag still lists all matched conditions — see `disclaimerConditionNames`.
    public var matchedTags: Set<ConditionTag>
    public var gates: DomainGates
    public var interstitial: ClearanceInterstitial
    public var requiresIndependentAllergenVerification: Bool

    /// Stored `false`, always. §5's third governing principle: a required-blocking gate
    /// restricts personalized suggestions in one domain, never app access as a whole — manual
    /// logging and generic, non-personalized information stay available throughout. No
    /// `GateResolutionResult` can ever be constructed with this `true`; it exists so a caller
    /// asking the wrong question ("can this user still use the app?") gets the right answer
    /// without having to derive it from `gates` themselves.
    public let blocksAppAccess = false

    public init(
        matchedTags: Set<ConditionTag>,
        gates: DomainGates,
        interstitial: ClearanceInterstitial,
        requiresIndependentAllergenVerification: Bool
    ) {
        self.matchedTags = matchedTags
        self.gates = gates
        self.interstitial = interstitial
        self.requiresIndependentAllergenVerification = requiresIndependentAllergenVerification
    }

    /// Every matched tag's `displayName`, sorted deterministically (alphabetically), ready for
    /// `ScreeningCopy.compactDisclaimerTag(conditions:)`. D-12: this is every matched condition,
    /// not just the one governing the binding gate.
    public var disclaimerConditionNames: [String] {
        matchedTags.map(\.displayName).sorted()
    }

    /// True only when `domain`'s gate is `.requiredBlocking`. Independent per domain — a tag
    /// can gate nutrition without gating workout, or vice versa.
    public func blocksPersonalization(in domain: GuidanceDomain) -> Bool {
        gates[domain] == .requiredBlocking
    }
}

/// Composes `TagDerivation` and `GateEscalation` into the one function the rest of the product
/// calls to find out what a user is cleared for.
public enum GateResolution {

    /// Pure and offline: no I/O, no network, no date dependency, no randomness. Calling this
    /// twice with identical `answers` and `ageDerivedTags` always returns an equal result.
    public static func resolve(
        answers: ScreeningAnswers,
        ageDerivedTags: Set<ConditionTag>
    ) -> GateResolutionResult {
        let tags = TagDerivation.deriveTags(from: answers, ageDerivedTags: ageDerivedTags)
        let gates = GateEscalation.escalate(tags: tags, answers: answers)
        return GateResolutionResult(
            matchedTags: tags,
            gates: gates,
            interstitial: interstitial(for: answers),
            requiresIndependentAllergenVerification:
                GateEscalation.requiresIndependentAllergenVerification(tags: tags)
        )
    }

    /// §1.2's branching: `.urgent` when G2 or G3 is yes, `.routine` when any other of G1-G7 is
    /// yes, `.none` when all seven are no. The user proceeds to the checklist after either
    /// interstitial (§1.2: "Either way, the user proceeds to the checklist afterward"), so this
    /// value never terminates the flow — it only selects which copy is shown first.
    private static func interstitial(for answers: ScreeningAnswers) -> ClearanceInterstitial {
        if answers.g2ChestPainOrBreathlessness == .yes
            || answers.g3DizzinessOrLossOfConsciousness == .yes {
            return .urgent
        }

        let anyGateYes = [
            answers.g1HeartConditionOrHighBP,
            answers.g2ChestPainOrBreathlessness,
            answers.g3DizzinessOrLossOfConsciousness,
            answers.g4OtherOngoingCondition,
            answers.g5MedicationOrPrescribedDiet,
            answers.g6BoneJointSoftTissueProblem,
            answers.g7MedicallySupervisedOnly,
        ].contains(.yes)

        return anyGateYes ? .routine : .none
    }
}
