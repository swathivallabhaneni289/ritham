import SwiftUI
import RithamCore

/// One of `HealthDataStore.supportedMomentumTargets`'s four values (2/3/4/5), wrapped for
/// `ChoiceQuestionView`'s `Identifiable` requirement rather than a retroactive `Int:
/// Identifiable` conformance -- the same rationale `WorkoutFrequencyView.swift`'s own
/// `WeeklyFrequencyOption` documents: a bare `Int` has no natural single UI-option identity of
/// its own, and conforming the whole standard-library type would leak far past this one screen.
struct MomentumTargetOption: Hashable, Identifiable {
    let target: Int
    var id: Int { target }

    /// The four supported choices, ascending. Declared as its own literal-derived list here
    /// rather than read from `HealthDataStore.supportedMomentumTargets` at declaration time --
    /// that property lives on `@MainActor`-isolated `HealthDataStore`, and this type must stay
    /// nonisolated to satisfy `Identifiable` generically for `ChoiceQuestionView<Option: Hashable
    /// & Identifiable>`. `MomentumTargetPickerTests.pickerOptionsMatchTheStoreSupportedTargets`
    /// asserts set-equality against `HealthDataStore.supportedMomentumTargets` (itself sourced
    /// from `MomentumTarget.supported`), so the two declared-separately lists can never silently
    /// drift apart -- the same drift guard `WeeklyFrequencyOption.all` already carries for its own
    /// two lists.
    static let all: [MomentumTargetOption] = MomentumTarget.supported.sorted().map(MomentumTargetOption.init)
}

/// MOMENTUM-01's weekly Momentum target preference: a near-verbatim adaptation of the shipped
/// `WorkoutFrequencyView` (the same flat decorative surface, same single-selection
/// `ChoiceQuestionView` chip picker, same inline save-error text, same init-supplied initial
/// selection so the first render never fires `onChange` and re-persists the value it was just
/// handed) with the frequency option set swapped for the four Momentum-target values.
///
/// **Planning decision, recorded here as an explicit deviation from the orchestrator's own
/// framing:** this screen is a Settings-presented sheet, not a registered `OnboardingStep` case,
/// even though `MomentumView` (plan 03-06) is. Four concrete reasons:
/// 1. `SettingsView` is itself presented as a sheet from `HomeHubView`. Routing from inside a
///    sheet through `flow.open(_:)` would push this screen onto the app's one root
///    `NavigationStack`, landing it visually *behind* the `SettingsView` sheet still on screen --
///    not a real, reachable navigation.
/// 2. Every shipped Settings sub-screen in this codebase (`DietPlanView`, `WorkoutFrequencyView`,
///    `HealthProfileView`, `EditAnswerFlow`'s section screens) is presented as a sheet for exactly
///    this reason -- there is no existing precedent for a Settings sub-screen as a pushed step.
/// 3. `03-UI-SPEC.md` Component 10 states this screen "follows `WorkoutFrequencyView` exactly,"
///    and that screen is itself a sheet, not a step.
/// 4. `03-RESEARCH.md`'s Pattern 4 names three full-screen surfaces that require a registered
///    step case, and this screen is not one of them.
struct MomentumTargetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var selection: Set<MomentumTargetOption>
    @State private var showSaveError = false

    /// The current target arrives already loaded (supplied by `SettingsView` at
    /// sheet-presentation time via the store's target loader), matching
    /// `WorkoutFrequencyView.init(initialFrequency:)`'s own "answers arrive already resolved"
    /// shape -- never loaded by this view itself in `onAppear`.
    init(initialTarget: Int) {
        _selection = State(initialValue: [MomentumTargetOption(target: initialTarget)])
    }

    var body: some View {
        RithamScreen(surface: DecorativeSurface.flat, headline: "Momentum target") {
            ChoiceQuestionView(
                prompt: MomentumCopy.Target.pickerPrompt,
                helper: MomentumCopy.Target.pickerHelper,
                options: MomentumTargetOption.all,
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
            persist(chosen.target)
        }
    }

    static func optionTitle(_ option: MomentumTargetOption) -> String {
        "\(option.target) sessions a week"
    }

    /// Copies `WorkoutFrequencyView.persist`'s isolation discipline exactly: only
    /// `HealthDataStore.saveMomentumTarget`, never any reconciliation or ledger type directly --
    /// this is a preference write, not a Momentum read, so this screen never reaches around the
    /// store's own accessor.
    private func persist(_ target: Int) {
        let store = HealthDataStore(context: modelContext)
        do {
            try store.saveMomentumTarget(target)
            showSaveError = false
        } catch {
            showSaveError = true
        }
    }
}
