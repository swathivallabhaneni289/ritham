import SwiftUI
import RithamCore

// STRENGTH-02's plate calculator surface: covers all five `Equipment` kinds, routing a pin-stack
// kind away from plate arithmetic entirely (T-02-06's threat register entry) and rendering
// `PlateCalculator.nearestLoadable`'s `nil` return as an invalid-input state -- never a
// force-unwrap, never a substituted zero. Presented as a sheet from set entry, following the
// sheet-presented own-screen pattern `DietPlanView` already uses.
//
// The one-rep-max estimate (`OneRepMaxCalculator.estimate`) is shown alongside, labelled as a
// general estimate and never framed as a score, grade, level, percentile, or rating -- the
// product-wide prohibition D-04 established for derived capability figures (T-02-33).

/// Drives `PlateCalculatorView`'s behavior at the model level, so `PlateCalculatorScreenTests`
/// can assert every behavior in the plan's `<behavior>` list without rendering the view.
@MainActor
@Observable
final class PlateCalculatorModel {
    var equipment: Equipment
    var barWeightKg: Double
    var targetWeightKg: String
    var availablePlatesKg: [Double]

    init(
        equipment: Equipment = .standardBarbell,
        targetWeightKg: String = "",
        availablePlatesKg: [Double] = PlateInventory.metricDefaultKg
    ) {
        self.equipment = equipment
        self.barWeightKg = equipment.defaultBarWeightKg
        self.targetWeightKg = targetWeightKg
        self.availablePlatesKg = availablePlatesKg
    }

    /// Choosing an equipment kind resets the bar weight to its default. A pin-stack kind's
    /// bar-weight field is hidden entirely by the view -- this method still keeps the field
    /// numerically consistent so a later switch back to a plate-loaded kind starts from a real
    /// default rather than a stale value.
    func selectEquipment(_ newEquipment: Equipment) {
        equipment = newEquipment
        barWeightKg = newEquipment.defaultBarWeightKg
    }

    var isPinStack: Bool {
        equipment.loadingStyle == .pinStack
    }

    /// `nil` for a negative, empty, non-numeric, or otherwise out-of-range target -- rendered by
    /// the view as an explicit invalid-input state with no plate list, never a force-unwrap and
    /// never a substituted zero (T-02-06).
    var result: PlateLoad? {
        guard let target = Double(targetWeightKg) else { return nil }
        return PlateCalculator.nearestLoadable(
            target: target,
            equipment: equipment,
            availablePlatesKg: availablePlatesKg,
            barWeightKg: isPinStack ? nil : barWeightKg
        )
    }

    /// True for a negative, empty, or non-numeric target -- every case `PlateCalculator
    /// .nearestLoadable` itself would also reject, since `result` is `nil` in exactly this same
    /// set of cases. Rendered by the view as an explicit invalid-input state with no plate list.
    var isInvalidInput: Bool {
        result == nil
    }

    /// One-rep-max estimate for `weightKg`/`reps`, computed purely from
    /// `OneRepMaxCalculator.estimate` -- `nil` for an unsupported rep count or non-positive
    /// weight, in which case the view hides this row entirely rather than showing a placeholder.
    func oneRepMaxEstimate(weightKg: Double, reps: Int) -> Double? {
        OneRepMaxCalculator.estimate(weightKg: weightKg, reps: reps)
    }

    /// The weight to write back to the set being logged: the achievable weight `result` actually
    /// computed, never the raw typed target. `nil` when there is no valid result to apply.
    var achievableWeightToApply: Double? {
        result?.achievedWeightKg
    }
}

struct PlateCalculatorView: View {
    /// Called with the achievable weight when the user applies the result back to the set being
    /// logged -- never the raw typed target.
    let onApply: (Double) -> Void

    /// The set's current weight/reps, used only to compute the alongside one-rep-max estimate.
    var currentWeightKg: Double?
    var currentReps: Int?

    @Environment(\.dismiss) private var dismiss
    @State private var model: PlateCalculatorModel

    init(
        equipment: Equipment = .standardBarbell,
        currentWeightKg: Double? = nil,
        currentReps: Int? = nil,
        onApply: @escaping (Double) -> Void
    ) {
        self.onApply = onApply
        self.currentWeightKg = currentWeightKg
        self.currentReps = currentReps
        _model = State(initialValue: PlateCalculatorModel(equipment: equipment))
    }

