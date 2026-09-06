// RECOVERY-01's daily sleep check-in screen. This is a single-purpose screen, per RECOVERY-01
// invariant 6 (03-UI-SPEC.md's "RECOVERY-01 -- UI Invariants" list, item 6): it must contain no
// button, link, label or mention of shields, Recovery Week, streak state or milestones anywhere
// on it. Everything below is the sleep-quality chip picker, an optional note, a save action, and
// the shared save-error string -- nothing else. `RecoveryAdjustmentTests.theSleepScreenMentions
// NoMomentumState` pins this by scanning this file's own non-comment source for the banned
// tokens.
//
// Fully skippable, per RECOVERY-01 invariant 3: nothing here persists until the primary CTA is
// tapped, so navigating away (the shared `NavigationStack`'s own back gesture/button) without
// selecting anything writes nothing and has no consequence anywhere else in the app. There is no
// "you must answer" guard and no blocking dismissal.
import SwiftUI
import RithamCore

/// A UI-layer wrapper around `SleepQuality`, following the exact precedent
/// `WeeklyFrequencyOption`/`MomentumTargetOption` already establish for this codebase: a bare
/// domain enum has no natural single UI-option identity of its own for `ChoiceQuestionView`'s
/// `Hashable & Identifiable` requirement, and `SleepQuality` (RithamCore) is not `Hashable` --
/// only `Equatable`. Rather than retroactively conforming a cross-module type to `Hashable` (a
/// manual `hash(into:)` implementation with no compiler-synthesis help, since synthesis only
/// applies to same-file declarations), this wrapper implements the equivalence itself over the
/// stable `rawValue`, matching the two precedents' own "wrapper type rather than a retroactive
/// conformance" choice.
struct SleepQualityOption: Hashable, Identifiable {
    let quality: SleepQuality
    var id: String { quality.rawValue }

    static func == (lhs: SleepQualityOption, rhs: SleepQualityOption) -> Bool {
        lhs.quality == rhs.quality
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(quality.rawValue)
    }

    /// The three supported choices, in `SleepQuality`'s own declaration order (Great, OK, Poor).
    static let all: [SleepQualityOption] = SleepQuality.allCases.map(SleepQualityOption.init)
}

struct SleepCheckInView: View, OnboardingStepPresenting {
    static let step: OnboardingStep = .sleepCheckIn

    static func makeView(flow: OnboardingFlow) -> AnyView {
        AnyView(SleepCheckInView(flow: flow))
    }

    let flow: OnboardingFlow

    @Environment(\.modelContext) private var modelContext
    @State private var selection: Set<SleepQualityOption> = []
    @State private var note: String = ""
    @State private var showSaveError = false

    var body: some View {
        RithamScreen(surface: DecorativeSurface.flat, headline: MomentumCopy.Sleep.headline) {
            ChoiceQuestionView(
                prompt: MomentumCopy.Sleep.headline,
                options: SleepQualityOption.all,
                mode: .single,
                selection: $selection,
                optionTitle: Self.optionTitle
            )

            VStack(alignment: .leading, spacing: RithamSpacing.sm) {
                Text(MomentumCopy.Sleep.noteFieldLabel)
                    .font(RithamType.label)
                    .foregroundStyle(RithamColor.paper)

                // A plain, no-character-count TextField -- 03-UI-SPEC.md Component 6 forbids any
                // length-pressure UI on this optional field.
                TextField("", text: $note, axis: .vertical)
                    .font(RithamType.body)
                    .foregroundStyle(RithamColor.paper)
                    .padding(RithamSpacing.sm)
                    .overlay(
                        RoundedRectangle(cornerRadius: RithamSpacing.sm)
                            .stroke(RithamColor.paper.opacity(0.2), lineWidth: 1)
                    )
            }

            if showSaveError {
                Text(OnboardingCopy.Errors.savingFailed)
                    .font(RithamType.label)
                    .foregroundStyle(RithamColor.hot)
                    .fixedSize(horizontal: false, vertical: true)
            }

            PrimaryCTAButton(title: "Done") {
                save()
            }
        }
    }

    /// Saves through `HealthDataStore.saveSleepCheckIn` only when an option was actually chosen,
    /// then returns to the hub. When nothing was selected, this returns to the hub without
    /// touching the store at all -- the same "skip has zero effect" behavior
    /// `dismissingWithoutSelectionWritesNoRow` (RecoveryAdjustmentTests) pins at the pure-function
    /// level via `pendingCheckIn(selection:note:day:)` below.
    private func save() {
        guard let checkIn = Self.pendingCheckIn(selection: selection, note: note, day: Date()) else {
            flow.returnToHub()
            return
        }
        let store = HealthDataStore(context: modelContext)
        do {
            try store.saveSleepCheckIn(checkIn)
            showSaveError = false
            flow.returnToHub()
        } catch {
            showSaveError = true
        }
    }

    private static func optionTitle(_ option: SleepQualityOption) -> String {
        switch option.quality {
        case .great: return MomentumCopy.Sleep.optionGreat
        case .ok: return MomentumCopy.Sleep.optionOK
        case .poor: return MomentumCopy.Sleep.optionPoor
        }
    }
}

// MARK: - Pure, testable derivation (see MomentumView.swift's header for why this must be
// `nonisolated`: SwiftUI's `View` protocol is itself `@MainActor`, which infers `@MainActor`
// isolation onto every member of a conforming type by default, and Swift Testing runs test
// functions off the main actor.)

extension SleepCheckInView {
    /// The check-in that should be persisted for a given selection/note/day, or `nil` when
    /// nothing was selected. Dismissing without choosing an option must persist nothing
    /// (RECOVERY-01 invariant 3) -- this function is the single source of that decision, called
    /// by `save()` above and exercised directly by
    /// `RecoveryAdjustmentTests.dismissingWithoutSelectionWritesNoRow` without needing a
    /// `ModelContext` or rendering the view.
    nonisolated static func pendingCheckIn(selection: Set<SleepQualityOption>, note: String, day: Date) -> SleepCheckIn? {
        guard let chosen = selection.first?.quality else { return nil }
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        return SleepCheckIn(day: day, quality: chosen, note: trimmedNote.isEmpty ? nil : trimmedNote)
    }
}
