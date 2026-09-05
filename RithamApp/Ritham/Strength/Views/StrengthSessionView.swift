import SwiftData
import SwiftUI
import RithamCore

// STRENGTH-01/02/03/04's strength-logging surface: exercise selection via `ExercisePickerView`,
// set entry with previous-session auto-fill, and (added by plan 02-11's Task 3) superset building
// and session save. Saves through `HealthDataStore.saveLiftSession` (plan 02-08's accessor) on
// finish and adds no persistence code of its own -- this file never touches `HealthDataStore.swift`.
//
// T-02-11: pre-fill comes solely from `HealthDataStore.autoFillSet(forExercise:)`, which delegates
// to the unit-tested `LiftSession.mostRecentSet` selection rule. This screen never filters or
// falls back on its own -- an exercise never logged before pre-fills nothing rather than a
// plausible-looking default.

/// Drives `StrengthSessionView`'s behavior at the model level, so `StrengthSetEntryTests` and
/// later suites in this same file can assert every behavior in the plan's `<behavior>` lists
/// without rendering the view.
@MainActor
@Observable
final class StrengthSessionModel {
    private(set) var session: LiftSession
    private(set) var exerciseOrder: [String]

    private let store: HealthDataStore

    init(session: LiftSession = LiftSession(startedAt: Date()), store: HealthDataStore) {
        self.session = session
        self.store = store
        self.exerciseOrder = Self.orderedExerciseIdentifiers(in: session)
    }

    private static func orderedExerciseIdentifiers(in session: LiftSession) -> [String] {
        var seen = Set<String>()
        var order: [String] = []
        for set in session.sets where !seen.contains(set.exerciseIdentifier) {
            seen.insert(set.exerciseIdentifier)
            order.append(set.exerciseIdentifier)
        }
        return order
    }

    /// Selecting an exercise adds it to the in-progress session -- a no-op if it's already
    /// present, so re-selecting the same exercise from the picker never duplicates its section.
    func addExercise(_ identifier: String) {
        guard !exerciseOrder.contains(identifier) else { return }
        exerciseOrder.append(identifier)
    }

    /// Every logged set for `identifier`, in the order they were added.
    func sets(for identifier: String) -> [LiftSet] {
        session.sets.filter { $0.exerciseIdentifier == identifier }
    }

    /// STRENGTH-01's pre-fill source: delegates entirely to the store, which itself delegates to
    /// `LiftSession.mostRecentSet(forExercise:in:)`. Returns `nil` for an exercise never logged
    /// before, or when every prior set for it was a warm-up -- both cases the store's own method
    /// already resolves, so this method performs no filtering or fallback of its own.
    func autoFillDraft(forExercise identifier: String) -> LiftSet? {
        try? store.autoFillSet(forExercise: identifier)
    }

    /// Appends a new working (or warm-up) set to the in-progress session. `weightKg`/`reps` are
    /// whatever the caller passes -- including an edited pre-fill value, which is what actually
    /// gets stored here, never the pre-fill itself.
    @discardableResult
    func addSet(
        exerciseIdentifier: String,
        weightKg: Double?,
        reps: Int,
        isWarmUp: Bool,
        equipment: Equipment? = nil
    ) -> LiftSet {
        addExercise(exerciseIdentifier)
        let set = LiftSet(
            exerciseIdentifier: exerciseIdentifier,
            weightKg: weightKg,
            reps: reps,
            isWarmUp: isWarmUp,
            equipment: equipment,
            orderIndex: session.sets.count,
            completedAt: Date()
        )
        session.sets.append(set)
        return set
    }
}

struct StrengthSessionView: View, OnboardingStepPresenting {
    static let step: OnboardingStep = .strengthSession

    static func makeView(flow: OnboardingFlow) -> AnyView {
        AnyView(StrengthSessionView(flow: flow))
    }

    /// A screen-local draft for the set-entry fields of one exercise -- pure UI state, never a
    /// calculation: the domain and persistence sides only ever see the fully-formed `LiftSet`
    /// `logSet(_:model:)` builds once this draft is submitted.
    struct SetDraft: Equatable {
        var weightText = ""
        var repsText = ""
        var isWarmUp = false
    }

    let flow: OnboardingFlow
    @Environment(\.modelContext) private var modelContext

    @State private var model: StrengthSessionModel?
    @State private var isPresentingPicker = false
    @State private var drafts: [String: SetDraft] = [:]

    var body: some View {
        RithamScreen(surface: DecorativeSurface.flat, headline: "Strength session") {
            if let model {
                ForEach(model.exerciseOrder, id: \.self) { identifier in
                    exerciseSection(identifier, model: model)
                }
            }

            PrimaryCTAButton(title: "Add exercise") {
                isPresentingPicker = true
            }
        }
        .onAppear(perform: setup)
        .sheet(isPresented: $isPresentingPicker) {
            ExercisePickerView { exercise in
                model?.addExercise(exercise.identifier)
            }
        }
    }

