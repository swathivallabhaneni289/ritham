import SwiftUI
import RithamCore

// D-09/03-UI-SPEC.md Component 9's binding decision, recorded here verbatim rather than only in
// the plan: this opt-in deliberately uses the app's existing two-option `ChoiceQuestionView`/
// `ChoiceChip` pattern rather than a first-ever native `SwiftUI.Toggle`. The codebase has zero
// `Toggle` precedent anywhere. A native `Toggle`'s default on-state track color is the system
// accent (blue); tinting it `RithamColor.hot` to match this app's palette would put a white knob
// on a coral track, measured at roughly 2.8:1 -- below even the 3:1 WCAG non-text-contrast floor,
// and exactly the kind of "intuitive-but-wrong" default `RithamColor.label(on:)` exists elsewhere
// in this app to make unreachable. The chip control is already contrast-verified (see
// 01-UI-SPEC.md's Contrast Verification table) and is the one sanctioned binary-choice control
// app-wide -- reused here rather than introducing a second, unverified one.

/// The two states this preference can be in, wrapped for `ChoiceQuestionView`'s `Identifiable`
/// requirement -- the same rationale `WeeklyFrequencyOption`/`MomentumTargetOption` already
/// document: a bare `Bool` has no natural single UI-option identity of its own.
struct MovementSnapshotOptInOption: Hashable, Identifiable {
    let isOn: Bool
    var id: Bool { isOn }

    /// On first, matching `MomentumCopy.Snapshot`'s own "On"/"Off" ordering.
    static let all: [MovementSnapshotOptInOption] = [
        MovementSnapshotOptInOption(isOn: true),
        MovementSnapshotOptInOption(isOn: false),
    ]
}

/// MOMENTUM-07/D-09's Settings opt-in for the Daily Movement Snapshot: a sheet-presented
/// preference screen, near-verbatim adaptation of the shipped `WorkoutFrequencyView`/
/// `MomentumTargetView` shape (flat decorative surface, single-selection `ChoiceQuestionView`
/// chip picker, the shared inline save-error text, init-supplied initial selection so the first
/// render never fires `onChange` and re-persists the value it was just handed) with the option
/// set swapped for this preference's two On/Off values.
///
/// Off by default: `SettingsView` supplies `initialOptIn` from
/// `HealthDataStore.loadMovementSnapshotOptIn()`, which itself defaults to `false` on an empty
/// store.
struct MovementSnapshotToggleView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var selection: Set<MovementSnapshotOptInOption>
    @State private var showSaveError = false

    /// The current opt-in arrives already loaded (supplied by `SettingsView` at
    /// sheet-presentation time via the store's opt-in loader), matching
    /// `WorkoutFrequencyView.init(initialFrequency:)`/`MomentumTargetView.init(initialTarget:)`'s
    /// own "answers arrive already resolved" shape -- never loaded by this view itself in
    /// `onAppear`.
    init(initialOptIn: Bool) {
        _selection = State(initialValue: [MovementSnapshotOptInOption(isOn: initialOptIn)])
    }

    var body: some View {
        RithamScreen(surface: DecorativeSurface.flat, headline: "Daily Movement Snapshot") {
            ChoiceQuestionView(
                prompt: MomentumCopy.Snapshot.toggleLabel,
                helper: MomentumCopy.Snapshot.toggleHelper,
                options: MovementSnapshotOptInOption.all,
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
            persist(chosen.isOn)
        }
    }

    static func optionTitle(_ option: MovementSnapshotOptInOption) -> String {
        option.isOn ? MomentumCopy.Snapshot.toggleOptionOn : MomentumCopy.Snapshot.toggleOptionOff
    }

    /// Copies `WorkoutFrequencyView.persist`/`MomentumTargetView.persist`'s isolation discipline
    /// exactly: only `HealthDataStore.saveMovementSnapshotOptIn`, never any Momentum ledger or
    /// reconciliation type -- this is a preference write, not a Momentum read.
    private func persist(_ optIn: Bool) {
        let store = HealthDataStore(context: modelContext)
        do {
            try store.saveMovementSnapshotOptIn(optIn)
            showSaveError = false
        } catch {
            showSaveError = true
        }
    }
}
