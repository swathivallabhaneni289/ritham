// The content-permission axis for guidance text, independent from `ClearanceGate`.
// `GateEscalation.swift`'s own comment on `hypertensionUncontrolledOrUnsure` records that the
// three-level gate has no state narrower than `requiredBlocking` to express "no personalized
// quantity, but generic education still allowed" -- that nuance lives here instead. Every
// value below is transcribed independently, per tag and per domain, from
// docs/health-screening.md section 2 (workout) and section 3 (nutrition)'s own prose, never
// computed from that tag's `ClearanceGate` value: section 3 gives Kidney Disease/Dialysis,
// Pregnancy - Complicated/Unsure, and a positive eating-disorder screen zero content, while
// giving Under-18, Hypertension - Uncontrolled/Unsure, and Postpartum - Uncomplicated general
// education under the same clearance-gate level. A formula over the gate enum would collapse
// those two groups together, which is the exact defect 02-RESEARCH.md's Pitfall 1 describes.

/// The three content-permission levels a `(ConditionTag, GuidanceDomain)` pair can carry, in
/// ascending permissiveness order. `Comparable` conformance is synthesized from declaration
/// order, mirroring `ClearanceGate`'s own discipline: the ordering is a language-level fact,
/// not a convention each call site has to re-implement.
public enum ContentPermission: Sendable, Equatable, Comparable, CaseIterable {
    /// Zero content of any kind for this domain, not even general education. Only a blocking
    /// message and a referral.
    case none

    /// General, non-individualized education is permitted for this domain. Zero personalized
    /// quantities (no calorie number, no macro split, no portion target, no personalized
    /// intensity or load) regardless of what else is shown.
    case educationOnly

    /// This tag's full rule-table content is available for this domain.
    case full

    /// The single most restrictive permission across every input, folding a tag set the same
    /// way HEALTH-06 folds a tag set of `ClearanceGate` values. Returns `.none` for an empty
    /// input.
    public static func mostRestrictive(_ permissions: [ContentPermission]) -> ContentPermission {
        permissions.min() ?? .none
    }
}

/// A tag's declared content permission for each `GuidanceDomain`, mirroring `DomainGates`'
/// shape since a tag's workout and nutrition permissions are independently transcribed from
/// two different sections of docs/health-screening.md and can differ from each other.
private struct DomainPermissions {
    var workout: ContentPermission
    var nutrition: ContentPermission

    subscript(domain: GuidanceDomain) -> ContentPermission {
        switch domain {
        case .workout:
            return workout
        case .nutrition:
            return nutrition
        }
    }
}

/// Content-layer lookups downstream of `GateEscalation`'s gate resolution. `GuidanceCatalog`
/// answers "what content may this tag show," never "what gate does this tag carry" -- that
/// remains `GateEscalation`'s and `ClearanceGate`'s job, read here but never modified.
public enum GuidanceCatalog {

