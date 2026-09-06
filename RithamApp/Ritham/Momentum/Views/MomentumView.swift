import SwiftData
import SwiftUI
import RithamCore

// D-08's Momentum detail screen: weekly progress, streak, shields, milestones, the Comeback
// Session card, this week's session list, and (Task 3) the two structurally separate self-report
// guardrail rows. Reads the same `MomentumSummaryReader` `HomeHubView`'s own summary section
// (plan 03-07) reads, so both surfaces show the same underlying data (D-08's own requirement) --
// this view constructs its own reader over its own `HealthDataStore` rather than sharing a
// hub-owned view model, matching D-08's "not baked into a hub-specific view model" requirement.
//
// Reading the summary on `onAppear` is what performs reconciliation-on-read (see
// `MomentumSummaryReader.summary(now:)`'s own header comment) -- nothing else on this screen
// triggers it.
//
// Every pure derivation this screen needs for its own tests (`MomentumViewTests`) is declared as
// a `nonisolated static func` in the bottom extension, not a method on the view itself: SwiftUI's
// `View` protocol is itself `@MainActor`, which infers `@MainActor` isolation onto every member
// of a conforming type by default. Swift Testing runs test functions off the main actor, so an
// inferred-`@MainActor` static function traps at runtime with an actor-isolation assertion
// failure when called directly from a test (caught the hard way by `MomentumProgressBlocks`'s own
// first test run in Task 1) -- `nonisolated` is required on every one of these helpers, not
// optional decoration.

@MainActor
@Observable
final class MomentumViewModel {
    private(set) var summary: MomentumSummary?
    private(set) var loadError: Error?

    private let reader: MomentumSummaryReader

    init(reader: MomentumSummaryReader) {
        self.reader = reader
    }

    /// The single load path. Calling this is what performs reconciliation-on-read via
    /// `MomentumSummaryReader.summary(now:)` -- see that method's own header comment.
    func load(now: Date = Date()) {
        do {
            summary = try reader.summary(now: now)
            loadError = nil
        } catch {
            loadError = error
        }
    }

    // MARK: - Task 3: the two structurally separate self-report guardrail actions
    //
    // Per D-03, the Recovery Week flag (MOMENTUM-03) and the injury/pain freeze (MOMENTUM-08) are
    // two structurally independent state machines. Each method here calls exactly one
    // `MomentumSummaryReader` action method and nothing else -- neither method calls the other,
    // and neither shares any mutation path beyond reloading the summary afterward so the screen
    // reflects the new state on its next render.

    /// Confirms the Recovery Week flag for the week containing `now`.
    func flagRecoveryWeek(now: Date = Date()) {
        performGuardrailAction(now: now) { try self.reader.flagRecoveryWeek(now: now) }
    }

    /// Confirms an injury/pain freeze starting at `now`.
    func flagInjury(now: Date = Date()) {
        performGuardrailAction(now: now) { try self.reader.flagInjury(now: now) }
    }

    /// Clears the open injury/pain freeze, if any, at `now`.
    func clearInjury(now: Date = Date()) {
        performGuardrailAction(now: now) { try self.reader.clearInjury(now: now) }
    }

    private func performGuardrailAction(now: Date, _ action: () throws -> Void) {
        do {
            try action()
            load(now: now)
        } catch {
            loadError = error
        }
    }
}

struct MomentumView: View, OnboardingStepPresenting {
    static let step: OnboardingStep = .momentum

    static func makeView(flow: OnboardingFlow) -> AnyView {
        AnyView(MomentumView(flow: flow))
    }

    let flow: OnboardingFlow
    @Environment(\.modelContext) private var modelContext
    @State private var model: MomentumViewModel?

    // Task 3: two separate `@State` booleans, one per row -- confirming or dismissing one alert
    // can never touch the other row's presentation state. No enum, no shared "which alert is
    // showing" flag of any kind (see this file's Task 3 section for the full D-03 rationale).
    @State private var showingRecoveryWeekAlert = false
    @State private var showingInjuryAlert = false

    var body: some View {
        RithamScreen(surface: DecorativeSurface.flat, headline: "Momentum") {
            content
        }
        .onAppear {
            if model == nil {
                let store = HealthDataStore(context: modelContext)
                model = MomentumViewModel(reader: MomentumSummaryReader(store: store, calendar: .current))
            }
            model?.load()
        }
    }

    @ViewBuilder
    private var content: some View {
        if let model {
            if let summary = model.summary {
                summaryContent(summary)
            } else if model.loadError != nil {
                // 03-UI-SPEC.md's Copywriting Contract: reuse `OnboardingCopy.Errors.savingFailed`
                // verbatim for any Momentum/Recovery saving failure rather than drafting a second
                // error string for this phase.
                Text(OnboardingCopy.Errors.savingFailed)
                    .font(RithamType.body)
                    .foregroundStyle(RithamColor.paper)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ProgressView()
            }
        } else {
            ProgressView()
        }
    }

