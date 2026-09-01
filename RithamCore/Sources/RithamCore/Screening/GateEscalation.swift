// The sixteen numbered escalation triggers and two always-on prohibitions from
// docs/health-screening.md §5, transcribed against the per-tag Clearance Gate columns of §2
// (workout) and §3 (nutrition). §5's second governing principle — "gates are never averaged,
// blended, or softened" — is enforced structurally: every escalation below folds a candidate
// gate in with `ClearanceGate.mostRestrictive`, which is a one-way (never-lowering) operation
// by construction (see ClearanceGate.swift), so there is no code path here that can produce a
// laxer gate than any single contributing tag or rule would alone.

/// The sixteen §5 escalation rules, the per-tag base gates they escalate from, and the two
/// always-on prohibitions that are standing product-wide facts rather than gate states.
public enum GateEscalation {

    /// The base workout (§2) and nutrition (§3) Clearance Gate for a single tag, read
    /// independently from each table's own Clearance Gate column — these genuinely differ per
    /// tag (e.g. `under18Minor` is workout `.none` / nutrition `.requiredBlocking`), so no
    /// case below reuses one value for both domains.
    public static func baseGates(for tag: ConditionTag) -> DomainGates {
        switch tag {
        case .under18Minor:
            // §2: no exercise-specific restriction from age alone. §3: required-blocking for
            // any weight-management/calorie/portion feature, per AAP guidance against dieting
            // for minors.
            return DomainGates(workout: .none, nutrition: .requiredBlocking)
        case .age65PlusOrDeconditioned:
            // §2: progression pace is the adjustment, not a block. §3: no nutrition-specific
            // rule from this framework.
            return DomainGates(workout: .none, nutrition: .none)
        case .hypertensionManaged:
            return DomainGates(workout: .recommended, nutrition: .recommended)
        case .hypertensionUncontrolledOrUnsure:
            // §3's row is "required-blocking (for personalized quantities specifically)" — the
            // three-level gate has no narrower state than requiredBlocking to express "no
            // quantity, but generic education still allowed"; that nuance is content-layer,
            // not gate-level, so nutrition is requiredBlocking here.
            return DomainGates(workout: .requiredBlocking, nutrition: .requiredBlocking)
        case .heartDiseaseStable:
            return DomainGates(workout: .recommended, nutrition: .recommended)
        case .heartDiseaseRecentEventOrSymptomatic:
            return DomainGates(workout: .requiredBlocking, nutrition: .requiredBlocking)
        case .arrhythmiaStable:
            // §3: "no arrhythmia-specific nutrition rule... unless combined with Hypertension
            // or Heart Disease" — the base gate for the arrhythmia tag alone is none; a
            // co-occurring Hypertension/Heart-Disease tag supplies its own nutrition gate,
            // and `escalate`'s mostRestrictive-across-tags fold already combines them.
            return DomainGates(workout: .recommended, nutrition: .none)
        case .arrhythmiaUncontrolledOrUnsure:
            return DomainGates(workout: .requiredBlocking, nutrition: .none)
        case .rateLimitingHeartOrBPMedication:
            // §2: "none (adjusts method, doesn't itself gate)". No §3 row exists for this
            // modifier — it changes how HR-based intensity is presented, not a nutrition
            // concern.
            return DomainGates(workout: .none, nutrition: .none)
        case .diabetesOnHypoglycemiaRiskMedication:
            // §3's diabetes row applies to "any medication status".
            return DomainGates(workout: .recommended, nutrition: .recommended)
        case .diabetesNotOnHypoglycemiaRiskMedication:
            return DomainGates(workout: .none, nutrition: .recommended)
        case .prediabetes:
            return DomainGates(workout: .none, nutrition: .none)
        case .diabetesRetinopathyOrFootComplication:
            // §3: "same as underlying Diabetes row" (recommended); §2's own row for this
            // modifier is recommended, not the full block §5 rule 6's prose might suggest —
            // the vigorous/weight-bearing-specific restriction is contraindication content the
            // gate level doesn't separately express.
            return DomainGates(workout: .recommended, nutrition: .recommended)
        case .osteoarthritis:
            return DomainGates(workout: .recommended, nutrition: .none)
        case .osteoporosisOrOsteopenia:
            return DomainGates(workout: .recommended, nutrition: .none)
        case .chronicLowBackPain:
            return DomainGates(workout: .recommended, nutrition: .none)
        case .priorInjuryOrSurgeryNotCleared:
            return DomainGates(workout: .requiredBlocking, nutrition: .none)
        case .priorInjuryOrSurgeryCleared:
            return DomainGates(workout: .recommended, nutrition: .none)
        case .musculoskeletalFlare:
            return DomainGates(workout: .recommended, nutrition: .none)
        case .pregnancyUncomplicated:
            // §3: required-blocking for any calorie/macro/weight-loss quantity, absolute,
            // independent of complication status (§5 rule 7).
            return DomainGates(workout: .recommended, nutrition: .requiredBlocking)
        case .pregnancyComplicatedOrUnsure:
            return DomainGates(workout: .requiredBlocking, nutrition: .requiredBlocking)
        case .postpartumUncomplicated:
            // §3: required-blocking specifically for the weight-loss goal-setting feature;
            // general educational content is shown normally — again a content-layer nuance
            // the three-level gate doesn't separately express, so the Clearance Gate column
            // value (requiredBlocking) is what's encoded here.
            return DomainGates(workout: .recommended, nutrition: .requiredBlocking)
        case .postpartumCSectionOrComplications:
            return DomainGates(workout: .requiredBlocking, nutrition: .requiredBlocking)
        case .kidneyDiseaseOrDialysis:
            return DomainGates(workout: .requiredBlocking, nutrition: .requiredBlocking)
        case .eatingDisorderPositiveScreen:
            return DomainGates(workout: .requiredBlocking, nutrition: .requiredBlocking)
        case .eatingDisorderSelfReportedNegativeScreen:
            return DomainGates(workout: .recommended, nutrition: .recommended)
        case .severeFoodAllergy:
            return DomainGates(workout: .none, nutrition: .recommended)
        case .nonSevereFoodAllergy:
            return DomainGates(workout: .none, nutrition: .none)
        case .otherSeriousConditionOrActiveCancerTreatment:
            return DomainGates(workout: .requiredBlocking, nutrition: .requiredBlocking)
        case .clinicianPrescribedDietOrMealPlan:
            return DomainGates(workout: .none, nutrition: .recommended)
        case .noneOfTheAboveBaseline:
            return DomainGates(workout: .none, nutrition: .none)
        }
    }

