import SwiftUI
import RithamCore

// STRENGTH-01/STRENGTH-04's exercise selector: a sheet-presented, name-searchable list of
// `ExerciseCatalog.all` (RithamCore, already seeded and unit-tested), showing each entry's
// auto-assigned movement pattern(s) as read-only labels. Per STRENGTH-04, pattern assignment is
// fully automatic -- this screen offers no control that lets a user pick or change a pattern, and
// adds no exercise-to-pattern lookup of its own; every pattern shown here comes straight from
// `ExerciseCatalog.patterns(for:)`.
//
// This view adds no calculation and no persistence logic: selecting a row only hands the chosen
// `ExerciseDefinition` back to the caller via `onSelect`, which decides what happens next.

/// A plain case-insensitive substring match on `displayName` -- no domain logic, no additional
/// RithamCore involvement, since this is presentation-layer filtering of an already-seeded list,
/// not a calculation STRENGTH-01/04 need RithamCore to own. Extracted as a standalone, non-private
/// function (rather than a `View`-local computed property) so `StrengthSetEntryTests` can assert
/// the search behavior without rendering `ExercisePickerView`.
enum ExercisePickerFilter {
    static func matching(_ query: String, in exercises: [ExerciseDefinition] = ExerciseCatalog.all) -> [ExerciseDefinition] {
        guard !query.isEmpty else { return exercises }
        return exercises.filter { $0.displayName.localizedCaseInsensitiveContains(query) }
    }
}

/// Sheet-presented picker for `ExerciseCatalog.all`, searchable by display name.
struct ExercisePickerView: View {
    let onSelect: (ExerciseDefinition) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filteredExercises: [ExerciseDefinition] {
        ExercisePickerFilter.matching(searchText)
    }

    var body: some View {
        RithamScreen(surface: DecorativeSurface.flat, headline: "Add exercise") {
            TextField("Search exercises", text: $searchText)
                .font(RithamType.body)
                .foregroundStyle(RithamColor.paper)
                .padding(RithamSpacing.md)
                .frame(minHeight: RithamSpacing.minimumTapTarget)
                .background(
                    RoundedRectangle(cornerRadius: RithamSpacing.sm)
                        .stroke(RithamColor.paper, lineWidth: 1)
                )
                .accessibilityLabel("Search exercises")

            VStack(alignment: .leading, spacing: RithamSpacing.sm) {
                ForEach(filteredExercises, id: \.identifier) { exercise in
                    Button {
                        onSelect(exercise)
                        dismiss()
                    } label: {
                        exerciseRow(exercise)
                    }
                }
            }

            SecondaryCTAButton(title: "Cancel") {
                dismiss()
            }
        }
    }

    @ViewBuilder
    private func exerciseRow(_ exercise: ExerciseDefinition) -> some View {
        VStack(alignment: .leading, spacing: RithamSpacing.xs) {
            Text(exercise.displayName)
                .font(RithamType.body)
                .foregroundStyle(RithamColor.paper)

            Text(patternsLabel(exercise))
                .font(RithamType.label)
                .foregroundStyle(RithamColor.paper.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(RithamSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: RithamSpacing.sm)
                .stroke(RithamColor.paper.opacity(0.3), lineWidth: 1)
        )
    }

    /// Read-only presentation of an exercise's auto-assigned patterns -- never editable, per
    /// STRENGTH-04.
    private func patternsLabel(_ exercise: ExerciseDefinition) -> String {
        exercise.patterns
            .sorted { $0.rawValue < $1.rawValue }
            .map(\.displayName)
            .joined(separator: " \u{00b7} ")
    }
}
