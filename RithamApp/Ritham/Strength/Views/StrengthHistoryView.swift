import SwiftUI
import RithamCore

// STRENGTH-04's history: past strength sessions, most recent first, with a multi-select
// movement-pattern filter. Loads through the store accessors plan 02-08 added and adds no
// persistence code of its own.
//
// The filter tests `LiftSession.movementPatterns` -- the union across a session's working sets
// (`LiftSession.swift`) -- never a per-exercise `ExerciseCatalog.patterns(for:)` lookup here.
// That union is what makes a compound lift (e.g. a thruster) appear under every pattern it
// trains, rather than being mis-filed under only one.
//
// Two empty states are kept deliberately distinct: no sessions stored at all (`isEmpty`) versus
// sessions stored but none matching the current filter (`hasNoResults`). Collapsing them into one
// state would make a working filter look like data loss.

/// Drives `StrengthHistoryView`'s behavior at the model level, so `StrengthHistoryFilterTests`
/// and later suites in this same file can assert every behavior in the plan's `<behavior>` lists
/// without rendering the view.
@MainActor
@Observable
final class StrengthHistoryModel {
    private(set) var sessions: [LiftSession] = []
    var selectedPatterns: Set<MovementPattern> = []

    /// Every stored session's `startedAt`, refreshed only by `load()` -- the single full-store
    /// read this model ever performs. `YearJumpDatePicker` derives its offered years and months
    /// from this list, never by loading the whole store again itself.
    private(set) var allSessionStartDates: [Date] = []

    /// The date range currently narrowing `sessions`, or `nil` when unfiltered. Tracked so a
    /// caller can tell whether a date jump is active.
    private(set) var selectedDateRange: ClosedRange<Date>?

    private let store: HealthDataStore

    init(store: HealthDataStore) {
        self.store = store
    }

    /// True only when the store has no strength sessions at all -- distinct from `hasNoResults`,
    /// which is a non-empty store narrowed by the current filter down to nothing.
    var isEmpty: Bool { sessions.isEmpty }

    /// The currently displayed sessions, narrowed to those whose `movementPatterns` union
    /// intersects `selectedPatterns`. An empty filter selection is "no filter" -- it shows every
    /// loaded session, never zero of them.
    var filteredSessions: [LiftSession] {
        guard !selectedPatterns.isEmpty else { return sessions }
        return sessions.filter { !$0.movementPatterns.isDisjoint(with: selectedPatterns) }
    }

    /// A working filter that matches nothing -- distinct from `isEmpty`.
    var hasNoResults: Bool {
        !sessions.isEmpty && filteredSessions.isEmpty
    }

    /// Loads every stored lift session, most recent first, and refreshes the date list
    /// `YearJumpDatePicker` offers years and months from. This is the only path in this model
    /// that reads the whole store -- `loadDateRange` below never does.
    func load() {
        sessions = (try? store.loadLiftSessions()) ?? []
        allSessionStartDates = sessions.map(\.startedAt)
        selectedDateRange = nil
    }

    /// Loads sessions within `range` through the store's date-range accessor -- never the
    /// full-store accessor -- so jumping to one month never pulls the whole history into memory.
    /// Passing `nil` clears the date selection and restores the unfiltered list via `load()`.
    func loadDateRange(_ range: ClosedRange<Date>?) {
        guard let range else {
            load()
            return
        }
        selectedDateRange = range
        sessions = (try? store.loadLiftSessions(in: range)) ?? []
    }

    func togglePattern(_ pattern: MovementPattern) {
        if selectedPatterns.contains(pattern) {
            selectedPatterns.remove(pattern)
        } else {
            selectedPatterns.insert(pattern)
        }
    }

    func clearPatternFilter() {
        selectedPatterns = []
    }
}

struct StrengthHistoryView: View, OnboardingStepPresenting {
    static let step: OnboardingStep = .strengthHistory