    @ViewBuilder
    private func summaryContent(_ summary: MomentumSummary) -> some View {
        VStack(alignment: .leading, spacing: RithamSpacing.lg) {
            MomentumProgressBlocks(filled: summary.displayedCount, target: summary.weeklyTarget)

            Text(Self.streakLine(for: summary))
                .font(RithamType.heading)
                .modifier(RithamType.numerals())
                .foregroundStyle(RithamColor.paper)

            if summary.shieldCount > 0 {
                ShieldRow(earned: summary.shieldCount, maximum: MomentumLedger.maxShields)
            } else {
                emptyState(headline: MomentumCopy.Empty.noShieldsHeadline, body: MomentumCopy.Empty.noShieldsBody)
            }

            if summary.milestones.isEmpty {
                emptyState(headline: MomentumCopy.Empty.noMilestonesHeadline, body: MomentumCopy.Empty.noMilestonesBody)
            } else {
                MilestoneBadgeList(awarded: summary.milestones)
            }

            if Self.showsComebackCard(for: summary), let window = summary.openComebackWindow {
                comebackCard(window)
            }

            sessionListSection(summary)

            recoveryWeekRow(summary)
            injuryRow(summary)
        }
    }

    // MARK: - Task 3: two structurally separate self-report controls
    //
    // Per D-03 (RithamCore-level) and its direct UI consequence (03-UI-SPEC.md Component 5), the
    // Recovery Week flag and the injury/pain freeze render as two clearly separate rows: two
    // different SF Symbols, two independent `@State` alert-presentation booleans, two separate
    // `.alert(...)` confirmations. They must never be merged into one row, one icon, one
    // enum-driven picker, or one section header implying they are a single mechanic. Neither row
    // uses `RithamColor.destructive` -- clearing an injury flag is a state change, not a
    // delete/irreversible action, and this phase has no destructive action of any kind.