    /// §5's second governing principle: the single most restrictive gate across every
    /// applicable tag's base gate, independently per domain — never averaged, blended, or
    /// softened. The sixteen numbered §5 triggers are then applied as additional escalations
    /// that can only raise a gate, never lower it: each computes a candidate gate and folds it
    /// in with `ClearanceGate.mostRestrictive`, so the direction is structurally one-way.
    public static func escalate(tags: Set<ConditionTag>, answers: ScreeningAnswers) -> DomainGates {
        var workout = ClearanceGate.mostRestrictive(tags.map { baseGates(for: $0).workout })
        var nutrition = ClearanceGate.mostRestrictive(tags.map { baseGates(for: $0).nutrition })

        func raiseWorkout(_ candidate: ClearanceGate) {
            workout = ClearanceGate.mostRestrictive([workout, candidate])
        }
        func raiseNutrition(_ candidate: ClearanceGate) {
            nutrition = ClearanceGate.mostRestrictive([nutrition, candidate])
        }
        func raiseBoth(_ candidate: ClearanceGate) {
            raiseWorkout(candidate)
            raiseNutrition(candidate)
        }

        // Rule 1: G2 or G3 = Yes -> both domains required-blocking, independent of any tag —
        // this is answer-driven, not tag-driven, which is why `escalate` takes `answers`.
        if answers.g2ChestPainOrBreathlessness == .yes
            || answers.g3DizzinessOrLossOfConsciousness == .yes {
            raiseBoth(.requiredBlocking)
        }

        // Rule 2: any Cardiovascular tag + CV-1 = Yes -> Heart Disease — Recent Event /
        // Symptomatic, required-blocking, both domains. Folded explicitly even though the base
        // gate already carries this, so a future base-gate edit can't silently unblock it.
        if tags.contains(.heartDiseaseRecentEventOrSymptomatic) {
            raiseBoth(.requiredBlocking)
        }

        // Rule 3: "High blood pressure" + CV-2 = doctor-says-high OR not-sure -> Hypertension —
        // Uncontrolled / Unsure, required-blocking for workout intensity; nutrition holds at
        // required-blocking for personalized quantities (general DASH education can still show
        // at the content layer, which the gate doesn't separately express).
        if tags.contains(.hypertensionUncontrolledOrUnsure) {
            raiseWorkout(.requiredBlocking)
            raiseNutrition(.requiredBlocking)
        }

        // Rule 4: "Irregular heartbeat" + CV-2b = No OR Not sure -> Arrhythmia — Uncontrolled /
        // Unsure, required-blocking, workout domain.
        if tags.contains(.arrhythmiaUncontrolledOrUnsure) {
            raiseWorkout(.requiredBlocking)
        }

        // Rule 5: any Metabolic tag (not Prediabetes alone) + M-1 = Yes -> a standing
        // glucose-check-before-exercising reminder at a recommended gate, not required-blocking.
        if tags.contains(.diabetesOnHypoglycemiaRiskMedication) {
            raiseWorkout(.recommended)
        }

        // Rule 6: any Metabolic tag + M-2 = Yes -> Diabetes — Retinopathy / Foot Complication
        // Flagged, required-blocking for vigorous/resistance/high-impact/weight-bearing
        // suggestions specifically (not a full personalization block) — §2's Clearance Gate
        // column for this row is `recommended`, which is what's raised here.
        if tags.contains(.diabetesRetinopathyOrFootComplication) {
            raiseWorkout(.recommended)
        }

        // Rule 7: "Currently pregnant" (regardless of PG-1) -> nutrition required-blocking on
        // any calorie/macro/weight-loss quantity or goal-setting, absolute, independent of
        // complication status. Folded explicitly for both pregnancy tags so a future §3 edit
        // can't silently unblock it.
        if tags.contains(.pregnancyUncomplicated) || tags.contains(.pregnancyComplicatedOrUnsure) {
            raiseNutrition(.requiredBlocking)
        }

        // Rule 8: "Currently pregnant" + PG-1 = Yes or Not sure -> Pregnancy — Complicated /
        // Unsure, required-blocking across both domains, full referral to OB.
        if tags.contains(.pregnancyComplicatedOrUnsure) {
            raiseBoth(.requiredBlocking)
        }

        // Rule 9: "Postpartum" + PP-1 = Yes -> Postpartum — C-Section / Complications,
        // required-blocking, workout domain, until explicit clearance is confirmed.
        if tags.contains(.postpartumCSectionOrComplications) {
            raiseWorkout(.requiredBlocking)
        }

        // Rule 10: any Kidney/Renal box checked, regardless of any follow-up -> required-
        // blocking, both domains, always — this tag alone is sufficient.
        if tags.contains(.kidneyDiseaseOrDialysis) {
            raiseBoth(.requiredBlocking)
        }

        // Rule 11: SCOFF score >= 2 "Yes" -> Eating Disorder History — Positive Screen,
        // required-blocking on all nutrition quantity features; workout suggestions shift to
        // non-quantified, non-compensatory framing, which §2's Clearance Gate column for this
        // row also places at required-blocking.
        if tags.contains(.eatingDisorderPositiveScreen) {
            raiseBoth(.requiredBlocking)
        }

        // Rule 12: any Musculoskeletal tag + MSK-2 = "Still in recovery, not yet cleared" ->
        // Prior Injury / Surgery — Not Yet Cleared, required-blocking for loading/progression
        // in the affected area specifically (not a full-body block); general low-impact
        // suggestions for unaffected areas remain available at the content layer.
        if tags.contains(.priorInjuryOrSurgeryNotCleared) {
            raiseWorkout(.requiredBlocking)
        }

        // Rule 13: any "Other Serious Condition" box checked, regardless of OS-1 ->
        // required-blocking, both domains, always.
        if tags.contains(.otherSeriousConditionOrActiveCancerTreatment) {
            raiseBoth(.requiredBlocking)
        }

        // Rules 14/15 (weight-loss goal feature) and 16 (allergen verification flag) are not
        // combination-tag escalations resolved here — they're evaluated at goal-setting time
        // and food-suggestion time respectively, via `weightLossFeatureGate` and
        // `requiresIndependentAllergenVerification` below.

        return DomainGates(workout: workout, nutrition: nutrition)
    }

