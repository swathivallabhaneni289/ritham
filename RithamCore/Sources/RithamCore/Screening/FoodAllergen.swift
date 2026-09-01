// Allergens are diet-plan preference data, asked and edited alongside `DietaryPattern` in
// Settings' diet section, not as a health-screening severity follow-up -- direct product
// feedback (2026-09-01) moved this out of `SeverityFollowUpView` before it was ever built there.
// Like `DietaryPattern` (see that file's own header comment), this must never be referenced by
// `ClearanceGate`, `DomainGates`, or `TagDerivation`: which foods a person avoids is not a
// safety-gate input, only food-suggestion guidance downstream of one.

/// A fixed multi-select list of common allergens (the US FALCPA/FASTER Act "Big 9" major food
/// allergens: milk, eggs, fish, shellfish, tree nuts, peanuts, wheat, soy, sesame), plus a
/// generic `other` catch-all. HEALTH-01 forbids free text anywhere in this app, so `other`
/// cannot capture which allergen, matching every "other ..." checklist case elsewhere (e.g.
/// `ChecklistItem.otherMetabolicCondition`).
public enum FoodAllergen: String, CaseIterable, Sendable, Hashable, Codable {
    case milk
    case eggs
    case fish
    case shellfish
    case treeNuts
    case peanuts
    case wheat
    case soy
    case sesame
    case other
}
