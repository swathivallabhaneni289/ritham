import SwiftData
import RithamCore

// One persisted allergen, one row per value -- the same shape `ConditionTagRecord` already uses
// for a set of raw-value-backed cases. Saved and loaded independently of `ConditionTagRecord`
// (see `HealthDataStore.saveFoodAllergens`/`loadFoodAllergens`): allergens are diet-plan
// preference data framed alongside `DietaryPattern`, never a health-screening/gate record, per
// `FoodAllergen`'s own header comment.
@Model
public final class FoodAllergenRecord {
    public var allergenRaw: String

    public init(allergenRaw: String) {
        self.allergenRaw = allergenRaw
    }

    /// `nil` rather than a trap when `allergenRaw` no longer matches a known `FoodAllergen` case
    /// (T-01-64's pattern, same as `ConditionTagRecord.tag`).
    public var allergen: FoodAllergen? {
        FoodAllergen(rawValue: allergenRaw)
    }
}