    @ViewBuilder
    private func recoveryWeekRow(_ summary: MomentumSummary) -> some View {
        if summary.isRecoveryWeekFlagged {
            // Already flagged: a plain, non-interactive state, not a second control and not
            // styled as an error. No distinct "already flagged" copy exists in MomentumCopy, so
            // this reuses the same flagButton string as a plain label rather than drafting new
            // copy the UI-SPEC's Copywriting Contract doesn't call for.
            controlLabel(icon: "figure.walk.motion", title: MomentumCopy.RecoveryWeek.flagButton)
        } else {
            Button {
                showingRecoveryWeekAlert = true
            } label: {
                controlLabel(icon: "figure.walk.motion", title: MomentumCopy.RecoveryWeek.flagButton)
            }
            .alert(MomentumCopy.RecoveryWeek.alertTitle, isPresented: $showingRecoveryWeekAlert) {
                Button(MomentumCopy.RecoveryWeek.confirmButton) {
                    model?.flagRecoveryWeek()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(MomentumCopy.RecoveryWeek.alertBody)
            }
        }
    }

    @ViewBuilder
    private func injuryRow(_ summary: MomentumSummary) -> some View {
        if summary.isInjuryFrozen {
            Button {
                showingInjuryAlert = true
            } label: {
                controlLabel(icon: "bandage", title: MomentumCopy.Injury.clearButton)
            }
            .alert(MomentumCopy.Injury.clearAlertTitle, isPresented: $showingInjuryAlert) {
                Button(MomentumCopy.Injury.clearButton) {
                    model?.clearInjury()
                }
                Button("Cancel", role: .cancel) {}
            }
        } else {
            Button {
                showingInjuryAlert = true
            } label: {
                controlLabel(icon: "bandage", title: MomentumCopy.Injury.flagButton)
            }
            .alert(MomentumCopy.Injury.alertTitle, isPresented: $showingInjuryAlert) {
                Button(MomentumCopy.Injury.confirmButton) {
                    model?.flagInjury()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(MomentumCopy.Injury.alertBody)
            }
        }
    }

    @ViewBuilder
    private func controlLabel(icon: String, title: String) -> some View {
        HStack(spacing: RithamSpacing.sm) {
            Image(systemName: icon)
            Text(title)
        }
        .font(RithamType.body)
        .foregroundStyle(RithamColor.paper)
        .frame(minHeight: RithamSpacing.minimumTapTarget)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(
            RoundedRectangle(cornerRadius: RithamSpacing.sm)
                .stroke(RithamColor.paper, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func comebackCard(_ window: ComebackWindow) -> some View {
        VStack(alignment: .leading, spacing: RithamSpacing.md) {
            Text(MomentumCopy.Comeback.headline)
                .font(RithamType.body.weight(.semibold))
                .foregroundStyle(RithamColor.paper)

            // A static "by {date}" statement only -- never a countdown, timer, or shrinking bar
            // (MOMENTUM-04, 03-UI-SPEC.md Component 4).
            Text(MomentumCopy.Comeback.body(deadline: window.closesAt.formatted(date: .abbreviated, time: .omitted)))
                .font(RithamType.body)
                .foregroundStyle(RithamColor.paper)
                .fixedSize(horizontal: false, vertical: true)

            // 03-UI-SPEC.md Component 4 names both `.cardioActivityPicker` and `.strengthSession`
            // as acceptable entry points, leaving the exact choice to the executor ("no new
            // multi-step flow, no separate wizard screen, per Claude's Discretion"). This routes
            // to the cardio picker -- the lower-friction single entry point for a qualifying
            // session of either modality, since a strength session stays reachable from the hub
            // directly and this screen adds no new navigation of its own.
            PrimaryCTAButton(title: MomentumCopy.Comeback.button) {
                flow.open(.cardioActivityPicker)
            }
        }
        .padding(RithamSpacing.md)
        .overlay(
            RoundedRectangle(cornerRadius: RithamSpacing.sm)
                .stroke(RithamColor.paper, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func sessionListSection(_ summary: MomentumSummary) -> some View {
        if summary.recentSessions.isEmpty {
            emptyState(headline: MomentumCopy.Empty.noSessionsHeadline, body: MomentumCopy.Empty.noSessionsBody)
        } else {
            VStack(alignment: .leading, spacing: RithamSpacing.md) {
                ForEach(summary.recentSessions) { entry in
                    sessionRow(entry)
                }
            }
        }
    }

    @ViewBuilder
    private func sessionRow(_ entry: MomentumSessionEntry) -> some View {
        VStack(alignment: .leading, spacing: RithamSpacing.xs) {
            Text(entry.title)
                .font(RithamType.body)
                .foregroundStyle(RithamColor.paper)

            Text(entry.startedAt.formatted(date: .abbreviated, time: .shortened))
                .font(RithamType.label)
                .foregroundStyle(RithamColor.paper)

            // A lift-derived entry (`verificationLabel == nil`) renders no label element at all
            // in this position -- never a default "Manually entered" invented for a field that
            // doesn't exist on that record type. Both cardio branches (sensor-verified,
            // manually-entered) use identical styling: no badge, no icon, no color distinction
            // (03-UI-SPEC.md Component 11).
            if Self.showsVerificationLabel(for: entry), let label = entry.verificationLabel {
                Text(label)
                    .font(RithamType.label)
                    .foregroundStyle(RithamColor.paper)
            }
        }
    }

    @ViewBuilder
    private func emptyState(headline: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: RithamSpacing.xs) {
            Text(headline)
                .font(RithamType.body.weight(.semibold))
                .foregroundStyle(RithamColor.paper)
            Text(body)
                .font(RithamType.label)
                .foregroundStyle(RithamColor.paper)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Pure, testable derivations (see this file's header for why these must be `nonisolated`)

extension MomentumView {
    /// Whether the Comeback Session card should render for `summary` -- present exactly when an
    /// open comeback window exists.
    nonisolated static func showsComebackCard(for summary: MomentumSummary) -> Bool {
        summary.openComebackWindow != nil
    }

    /// The streak headline: `MomentumCopy.Streak.rebuiltStreak` exactly when the label kind is
    /// `.rebuilt` and the streak is 1, `MomentumCopy.Streak.streak(weeks:)` otherwise.
    nonisolated static func streakLine(for summary: MomentumSummary) -> String {
        if summary.streakLabelKind == .rebuilt && summary.currentStreak == 1 {
            return MomentumCopy.Streak.rebuiltStreak
        }
        return MomentumCopy.Streak.streak(weeks: summary.currentStreak)
    }

    /// Whether a session row should render a verification label element at all -- a lift-derived
    /// entry (`verificationLabel == nil`) renders no label element in that position at all, never
    /// a default value invented for a field that doesn't exist on that record type.
    nonisolated static func showsVerificationLabel(for entry: MomentumSessionEntry) -> Bool {
        entry.verificationLabel != nil
    }

    /// The injury row's label: `MomentumCopy.Injury.clearButton` exactly when `isInjuryFrozen`,
    /// `MomentumCopy.Injury.flagButton` otherwise. Depends only on `isInjuryFrozen`, never on
    /// `isRecoveryWeekFlagged` -- the two self-report controls share no state (D-03).
    nonisolated static func injuryRowLabel(isInjuryFrozen: Bool) -> String {
        isInjuryFrozen ? MomentumCopy.Injury.clearButton : MomentumCopy.Injury.flagButton
    }
}
