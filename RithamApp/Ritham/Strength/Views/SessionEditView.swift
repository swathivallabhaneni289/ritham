import SwiftUI
import RithamCore

// STRENGTH-05's retroactive editing: a past session's sets, weight, reps, and warm-up flag can be
// edited after the fact, and two sessions can be merged or one split, in a dedicated screen
// presented as a sheet -- the same discipline `EditAnswerFlow` (Phase 1) already established for
// a scoped retroactive edit, and deliberately not a push, since a merge or split is destructive
// in a way live logging (`StrengthSessionView`) never is (T-02-09, T-02-43).
//
// Every revision delegates to the pure `SessionRevision.merge`/`.split` functions and persists
// through the single `HealthDataStore.applyRevision(_:replacing:)` write path -- this file
// performs no merge or split arithmetic of its own, so the identity-partition invariant proved in
// `SessionRevisionTests` (RithamCoreTests) and the behaviour that consumes it are never allowed to
// drift apart (T-02-09). Editing a field mutates the existing `LiftSet` value in place rather than
// constructing a fresh one, so `id` -- and therefore superset membership and any later revision's
// identity -- survives (T-02-45).

/// Drives `SessionEditView`'s behavior at the model level, so `SessionRevisionScreenTests` can
/// assert every behavior in the plan's `<behavior>` list without rendering the view.
@MainActor
@Observable
final class SessionEditModel {
    private(set) var session: LiftSession

    /// A merge or split staged for confirmation. Non-nil only between `requestMerge`/
    /// `requestSplit` and either `confirmRevision()` or `abandonRevision()` -- nothing is written
    /// to the store while this holds a value, and `abandonRevision()` clears it without writing
    /// anything at all (T-02-43).
    private(set) var pendingRevision: PendingRevision?

    /// A short explanation set when `requestMerge`/`requestSplit` is refused -- splitting at the
    /// first set or past the last set, and merging a session with itself, are refusals rather
    /// than errors, and this is what a screen shows instead of silently doing nothing or
    /// producing an empty session (T-02-44).
    private(set) var refusalMessage: String?

    private let store: HealthDataStore

    init(session: LiftSession, store: HealthDataStore) {
        self.session = session
        self.store = store
    }

    enum PendingRevision: Equatable {
        case merge(firstID: UUID, secondID: UUID, merged: LiftSession)
        case split(originalID: UUID, first: LiftSession, second: LiftSession)
    }

    // MARK: - Editing

    /// Mutates field values on the set already at `index` -- never rebuilds it -- so its `id`
    /// survives unchanged (T-02-45). A missing index is a no-op.
    func updateSet(at index: Int, weightKg: Double?, reps: Int, isWarmUp: Bool) {
        guard session.sets.indices.contains(index) else { return }
        session.sets[index].weightKg = weightKg
        session.sets[index].reps = reps
        session.sets[index].isWarmUp = isWarmUp
    }

    func updateDate(_ date: Date) {
        session.startedAt = date
    }

    /// Persists the in-place edits above. Merge and split never go through this method -- they
    /// write only via `confirmRevision()`, gated on an explicit confirmation.
    func save() throws {
        try store.saveLiftSession(session)
    }

    // MARK: - Merge

    /// Stages a merge with `other` for confirmation. Refuses (setting `refusalMessage`, staging
    /// nothing) when `other` is this same session -- `SessionRevision.merge` returns `nil` for
    /// that case by design, and this is the refusal-with-explanation that nil becomes here rather
    /// than falling through to any write.
    func requestMerge(with other: LiftSession) {
        refusalMessage = nil
        guard let merged = SessionRevision.merge(session, other) else {
            refusalMessage = "This is the same session -- there's nothing to merge it with."
            return
        }
        pendingRevision = .merge(firstID: session.id, secondID: other.id, merged: merged)
    }

    // MARK: - Split

    /// Stages a split at `index` for confirmation. Refuses (setting `refusalMessage`, staging
    /// nothing) for a split at the first set or at/past the last set -- `SessionRevision.split`
    /// returns `nil` for both, which never falls through to producing an empty session here.
    func requestSplit(atSetIndex index: Int) {
        refusalMessage = nil
        guard let (first, second) = SessionRevision.split(session, atSetIndex: index) else {
            refusalMessage = "Can't split there -- choose a set that isn't the first, and isn't past the last."
            return
        }
        pendingRevision = .split(originalID: session.id, first: first, second: second)
    }

    // MARK: - Confirmation

    /// Applies the staged merge or split through `HealthDataStore.applyRevision(_:replacing:)` --
    /// the single write path for a revision. Writes no merge/split arithmetic itself; the
    /// revision arrived already-computed from `SessionRevision`.
    func confirmRevision() throws {
        guard let pendingRevision else { return }
        switch pendingRevision {
        case let .merge(firstID, secondID, merged):
            try store.applyRevision([merged], replacing: [firstID, secondID])
        case let .split(originalID, first, second):
            try store.applyRevision([first, second], replacing: [originalID])
        }
        self.pendingRevision = nil
    }

    /// Abandons the staged merge or split. A no-op with respect to the store -- nothing is
    /// written (T-02-43).
    func abandonRevision() {
        pendingRevision = nil
    }
}

struct SessionEditView: View {
    let session: LiftSession
    let mergeCandidates: [LiftSession]
    let store: HealthDataStore

    @Environment(\.dismiss) private var dismiss

    @State private var model: SessionEditModel?
    @State private var isConfirmingRevision = false
    @State private var showSaveError = false