    /// §5 rules 14 and 15: a weight-loss goal set anywhere in the app (not just at intake).
    /// Phase 2 calls this at goal-setting time; it lives here so all escalation logic stays in
    /// one module. Returns `.requiredBlocking` when the tags contain `.under18Minor` or
    /// `.eatingDisorderPositiveScreen` (rule 14's under-18 case and the ED-screen equivalence
    /// both named explicitly), or when `goalBelowHealthyBMIFloor` is true (rule 15's
    /// below-healthy-BMI-floor goal, treated as a red flag equivalent to a positive ED screen
    /// even with no Eating Disorder History reported). Otherwise `.none` — this function has
    /// no opinion on any other tag; the base/escalated `DomainGates` already govern those.
    public static func weightLossFeatureGate(
        tags: Set<ConditionTag>,
        goalBelowHealthyBMIFloor: Bool
    ) -> ClearanceGate {
        if tags.contains(.under18Minor)
            || tags.contains(.eatingDisorderPositiveScreen)
            || goalBelowHealthyBMIFloor {
            return .requiredBlocking
        }
        return .none
    }

    /// §5 rule 16: not a personalization block, but a standing, non-removable "verify
    /// independently before eating" flag attached to every food suggestion touching a flagged
    /// allergen category, every time, with no expiry.
    public static func requiresIndependentAllergenVerification(tags: Set<ConditionTag>) -> Bool {
        tags.contains(.severeFoodAllergy)
    }

