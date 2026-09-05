import SwiftUI
import RithamCore

/// One of the three weekly-frequency choices `HealthDataStore.supportedWeeklyFrequencies`
/// persists. A small wrapper type rather than a retroactive `Int: Identifiable` conformance --
/// unlike `DietaryPattern`/`ChecklistItem`, a bare `Int` has no natural single UI-option identity
/// of its own, and conforming the whole standard-library type would leak far past this one
/// screen.
struct WeeklyFrequencyOption: Hashable, Identifiable {
    let daysPerWeek: Int
    var id: Int { daysPerWeek }

    /// The three supported choices, ascending. Kept as its own literal here rather than derived
    /// from `HealthDataStore.supportedWeeklyFrequencies` at declaration time -- that constant
    /// lives on `@MainActor`-isolated `HealthDataStore`, and this type must stay nonisolated to
    /// satisfy `Identifiable` generically for `ChoiceQuestionView<Option: Hashable &
    /// Identifiable>`. `WorkoutFrequencyTests.weeklyFrequencyOptionsMatchSupportedFrequencies`
    /// asserts byte-for-byte equality against the store's own constant, so the two declared-
    /// separately lists can never silently drift apart.
    static let all: [WeeklyFrequencyOption] = [3, 5, 7].map(WeeklyFrequencyOption.init)
}

/// The weekly workout-frequency preference (`02-CONTEXT.md`'s Claude's Discretion): an ordinary,
/// gate-isolated Settings preference in the same family as `DietPlanView`'s dietary pattern.
/// Presented as a sheet from `SettingsView`, the same pairing that screen already uses for the
/// diet plan.
///
/// Fixed-choice only -- `HealthDataStore.saveWeeklyFrequency` throws on anything outside
/// `supportedWeeklyFrequencies`, so this screen offers only those three values via
/// `ChoiceQuestionView`'s chip picker, never free text or an arbitrary number.
///
/// The initial selection arrives already loaded (`initialFrequency`, supplied by `SettingsView`
/// at sheet-presentation time via the store's frequency loader) rather than this view loading it
/// itself in `onAppear` -- the same "answers arrive already resolved" shape `DietPlanView`'s own
/// initializer uses for `flow.answers.dietaryPattern`. Setting the initial selection through
/// `init` (rather than an `onAppear` + `onChange` pair) also means the first render never fires
/// `onChange` and re-persists the value it was just loaded with.
struct WorkoutFrequencyView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var selection: Set<WeeklyFrequencyOption>
    @State private var showSaveError = false

    init(initialFrequency: Int) {
        _selection = State(initialValue: [WeeklyFrequencyOption(daysPerWeek: initialFrequency)])
    }

    var body: some View {
        RithamScreen(surface: DecorativeSurface.flat, headline: "Workout frequency") {
            Text("How many days a week do you want to plan for? Change this anytime -- it shapes future plan generation, never a one-time lock.")
                .font(RithamType.body)
                .foregroundStyle(RithamColor.paper)
                .fixedSize(horizontal: false, vertical: true)

            ChoiceQuestionView(
                prompt: "Weekly workout frequency",
                options: WeeklyFrequencyOption.all,
                mode: .single,
                selection: $selection,
                optionTitle: Self.optionTitle
            )

            if showSaveError {
                Text(OnboardingCopy.Errors.savingFailed)
                    .font(RithamType.label)
                    .foregroundStyle(RithamColor.hot)
                    .fixedSize(horizontal: false, vertical: true)
            }

            PrimaryCTAButton(title: "Done") {
                dismiss()
            }
        }
        .onChange(of: selection) { _, newValue in
            guard let chosen = newValue.first else { return }
            persist(chosen.daysPerWeek)
        }
    }

    static func optionTitle(_ option: WeeklyFrequencyOption) -> String {
        "\(option.daysPerWeek) days a week"
    }

    /// Copies `DietPlanView.persistDiet`'s isolation discipline exactly: only
    /// `HealthDataStore.saveWeeklyFrequency`, never `GateResolution`, `TagDerivation`, or
    /// `saveScreeningResult` -- this is a preference, not a screening answer, and the store's own
    /// accessor is already isolated, so this screen never reaches around it.
    private func persist(_ frequency: Int) {
        let store = HealthDataStore(context: modelContext)
        do {
            try store.saveWeeklyFrequency(frequency)
            showSaveError = false
        } catch {
            showSaveError = true
        }
    }
}