    static func makeView(flow: OnboardingFlow) -> AnyView {
        AnyView(StrengthHistoryView(flow: flow))
    }

    let flow: OnboardingFlow
    @Environment(\.modelContext) private var modelContext

    @State private var model: StrengthHistoryModel?

    var body: some View {
        RithamScreen(surface: DecorativeSurface.flat, headline: "Strength history") {
            if let model {
                YearJumpDatePicker(availableDates: model.allSessionStartDates) { range in
                    model.loadDateRange(range)
                }

                patternFilter(model)

                if model.isEmpty {
                    emptyHistoryState
                } else if model.hasNoResults {
                    noResultsState
                } else {
                    VStack(alignment: .leading, spacing: RithamSpacing.md) {
                        ForEach(model.filteredSessions, id: \.id) { session in
                            sessionRow(session)
                        }
                    }
                }
            }

            SecondaryCTAButton(title: "Back") {
                flow.goBack()
            }
        }
        .onAppear(perform: load)
    }

    // MARK: - Filter

    @ViewBuilder
    private func patternFilter(_ model: StrengthHistoryModel) -> some View {
        VStack(alignment: .leading, spacing: RithamSpacing.sm) {
            Text("Filter by movement pattern")
                .font(RithamType.label)
                .foregroundStyle(RithamColor.paper)

            HStack(spacing: RithamSpacing.sm) {
                ForEach(MovementPattern.allCases, id: \.self) { pattern in
                    ChoiceChip(
                        title: pattern.displayName,
                        isSelected: model.selectedPatterns.contains(pattern),
                        action: { model.togglePattern(pattern) }
                    )
                }
            }

            if !model.selectedPatterns.isEmpty {
                SecondaryCTAButton(title: "Clear filter") {
                    model.clearPatternFilter()
                }
            }
        }
    }

    // MARK: - Empty states

    private var emptyHistoryState: some View {
        VStack(alignment: .leading, spacing: RithamSpacing.sm) {
            Text("No strength sessions yet")
                .font(RithamType.display)
                .foregroundStyle(RithamColor.paper)
                .fixedSize(horizontal: false, vertical: true)

            Text("Sessions you log will show up here, most recent first.")
                .font(RithamType.body)
                .foregroundStyle(RithamColor.paper)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var noResultsState: some View {
        VStack(alignment: .leading, spacing: RithamSpacing.sm) {
            Text("No sessions match this filter")
                .font(RithamType.display)
                .foregroundStyle(RithamColor.paper)
                .fixedSize(horizontal: false, vertical: true)

            Text("Clear the filter above to see your full history.")
                .font(RithamType.body)
                .foregroundStyle(RithamColor.paper)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Session row

    @ViewBuilder
    private func sessionRow(_ session: LiftSession) -> some View {
        VStack(alignment: .leading, spacing: RithamSpacing.xs) {
            Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                .font(RithamType.label)
                .foregroundStyle(RithamColor.paper)

            Text("\(session.distinctWorkingExercises) exercises \u{00b7} \(session.workingSetCount) sets")
                .font(RithamType.body)
                .modifier(RithamType.numerals())
                .foregroundStyle(RithamColor.paper)

            Text(patternsLabel(session))
                .font(RithamType.label)
                .foregroundStyle(RithamColor.paper.opacity(0.7))
        }
        .padding(RithamSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: RithamSpacing.sm)
                .stroke(RithamColor.paper.opacity(0.3), lineWidth: 1)
        )
    }

    private func patternsLabel(_ session: LiftSession) -> String {
        session.movementPatterns
            .sorted { $0.rawValue < $1.rawValue }
            .map(\.displayName)
            .joined(separator: " \u{00b7} ")
    }

    // MARK: - Loading

    private func load() {
        let store = HealthDataStore(context: modelContext)
        let currentModel = model ?? StrengthHistoryModel(store: store)
        currentModel.load()
        model = currentModel
    }
}