    /// §5's closing section, first always-on rule: Ritham never generates an insulin-dosing or
    /// medication-adjustment suggestion, for any user, under any tag or combination of tags.
    /// This is a product-wide prohibition, not a gate state any user can be in or clear — no
    /// clearance toggle can unlock it. It exists as a standing fact for callers to assert
    /// against (e.g. in a guidance-generation test), not as an input to `escalate`.
    public static let neverGeneratesMedicationDosingGuidance = true

    /// The screening-flow sections this phase renders, for `showsEmergencyLine(for:)` below.
    public enum ScreeningSection: Sendable, CaseIterable {
        case openingDisclaimer
        case gate
        case conditionChecklist
        case severityFollowUps
        case routineInterstitial
        case urgentInterstitial
    }

    /// §5's closing section, second always-on rule: the emergency line is shown in the urgent
    /// interstitial, and it is never conditional on a specific answer combination for that
    /// section -- so this always returns the same value for it regardless of any tag, gate, or
    /// answer state.
    ///
    /// Revised 2026-09-01 (product decision, not this file's own judgment call): `.gate` no
    /// longer shows a dedicated emergency-line callout -- live-review feedback found it visually
    /// dominated the top of the gate section screen. The opening disclaimer's body text (shown
    /// one screen earlier) still carries the same "if you're having a medical emergency, stop
    /// and call your local emergency number" instruction inline, and the urgent interstitial
    /// (`.urgentInterstitial`, still `true` below) still shows it as a dedicated callout when
    /// G2/G3 = yes. This function's return value for `.gate` is what `GateSectionView` obeys --
    /// see its own header comment for the full record.
    public static func showsEmergencyLine(for section: ScreeningSection) -> Bool {
        switch section {
        case .urgentInterstitial:
            return true
        case .openingDisclaimer, .gate, .conditionChecklist, .severityFollowUps, .routineInterstitial:
            return false
        }
    }
}