    private func setup() {
        guard model == nil else { return }
        model = StrengthSessionModel(store: HealthDataStore(context: modelContext))
    }

    // MARK: - Exercise section

    @ViewBuilder
    private func exerciseSection(_ identifier: String, model: StrengthSessionModel) -> some View {
        VStack(alignment: .leading, spacing: RithamSpacing.sm) {
            Text(exerciseDisplayName(identifier))
                .font(RithamType.body.weight(.semibold))
                .foregroundStyle(RithamColor.paper)

            Text(patternsLabel(identifier))
                .font(RithamType.label)
                .foregroundStyle(RithamColor.paper.opacity(0.7))

            ForEach(model.sets(for: identifier)) { set in
                setRow(set)
            }

            setEntryForm(identifier, model: model)
        }
        .padding(RithamSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: RithamSpacing.sm)
                .stroke(RithamColor.paper.opacity(0.3), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func setRow(_ set: LiftSet) -> some View {
        HStack(spacing: RithamSpacing.sm) {
            Text(set.weightKg.map { "\(formattedWeight($0)) kg" } ?? "Bodyweight")
            Text("\u{00d7} \(set.reps)")
            if set.isWarmUp {
                Text("Warm-up")
                    .font(RithamType.label)
            }
        }
        .font(RithamType.body)
        .modifier(RithamType.numerals())
        .foregroundStyle(RithamColor.paper)
    }

    // MARK: - Set entry

    @ViewBuilder
    private func setEntryForm(_ identifier: String, model: StrengthSessionModel) -> some View {
        let binding = draftBinding(for: identifier, model: model)

        HStack(spacing: RithamSpacing.sm) {
            TextField("Weight (kg)", text: binding.weightText)
                .keyboardType(.decimalPad)
                .font(RithamType.body)
                .foregroundStyle(RithamColor.paper)
                .padding(RithamSpacing.sm)
                .frame(minHeight: RithamSpacing.minimumTapTarget)
                .background(
                    RoundedRectangle(cornerRadius: RithamSpacing.sm)
                        .stroke(RithamColor.paper, lineWidth: 1)
                )

            TextField("Reps", text: binding.repsText)
                .keyboardType(.numberPad)
                .font(RithamType.body)
                .foregroundStyle(RithamColor.paper)
                .padding(RithamSpacing.sm)
                .frame(minHeight: RithamSpacing.minimumTapTarget)
                .background(
                    RoundedRectangle(cornerRadius: RithamSpacing.sm)
                        .stroke(RithamColor.paper, lineWidth: 1)
                )
        }

        Toggle("Warm-up", isOn: binding.isWarmUp)
            .foregroundStyle(RithamColor.paper)

        SecondaryCTAButton(title: "Log set") {
            logSet(identifier, model: model)
        }
    }

    /// Reads/writes `drafts[identifier]`, seeding it once from `model.autoFillDraft(forExercise:)`
    /// the first time this exercise's form is shown -- an exercise never logged before seeds an
    /// empty draft rather than a misleading default (T-02-11). Editing the returned binding before
    /// `logSet` submits it is what carries an edited value forward instead of the pre-fill.
    private func draftBinding(for identifier: String, model: StrengthSessionModel) -> Binding<SetDraft> {
        Binding(
            get: { drafts[identifier] ?? seedDraft(for: identifier, model: model) },
            set: { drafts[identifier] = $0 }
        )
    }

    private func seedDraft(for identifier: String, model: StrengthSessionModel) -> SetDraft {
        guard let previous = model.autoFillDraft(forExercise: identifier) else {
            return SetDraft()
        }
        return SetDraft(
            weightText: previous.weightKg.map(formattedWeight) ?? "",
            repsText: String(previous.reps),
            isWarmUp: false
        )
    }

    private func logSet(_ identifier: String, model: StrengthSessionModel) {
        let draft = drafts[identifier] ?? seedDraft(for: identifier, model: model)
        guard let reps = Int(draft.repsText), reps > 0 else { return }
        let weight = Double(draft.weightText)

        model.addSet(exerciseIdentifier: identifier, weightKg: weight, reps: reps, isWarmUp: draft.isWarmUp)
        drafts[identifier] = SetDraft()
    }

    // MARK: - Formatting

    private func exerciseDisplayName(_ identifier: String) -> String {
        ExerciseCatalog.definition(for: identifier)?.displayName ?? identifier
    }

    /// Read-only presentation of an exercise's auto-assigned patterns -- STRENGTH-04 requires no
    /// control that lets a user pick or change one.
    private func patternsLabel(_ identifier: String) -> String {
        ExerciseCatalog.patterns(for: identifier)
            .sorted { $0.rawValue < $1.rawValue }
            .map(\.displayName)
            .joined(separator: " \u{00b7} ")
    }

    private func formattedWeight(_ weightKg: Double) -> String {
        weightKg.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", weightKg)
            : String(format: "%.2f", weightKg)
    }
}