    /// One case per `ConditionTag`, each citing the section 2 (workout) or section 3
    /// (nutrition) row it was transcribed from. No `default` clause: adding a 32nd
    /// `ConditionTag` case is a compile error here, not a silent fallthrough.
    ///
    /// Within a domain, `.full` is declared wherever that domain's Clearance Gate column is
    /// `none` or `recommended` and the row's own prose does not itself forbid a personalized
    /// quantity or intensity (the nutrition table's `recommended` legend already forbids a
    /// personalized quantity for most rows; a handful, like the food-allergy and
    /// clinician-prescribed-plan rows, are `recommended` for a reason unrelated to
    /// quantities -- a verification flag or a deferral to an external plan -- and are declared
    /// `.full` here rather than `.educationOnly`, since nothing in their prose blocks a
    /// quantity). `.educationOnly` and `.none` are declared per the row's own required-
    /// blocking prose, exactly as this file's header describes.
    private static func declaredPermissions(for tag: ConditionTag) -> DomainPermissions {
        switch tag {
        case .under18Minor:
            // Section 2: no age-alone workout restriction, full content applies. Section 3:
            // "general movement and food-variety education only," every quantity blocked.
            return DomainPermissions(workout: .full, nutrition: .educationOnly)
        case .age65PlusOrDeconditioned:
            // Section 2: none gate, full progression content. Section 3: "no nutrition-
            // specific rule from this framework, standard general guidance applies."
            return DomainPermissions(workout: .full, nutrition: .full)
        case .hypertensionManaged:
            // Section 2: recommended gate, full personalized content with a caution note.
            // Section 3: recommended gate forbids "calculating or displaying a personalized
            // sodium mg/day target," leaving only DASH-style education.
            return DomainPermissions(workout: .full, nutrition: .educationOnly)
        case .hypertensionUncontrolledOrUnsure:
            // Section 2: "offer only general, non-vigorous activity information until status
            // is clarified." Section 3: "the same DASH-style educational content...may still
            // be shown," but no personalized quantity of any kind.
            return DomainPermissions(workout: .educationOnly, nutrition: .educationOnly)
        case .heartDiseaseStable:
            // Section 2: recommended gate, full cardiac-rehab-paced content. Section 3:
            // recommended gate forbids "an individualized saturated-fat percentage or
            // cholesterol mg target," leaving only AHA general education.
            return DomainPermissions(workout: .full, nutrition: .educationOnly)
        case .heartDiseaseRecentEventOrSymptomatic:
            // Section 2: "hold personalized suggestions; direct to a cardiac-rehab program,"
            // no general activity content offered in the row. Section 3: "general heart-
            // healthy educational content only, no personalized targets."
            return DomainPermissions(workout: .none, nutrition: .educationOnly)
        case .arrhythmiaStable:
            // Section 2: recommended gate, full content. Section 3: "no arrhythmia-specific
            // nutrition rule was identified," standard guidance applies for this tag alone.
            return DomainPermissions(workout: .full, nutrition: .full)
        case .arrhythmiaUncontrolledOrUnsure:
            // Section 2: "hold personalized intensity suggestions until rate control is
            // established," no general content offered in the row, matching the required-
            // blocking-and-truly-empty pattern this file's header names for
            // `heartDiseaseRecentEventOrSymptomatic`. Section 3: no arrhythmia-specific
            // nutrition rule for this tag alone, standard guidance applies.
            return DomainPermissions(workout: .none, nutrition: .full)
        case .rateLimitingHeartOrBPMedication:
            // Section 2: a method modifier, not itself a gate, full content. Section 3: no
            // row exists for this modifier.
            return DomainPermissions(workout: .full, nutrition: .full)
        case .diabetesOnHypoglycemiaRiskMedication:
            // Section 2: recommended gate, full content plus a glucose-check reminder.
            // Section 3: recommended gate forbids "calculating a personalized carbohydrate-
            // gram target," leaving the Plate Method as general education.
            return DomainPermissions(workout: .full, nutrition: .educationOnly)
        case .diabetesNotOnHypoglycemiaRiskMedication:
            // Section 2: none gate, full content. Section 3: same Plate Method row as the
            // on-medication case above, same educationOnly reasoning.
            return DomainPermissions(workout: .full, nutrition: .educationOnly)
        case .prediabetes:
            // Section 2: none gate, full content. Section 3: none gate; the row's one
            // prohibition is a specific published figure, not a blanket quantity block, so
            // standard personalization applies.
            return DomainPermissions(workout: .full, nutrition: .full)
        case .diabetesRetinopathyOrFootComplication:
            // Section 2: recommended gate, full content with mode-specific caution. Section
            // 3: "same as underlying Diabetes row," same educationOnly reasoning.
            return DomainPermissions(workout: .full, nutrition: .educationOnly)
        case .osteoarthritis:
            // Section 2: recommended gate, full low-impact-mode content. Section 3: "no
            // nutrition-specific rule was identified," standard guidance applies.
            return DomainPermissions(workout: .full, nutrition: .full)
        case .osteoporosisOrOsteopenia:
            // Section 2: recommended gate, full content. Section 3: no nutrition-specific
            // rule, standard guidance applies.
            return DomainPermissions(workout: .full, nutrition: .full)
        case .chronicLowBackPain:
            // Section 2: recommended gate, full content. Section 3: no nutrition-specific
            // rule, standard guidance applies.
            return DomainPermissions(workout: .full, nutrition: .full)
        case .priorInjuryOrSurgeryNotCleared:
            // Section 2: "general, low-impact, non-affected-area activity can still be
            // suggested" even though loading progression for the affected area is held.
            // Section 3: no nutrition-specific rule, standard guidance applies.
            return DomainPermissions(workout: .educationOnly, nutrition: .full)
        case .priorInjuryOrSurgeryCleared:
            // Section 2: recommended gate, full conservative-reintroduction content. Section
            // 3: no nutrition-specific rule, standard guidance applies.
            return DomainPermissions(workout: .full, nutrition: .full)
        case .musculoskeletalFlare:
            // Section 2: recommended gate, full higher-caution content. Section 3: flare
            // status changes workout guidance only, standard nutrition guidance applies.
            return DomainPermissions(workout: .full, nutrition: .full)
        case .pregnancyUncomplicated:
            // Section 2: recommended gate, full content. Section 3: "general, non-numeric
            // educational content about eating patterns during pregnancy...may be shown; no
            // calorie or weight-loss targets under any circumstance."
            return DomainPermissions(workout: .full, nutrition: .educationOnly)
        case .pregnancyComplicatedOrUnsure:
            // Section 2: "general, non-quantified information only" even though personalized
            // suggestions are held entirely. Section 3: "no personalized content at all,
            // including the general educational text allowed in the row above, referral
            // only."
            return DomainPermissions(workout: .educationOnly, nutrition: .none)
        case .postpartumUncomplicated:
            // Section 2: recommended gate, full content. Section 3: "general, non-
            // restrictive recovery-supportive education," blocked specifically for the
            // weight-loss goal-setting feature.
            return DomainPermissions(workout: .full, nutrition: .educationOnly)
        case .postpartumCSectionOrComplications:
            // Section 2: "general, non-quantified information only" even though
            // personalized suggestions are held until clearance. Section 3: "general
            // educational content only, more conservative than the uncomplicated row."
            return DomainPermissions(workout: .educationOnly, nutrition: .educationOnly)
        case .kidneyDiseaseOrDialysis:
            // Section 2: no exercise-specific guidance was identified in the research; the
            // table's own preamble says an unresearched pairing defaults to the more
            // cautious setting, so zero content. Section 3: explicitly "zero personalized
            // guidance of any kind, including general framework content."
            return DomainPermissions(workout: .none, nutrition: .none)
        case .eatingDisorderPositiveScreen:
            // Section 2: "general movement-for-enjoyment suggestions only" even though
            // quantified/compensatory framing is held entirely. Section 3: "shift entirely
            // to non-numeric, behavior-based content (e.g., general food-variety education)
            // if any nutrition content is shown at all."
            return DomainPermissions(workout: .educationOnly, nutrition: .educationOnly)
        case .eatingDisorderSelfReportedNegativeScreen:
            // Section 2: recommended gate, full standard content. Section 3: "general
            // framework guidance permitted"; numeric targets stay off by default but the row
            // does not forbid them outright, so this is a display-default concern for a
            // later plan's nutrition catalog, not a permission-layer block.
            return DomainPermissions(workout: .full, nutrition: .full)
        case .severeFoodAllergy:
            // Section 2: no exercise-specific adjustment identified, none gate, full
            // content. Section 3: recommended gate is for a standing verification flag, not
            // a quantity restriction, so full nutrition content applies (the flag itself is
            // `GateEscalation.requiresIndependentAllergenVerification`, not modeled here).
            return DomainPermissions(workout: .full, nutrition: .full)
        case .nonSevereFoodAllergy:
            // Section 2: no exercise-specific adjustment identified, full content. Section
            // 3: a label-check reminder only, not a quantity restriction, full content.
            return DomainPermissions(workout: .full, nutrition: .full)
        case .otherSeriousConditionOrActiveCancerTreatment:
            // Section 2: no exercise-specific guidance was identified in the research,
            // defaulting to the more cautious zero-content setting, same reasoning as
            // Kidney Disease/Dialysis above. Section 3: explicitly "for the same reason as
            // kidney disease," zero content.
            return DomainPermissions(workout: .none, nutrition: .none)
        case .clinicianPrescribedDietOrMealPlan:
            // Section 2: no workout-specific rule from this framework, full content (there
            // is nothing to restrict). Section 3: recommended gate defers to an external
            // clinician-set plan rather than restricting a quantity Ritham would otherwise
            // compute, so full content applies.
            return DomainPermissions(workout: .full, nutrition: .full)
        case .noneOfTheAboveBaseline:
            // Section 2 and section 3: none gate in both tables, full standard programming
            // and full personalization.
            return DomainPermissions(workout: .full, nutrition: .full)
        }
    }

    /// The declared content permission for a single tag and domain, transcribed
    /// independently from the rule tables' prose rather than derived from
    /// `GateEscalation.baseGates(for:)`.
    public static func contentPermission(for tag: ConditionTag, domain: GuidanceDomain) -> ContentPermission {
        declaredPermissions(for: tag)[domain]
    }

    /// The most restrictive permission across a tag set, for a single domain. An empty tag
    /// set means the caller has no screening data at all -- a screened user always carries at
    /// least `.noneOfTheAboveBaseline`, so an empty set must resolve to `.none`, never to
    /// `.full`.
    public static func resolvedPermission(for tags: [ConditionTag], domain: GuidanceDomain) -> ContentPermission {
        guard !tags.isEmpty else {
            return .none
        }
        return ContentPermission.mostRestrictive(tags.map { contentPermission(for: $0, domain: domain) })
    }
}