    var body: some View {
        RithamScreen(surface: DecorativeSurface.flat, headline: "Plate calculator") {
            equipmentPicker

            if !model.isPinStack {
                barWeightField
            }

            targetField

            resultSection

            oneRepMaxSection

            SecondaryCTAButton(title: "Close") {
                dismiss()
            }
        }
    }

    // MARK: - Equipment

    private var equipmentPicker: some View {
        VStack(alignment: .leading, spacing: RithamSpacing.sm) {
            Text("Equipment")
                .font(RithamType.body)
                .foregroundStyle(RithamColor.paper)

            WrapEquipmentChips(selected: model.equipment) { chosen in
                model.selectEquipment(chosen)
            }
        }
    }

    private var barWeightField: some View {
        labelledNumericField(
            label: "Bar weight (kg)",
            text: Binding(
                get: { formattedNumber(model.barWeightKg) },
                set: { model.barWeightKg = Double($0) ?? model.barWeightKg }
            )
        )
    }

    private var targetField: some View {
        labelledNumericField(label: "Target weight (kg)", text: $model.targetWeightKg)
    }

    private func labelledNumericField(label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: RithamSpacing.xs) {
            Text(label)
                .font(RithamType.label)
                .foregroundStyle(RithamColor.paper)

            TextField(label, text: text)
                .keyboardType(.decimalPad)
                .font(RithamType.body)
                .modifier(RithamType.numerals())
                .foregroundStyle(RithamColor.paper)
                .padding(RithamSpacing.sm)
                .frame(minHeight: RithamSpacing.minimumTapTarget)
                .background(
                    RoundedRectangle(cornerRadius: RithamSpacing.sm)
                        .stroke(RithamColor.paper, lineWidth: 1)
                )
                .accessibilityLabel(label)
        }
    }

    // MARK: - Result

    @ViewBuilder
    private var resultSection: some View {
        if model.isInvalidInput {
            Text("Enter a valid, non-negative target weight.")
                .font(RithamType.label)
                .foregroundStyle(RithamColor.hot)
        } else if let result = model.result {
            VStack(alignment: .leading, spacing: RithamSpacing.xs) {
                if !result.platesPerSideKg.isEmpty {
                    Text("Load per side: \(result.platesPerSideKg.map(formattedNumber).joined(separator: ", ")) kg")
                }
                Text(
                    result.isExactMatch
                        ? "Achievable: \(formattedNumber(result.achievedWeightKg)) kg (exact match)"
                        : "Nearest achievable: \(formattedNumber(result.achievedWeightKg)) kg"
                )

                PrimaryCTAButton(title: "Apply to set") {
                    onApply(result.achievedWeightKg)
                    dismiss()
                }
            }
            .font(RithamType.body)
            .modifier(RithamType.numerals())
            .foregroundStyle(RithamColor.paper)
        }
    }

    // MARK: - One-rep-max

    /// Labelled plainly as an estimate -- never a score, grade, level, percentile, or rating
    /// (T-02-33). Hidden entirely when no estimate is available, rather than shown with a
    /// placeholder value.
    @ViewBuilder
    private var oneRepMaxSection: some View {
        if let weight = currentWeightKg,
           let reps = currentReps,
           let estimate = model.oneRepMaxEstimate(weightKg: weight, reps: reps) {
            Text("Estimated one-rep max: \(formattedNumber(estimate)) kg")
                .font(RithamType.label)
                .foregroundStyle(RithamColor.paper)
        }
    }

    private func formattedNumber(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.2f", value)
    }
}

/// A row of equipment-kind chips -- kept file-local since it's a one-off selector, not a
/// general-purpose choice component like `ChoiceQuestionView`.
private struct WrapEquipmentChips: View {
    let selected: Equipment
    let onSelect: (Equipment) -> Void

    var body: some View {
        HStack(spacing: RithamSpacing.sm) {
            ForEach(Equipment.allCases, id: \.self) { equipment in
                ChoiceChip(title: equipment.displayName, isSelected: equipment == selected) {
                    onSelect(equipment)
                }
            }
        }
    }
}
