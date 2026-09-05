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

    // MARK: - Superset building (Task 3)

    /// The superset group, if any, every *working* set for `identifier` currently shares. `join`
    /// always assigns the same group ID to every matching working set in one call, so reading the
    /// first working set's group is sufficient -- there is never a mixed-membership exercise.
    func groupID(forExercise identifier: String) -> SupersetGroupID? {
        session.sets.first { $0.exerciseIdentifier == identifier && !$0.isWarmUp }?.supersetGroupID
    }

    /// Whether `identifier` has at least one working (non-warm-up) set. `SupersetGrouping.join`
    /// only ever assigns a group to a *set*, never to a bare exercise-order entry -- so joining an
    /// exercise with no working sets yet would silently do nothing (no set exists to receive the
    /// group ID). The view gates its join action on this so the action never no-ops.
    func hasWorkingSets(forExercise identifier: String) -> Bool {
        session.workingSets.contains { $0.exerciseIdentifier == identifier }
    }

    /// Joins `exerciseIdentifiers` into one superset in a single step -- STRENGTH-03's stated
    /// interaction, with no separate create-a-superset flow. Delegates entirely to
    /// `SupersetGrouping.join`, which never recreates a set: every set's `id` is unchanged.
    func joinIntoSuperset(_ exerciseIdentifiers: [String]) {
        session = SupersetGrouping.join(exerciseIdentifiers: exerciseIdentifiers, in: session, groupID: SupersetGroupID())
    }

    /// Restores every set in `groupID` to standalone. Delegates entirely to
    /// `SupersetGrouping.ungroup`, which never recreates a set.
    func ungroup(_ groupID: SupersetGroupID) {
        session = SupersetGrouping.ungroup(groupID, in: session)
    }

    func supersetGroups() -> [SupersetGroup] {
        SupersetGrouping.groups(in: session)
    }

    // MARK: - Qualification and finish (Task 3)

    /// Reads the shared domain evaluation rather than counting sets or exercises itself -- the
    /// qualifying-bar thresholds live in exactly one place (`CalibrationThreshold`, via
    /// `LiftQualification.evaluate`).
    var qualification: LiftQualification {
        LiftQualification.evaluate(session)
    }

    /// Applies the plate calculator's achievable weight to one specific already-logged set --
    /// never the raw typed target, per `PlateCalculatorView`'s own contract.
    func updateWeight(forSetID id: UUID, to weightKg: Double) {
        guard let index = session.sets.firstIndex(where: { $0.id == id }) else { return }
        session.sets[index].weightKg = weightKg
    }

    /// Saves the in-progress session through the shared store accessor plan 02-08 added. Performs
    /// no persistence logic of its own beyond the single `saveLiftSession` call.
    @discardableResult
    func finish() throws -> LiftSession {
        try store.saveLiftSession(session)
        return session
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
    @State private var presentedPlateCalculatorSet: LiftSet?

    /// HEALTH-03's inline workout guidance for this screen -- see `CardioSessionView`'s identical
    /// field for the full rationale on when this is (re)built.
    @State private var guidanceContext: GuidanceContext?

    var body: some View {
        RithamScreen(surface: DecorativeSurface.flat, headline: "Strength session") {
            guidanceSection

            if let model {
                qualificationBanner(model)

                ForEach(Array(displaySections(model).enumerated()), id: \.offset) { _, group in
                    // Branches on group *membership* (a non-nil group ID), not on `group.count`:
                    // a superset can transiently hold just one remaining member after an earlier
                    // member is re-joined elsewhere, and that lone member must still render with
                    // its Ungroup action rather than falling back to the plain exercise section,
                    // which offers no way to clear its group ID.
                    if let first = group.first, model.groupID(forExercise: first) != nil {
                        supersetBlock(group, model: model)
                    } else if let identifier = group.first {
                        exerciseSection(identifier, model: model)
                    }
                }

                PrimaryCTAButton(title: "Finish") {
                    finish(model)
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
        .sheet(item: $presentedPlateCalculatorSet) { set in
            PlateCalculatorView(
                equipment: set.equipment ?? .standardBarbell,
                currentWeightKg: set.weightKg,
                currentReps: set.reps
            ) { achievableWeightKg in
                model?.updateWeight(forSetID: set.id, to: achievableWeightKg)
            }
        }
    }

    private func setup() {
        if model == nil {
            model = StrengthSessionModel(store: HealthDataStore(context: modelContext))
        }
        if guidanceContext == nil {
            guidanceContext = GuidanceContext(context: modelContext)
        }
    }

    // MARK: - Guidance

    /// HEALTH-03's workout guidance, shown inline above every logging control on this screen --
    /// exercise picker, set entry, superset actions, and finish -- never gating any of them.
    @ViewBuilder
    private var guidanceSection: some View {
        if let guidanceContext {
            AdjustedGuidanceBanner(context: guidanceContext, domain: .workout)
        }
    }

    private func finish(_ model: StrengthSessionModel) {
        try? model.finish()
        flow.returnToHub()
    }

    // MARK: - Qualification

    private func qualificationBanner(_ model: StrengthSessionModel) -> some View {
        Text(
            model.qualification == .complete
                ? "This session meets the qualifying bar."
                : "Keep going -- this session doesn't meet the qualifying bar yet."
        )
        .font(RithamType.label)
        .foregroundStyle(RithamColor.paper)
    }

    // MARK: - Section grouping

    /// Every displayed section, in `exerciseOrder`: a single-element array for a standalone
    /// exercise, or a multi-element array (in `exerciseOrder`'s own relative order) for every
    /// exercise sharing one superset group -- the "one visually grouped block" STRENGTH-03 asks
    /// for, derived purely from `groupID(forExercise:)` reads, never a separate grouping model of
    /// this view's own.
    private func displaySections(_ model: StrengthSessionModel) -> [[String]] {
        var sections: [[String]] = []
        var visited = Set<String>()

        for identifier in model.exerciseOrder where !visited.contains(identifier) {
            if let groupID = model.groupID(forExercise: identifier) {
                let members = model.exerciseOrder.filter { model.groupID(forExercise: $0) == groupID }
                sections.append(members)
                visited.formUnion(members)
            } else {
                sections.append([identifier])
                visited.insert(identifier)
            }
        }
        return sections
    }

    private func nextExerciseIdentifier(after identifier: String, model: StrengthSessionModel) -> String? {
        guard
            let index = model.exerciseOrder.firstIndex(of: identifier),
            model.exerciseOrder.indices.contains(index + 1)
        else { return nil }
        return model.exerciseOrder[index + 1]
    }

    /// The next exercise to join with, only when *both* sides already have a working set to carry
    /// the group ID -- `SupersetGrouping.join` assigns a group to sets, never to a bare
    /// exercise-order entry, so offering the action before either side has logged one would be a
    /// tap that silently does nothing.
    private func joinableNextExerciseIdentifier(after identifier: String, model: StrengthSessionModel) -> String? {
        guard
            model.hasWorkingSets(forExercise: identifier),
            let next = nextExerciseIdentifier(after: identifier, model: model),
            model.hasWorkingSets(forExercise: next)
        else { return nil }
        return next
    }

    // MARK: - Exercise section

    @ViewBuilder
    private func exerciseSection(_ identifier: String, model: StrengthSessionModel) -> some View {
        VStack(alignment: .leading, spacing: RithamSpacing.sm) {
            exerciseContent(identifier, model: model)

            if let next = joinableNextExerciseIdentifier(after: identifier, model: model) {
                SecondaryCTAButton(title: "Join with next exercise") {
                    model.joinIntoSuperset([identifier, next])
                }
            }
        }
        .padding(RithamSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: RithamSpacing.sm)
                .stroke(RithamColor.paper.opacity(0.3), lineWidth: 1)
        )
    }

    /// One visually grouped block for every exercise sharing a superset group -- STRENGTH-03's
    /// "no separate creation step" also means this is the same `exerciseContent` a standalone
    /// section renders, just gathered under one bordered container with a single ungroup action.
    @ViewBuilder
    private func supersetBlock(_ identifiers: [String], model: StrengthSessionModel) -> some View {
        VStack(alignment: .leading, spacing: RithamSpacing.sm) {
            Text("Superset")
                .font(RithamType.label)
                .foregroundStyle(RithamColor.hot)

            ForEach(identifiers, id: \.self) { identifier in
                exerciseContent(identifier, model: model)
            }

            SecondaryCTAButton(title: "Ungroup") {
                if let groupID = identifiers.first.flatMap(model.groupID(forExercise:)) {
                    model.ungroup(groupID)
                }
            }
        }
        .padding(RithamSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: RithamSpacing.sm)
                .stroke(RithamColor.hot, lineWidth: 2)
        )
    }

    @ViewBuilder
    private func exerciseContent(_ identifier: String, model: StrengthSessionModel) -> some View {
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

            SecondaryCTAButton(title: "Plate calculator") {
                presentedPlateCalculatorSet = set
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
