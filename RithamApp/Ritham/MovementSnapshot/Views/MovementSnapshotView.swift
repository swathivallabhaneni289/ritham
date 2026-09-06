import SwiftUI
import RithamCore

// MOMENTUM-07/D-09: the Daily Movement Snapshot's own registered step -- a plain calendar of
// days with logged activity, carrying no streak, shield, target or milestone of any kind.
//
// This whole feature lives in its own `RithamApp/Ritham/MovementSnapshot/` directory rather than
// under `RithamApp/Ritham/Momentum/` (the directory 03-RESEARCH.md's own suggested file placement
// names) -- a deliberate departure, made for exactly one reason: it turns "carries no streak,
// shield or target" from a per-file reading into a directory-scoped, mechanically checkable
// constraint. `theSnapshotScreenReferencesNoMomentumType` (MovementSnapshotViewTests.swift)
// scans every file under this directory for the Momentum summary type, the Momentum state
// record, the progress-block component, the shield row and the milestone list, and a
// directory-wide comment-filtered identifier grep gate backs the same assertion at the shell
// level (T-3-15's mitigation). A file living under `Momentum/` could still satisfy a per-file
// reading of the same rule, but would make that constraint something a reviewer has to keep
// re-checking by hand rather than something a `grep -r` over one directory answers once and for
// all.
//
// The marked/unmarked day distinction below deliberately never uses `RithamColor.hot`: in this
// phase's visual vocabulary, coral means "Momentum progress" (03-UI-SPEC.md's "Accent discipline,
// extended for this phase"), and this screen must carry none of that association. A marked day
// is distinguished by shape and opacity within the existing paper-and-ink field, never by an
// accent fill -- satisfying WCAG 1.4.1's "not color alone" the same way `ShieldRow`/
// `MomentumProgressBlocks` already do for their own filled/unfilled states, but with a palette
// this screen never shares with those types.

struct MovementSnapshotView: View, OnboardingStepPresenting {
    static let step: OnboardingStep = .movementSnapshot

    static func makeView(flow: OnboardingFlow) -> AnyView {
        AnyView(MovementSnapshotView())
    }

    @Environment(\.modelContext) private var modelContext
    @State private var displayedMonth: Date = Calendar(identifier: .gregorian).startOfDay(for: Date())
    @State private var days: [HealthDataStore.MovementSnapshotDay] = []

    private let calendar = Calendar(identifier: .gregorian)

    var body: some View {
        RithamScreen(surface: DecorativeSurface.flat, headline: "Daily Movement Snapshot") {
            monthNavigationRow

            if days.contains(where: \.hasLoggedActivity) {
                dayGrid
            } else {
                emptyState
            }
        }
        .onAppear(perform: loadCurrentMonth)
    }

    // MARK: - Month navigation

    private var monthNavigationRow: some View {
        HStack {
            Button {
                changeMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .frame(minWidth: RithamSpacing.minimumTapTarget, minHeight: RithamSpacing.minimumTapTarget)
            }

            Spacer()

            Text(Self.monthTitle(for: displayedMonth, calendar: calendar))
                .font(RithamType.body.weight(.semibold))
                .foregroundStyle(RithamColor.paper)

            Spacer()

            Button {
                changeMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .frame(minWidth: RithamSpacing.minimumTapTarget, minHeight: RithamSpacing.minimumTapTarget)
            }
        }
        .foregroundStyle(RithamColor.paper)
    }

    private func changeMonth(by delta: Int) {
        guard let next = calendar.date(byAdding: .month, value: delta, to: displayedMonth) else { return }
        displayedMonth = next
        loadCurrentMonth()
    }

    // MARK: - Day grid
    //
    // A plain grid, one cell per day in the displayed month. A marked (logged-activity) day is a
    // filled `RithamColor.paper` shape; an unmarked day is an outline-only shape at the same
    // opacity `MomentumProgressBlocks`/`ShieldRow` use for their own not-yet-earned state --
    // shape (filled vs. outline) plus opacity is the non-color-alone channel, never
    // `RithamColor.hot`.

    private var dayGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: RithamSpacing.xs), count: 7)
        return LazyVGrid(columns: columns, spacing: RithamSpacing.xs) {
            ForEach(days) { day in
                dayCell(day)
            }
        }
    }

    private func dayCell(_ day: HealthDataStore.MovementSnapshotDay) -> some View {
        Group {
            if day.hasLoggedActivity {
                RoundedRectangle(cornerRadius: RithamSpacing.xs)
                    .fill(RithamColor.paper)
            } else {
                RoundedRectangle(cornerRadius: RithamSpacing.xs)
                    .stroke(RithamColor.paper.opacity(0.2), lineWidth: 1)
            }
        }
        .frame(minHeight: RithamSpacing.minimumTapTarget)
        .overlay(
            Text(Self.dayNumber(for: day.date, calendar: calendar))
                .font(RithamType.label)
                .foregroundStyle(day.hasLoggedActivity ? RithamColor.label(on: RithamColor.paper) : RithamColor.paper)
        )
        .accessibilityLabel(Self.dayCellAccessibilityLabel(for: day))
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: RithamSpacing.xs) {
            Text(MomentumCopy.Empty.noSnapshotEntriesHeadline)
                .font(RithamType.body.weight(.semibold))
                .foregroundStyle(RithamColor.paper)
            Text(MomentumCopy.Empty.noSnapshotEntriesBody)
                .font(RithamType.label)
                .foregroundStyle(RithamColor.paper)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func loadCurrentMonth() {
        let store = HealthDataStore(context: modelContext, calendar: calendar)
        guard let range = Self.monthRange(containing: displayedMonth, calendar: calendar) else {
            days = []
            return
        }
        days = (try? store.movementSnapshotDays(in: range)) ?? []
    }
}

// MARK: - Pure, testable derivations

extension MovementSnapshotView {
    /// The closed date range spanning every calendar day in the month containing `date`, or
    /// `nil` if the calendar cannot resolve the month's interval.
    nonisolated static func monthRange(containing date: Date, calendar: Calendar) -> ClosedRange<Date>? {
        guard let interval = calendar.dateInterval(of: .month, for: date) else { return nil }
        let firstDay = calendar.startOfDay(for: interval.start)
        guard let lastDay = calendar.date(byAdding: .day, value: -1, to: interval.end) else { return nil }
        return firstDay...calendar.startOfDay(for: lastDay)
    }

    nonisolated static func monthTitle(for date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: date)
    }

    nonisolated static func dayNumber(for date: Date, calendar: Calendar) -> String {
        "\(calendar.component(.day, from: date))"
    }

    nonisolated static func dayCellAccessibilityLabel(for day: HealthDataStore.MovementSnapshotDay) -> String {
        let dateText = day.date.formatted(date: .abbreviated, time: .omitted)
        return day.hasLoggedActivity ? "\(dateText), activity logged" : "\(dateText), no activity logged"
    }
}