    var body: some View {
        RithamScreen(surface: DecorativeSurface.flat, headline: "Edit session") {
            if let model {
                dateEditor(model)

                VStack(alignment: .leading, spacing: RithamSpacing.md) {
                    ForEach(Array(model.session.sets.enumerated()), id: \.element.id) { index, set in
                        setRow(index: index, set: set, model: model)
                    }
                }

                if let refusalMessage = model.refusalMessage {
                    Text(refusalMessage)
                        .font(RithamType.label)
                        .foregroundStyle(RithamColor.paper)
                }

                mergeSection(model)
                splitSection(model)

                PrimaryCTAButton(title: "Save changes") {
                    saveEdits(model)
                }
            }

            SecondaryCTAButton(title: "Cancel") {
                dismiss()
            }
        }
        .onAppear {
            model = SessionEditModel(session: session, store: store)
        }
        .confirmationDialog(
            "This can't be undone once applied. Apply this change?",
            isPresented: $isConfirmingRevision,
            titleVisibility: .visible
        ) {
            Button("Apply", role: .destructive) {
                applyRevision(model)
            }
            Button("Cancel", role: .cancel) {
                model?.abandonRevision()
            }
        }
        .alert("Couldn't save your changes.", isPresented: $showSaveError) {
            Button("OK", role: .cancel) {}
        }
    }

    // MARK: - Date

    @ViewBuilder
    private func dateEditor(_ model: SessionEditModel) -> some View {
        DatePicker(
            "Date",
            selection: Binding(
                get: { model.session.startedAt },
                set: { model.updateDate($0) }
            ),
            displayedComponents: .date
        )
        .foregroundStyle(RithamColor.paper)
    }

    // MARK: - Sets

    @ViewBuilder
    private func setRow(index: Int, set: LiftSet, model: SessionEditModel) -> some View {
        VStack(alignment: .leading, spacing: RithamSpacing.xs) {
            Text(set.exerciseIdentifier)
                .font(RithamType.label)
                .foregroundStyle(RithamColor.paper)

            HStack(spacing: RithamSpacing.sm) {
                TextField(
                    "Weight (kg)",
                    text: Binding(
                        get: { set.weightKg.map { String($0) } ?? "" },
                        set: { newValue in
                            model.updateSet(at: index, weightKg: Double(newValue), reps: set.reps, isWarmUp: set.isWarmUp)
                        }
                    )
                )
                .keyboardType(.decimalPad)
                .foregroundStyle(RithamColor.paper)

                TextField(
                    "Reps",
                    value: Binding(
                        get: { set.reps },
                        set: { newValue in
                            model.updateSet(at: index, weightKg: set.weightKg, reps: newValue, isWarmUp: set.isWarmUp)
                        }
                    ),
                    format: .number
                )
                .keyboardType(.numberPad)
                .foregroundStyle(RithamColor.paper)
            }

            Toggle(
                "Warm-up",
                isOn: Binding(
                    get: { set.isWarmUp },
                    set: { newValue in
                        model.updateSet(at: index, weightKg: set.weightKg, reps: set.reps, isWarmUp: newValue)
                    }
                )
            )
            .tint(RithamColor.hot)
            .foregroundStyle(RithamColor.paper)
        }
        .padding(RithamSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: RithamSpacing.sm)
                .stroke(RithamColor.paper.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Merge

    @ViewBuilder
    private func mergeSection(_ model: SessionEditModel) -> some View {
        if !mergeCandidates.isEmpty {
            VStack(alignment: .leading, spacing: RithamSpacing.sm) {
                Text("Merge with another session")
                    .font(RithamType.label)
                    .foregroundStyle(RithamColor.paper)

                ForEach(mergeCandidates, id: \.id) { candidate in
                    SecondaryCTAButton(
                        title: "Merge with \(candidate.startedAt.formatted(date: .abbreviated, time: .shortened))"
                    ) {
                        model.requestMerge(with: candidate)
                        // Only prompt for confirmation when the merge was actually staged --
                        // a refusal (merging a session with itself) leaves `pendingRevision`
                        // nil and shows `refusalMessage` instead, never a confirmation dialog
                        // with nothing behind it.
                        isConfirmingRevision = model.pendingRevision != nil
                    }
                }
            }
        }
    }

    // MARK: - Split

    @ViewBuilder
    private func splitSection(_ model: SessionEditModel) -> some View {
        if model.session.sets.count > 1 {
            VStack(alignment: .leading, spacing: RithamSpacing.sm) {
                Text("Split this session")
                    .font(RithamType.label)
                    .foregroundStyle(RithamColor.paper)

                ForEach(Array(model.session.sets.enumerated()), id: \.element.id) { index, set in
                    SecondaryCTAButton(title: "Split before set \(index + 1) (\(set.exerciseIdentifier))") {
                        model.requestSplit(atSetIndex: index)
                        // Same discipline as the merge button above: a refusal (first set, or
                        // at/past the last set) leaves `pendingRevision` nil, so no dialog
                        // appears over nothing.
                        isConfirmingRevision = model.pendingRevision != nil
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func saveEdits(_ model: SessionEditModel) {
        do {
            try model.save()
            dismiss()
        } catch {
            showSaveError = true
        }
    }

    private func applyRevision(_ model: SessionEditModel?) {
        guard let model else { return }
        do {
            try model.confirmRevision()
            dismiss()
        } catch {
            showSaveError = true
        }
    }
}
