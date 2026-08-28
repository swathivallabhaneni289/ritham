import Testing
import RithamCore

// Asserts against `GateResolutionResult` and `ScreeningCopy` directly -- the data `Disclaimers/`
// renders -- rather than by rendering any view, per this plan's own instruction. This is the
// same "assert at the data level" approach `ScreeningFlowTests`/`HealthDataStoreTests` already
// use for their own view-adjacent behavior.
@Suite("DisclaimerTagTests")
struct DisclaimerTagTests {

    private func makeResult(
        matchedTags: Set<ConditionTag>,
        gates: DomainGates = DomainGates(workout: .none, nutrition: .none)
    ) -> GateResolutionResult {
        GateResolutionResult(
            matchedTags: matchedTags,
            gates: gates,
            interstitial: .none,
            requiresIndependentAllergenVerification: false
        )
    }

    @Test("a two-tag result where only one gate binds names both matched conditions, not only the governing one (D-12)")
    func twoTagResultNamesBothConditions() {
        // Osteoarthritis alone never blocks anything on its own; kidney disease is the tag
        // whose gate actually binds here -- the tag must still name both, per D-12.
        let result = makeResult(
            matchedTags: [.osteoarthritis, .kidneyDiseaseOrDialysis],
            gates: DomainGates(workout: .requiredBlocking, nutrition: .requiredBlocking)
        )

        let tagText = ScreeningCopy.compactDisclaimerTag(conditions: result.disclaimerConditionNames)
        #expect(tagText.contains(ConditionTag.osteoarthritis.displayName))
        #expect(tagText.contains(ConditionTag.kidneyDiseaseOrDialysis.displayName))
    }

    @Test("a single-tag result names that one condition")
    func singleTagResultNamesOneCondition() {
        let result = makeResult(matchedTags: [.hypertensionManaged])

        let tagText = ScreeningCopy.compactDisclaimerTag(conditions: result.disclaimerConditionNames)
        #expect(tagText.contains(ConditionTag.hypertensionManaged.displayName))
    }

    @Test("disclaimerConditionNames is stable across repeated calls -- the tag never reorders between renders")
    func disclaimerConditionNamesIsStableAcrossRepeatedCalls() {
        let result = makeResult(matchedTags: [
            .osteoarthritis, .kidneyDiseaseOrDialysis, .severeFoodAllergy, .prediabetes,
        ])

        let first = result.disclaimerConditionNames
        let second = result.disclaimerConditionNames
        let third = result.disclaimerConditionNames
        #expect(first == second)
        #expect(second == third)
        // Sorted, not insertion-order-dependent (matchedTags is a Set, which has no stable
        // iteration order of its own) -- disclaimerConditionNames must not merely be
        // "consistent by luck" for one particular Set layout.
        #expect(first == first.sorted())
    }

    @Test("the expanded disclaimer names every matched condition and carries the not-a-diagnosis phrasing")
    func expandedDisclaimerContainsConditionsAndNotADiagnosisPhrasing() {
        let result = makeResult(matchedTags: [.osteoarthritis, .kidneyDiseaseOrDialysis])

        let expanded = ScreeningCopy.expandedDisclaimer(conditions: result.disclaimerConditionNames)
        #expect(expanded.contains(ConditionTag.osteoarthritis.displayName))
        #expect(expanded.contains(ConditionTag.kidneyDiseaseOrDialysis.displayName))
        #expect(expanded.contains("not a diagnosis"))
    }

    @Test("blocksPersonalization is true for a required-blocking domain while blocksAppAccess stays false -- the invariant RequiredBlockingMessageView's non-covering presentation depends on")
    func blocksPersonalizationTrueBlocksAppAccessFalse() {
        let result = makeResult(
            matchedTags: [.kidneyDiseaseOrDialysis],
            gates: DomainGates(workout: .requiredBlocking, nutrition: .requiredBlocking)
        )

        #expect(result.blocksPersonalization(in: .workout))
        #expect(result.blocksPersonalization(in: .nutrition))
        #expect(result.blocksAppAccess == false)
    }

    @Test("a domain not raised to required-blocking is not reported as blocked")
    func nonBlockingDomainIsNotReportedAsBlocked() {
        let result = makeResult(
            matchedTags: [.hypertensionManaged],
            gates: DomainGates(workout: .recommended, nutrition: .recommended)
        )

        #expect(result.blocksPersonalization(in: .workout) == false)
        #expect(result.blocksPersonalization(in: .nutrition) == false)
    }
}
