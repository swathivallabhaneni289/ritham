import SwiftUI
import SwiftData
import RithamCore

/// D-09: editing a single answer later re-checks only that specific question or section, never
/// the entire questionnaire. Re-running the whole questionnaire for a single edit would be a
/// worse experience and is explicitly not what D-09 asks for -- this type exists so a Settings
/// edit costs exactly one section's worth of questions, not seven screens.
///
/// Presents exactly one of plan 01-16's already-registered screening screens --
/// `GateSectionView`/`ConditionChecklistView`/`SeverityFollowUpView`/`EatingPatternFollowUpView`,
/// resolved through `StepRegistry.view(for:flow:)` -- rather than re-implementing a second copy
/// of any question. Those screens are wired to call `flow.advance(from:)` on their own CTA,
/// which is correct during onboarding but would otherwise push this edit session into the
/// *next* onboarding step (the clearance interstitial, the checklist, the universal follow-up,
/// ...) on the very `path` `OnboardingRootView`'s single `NavigationStack` observes (CROSSGEN-05:
/// that view is the only place a navigation container may exist, so this type deliberately
/// presents no `NavigationStack` of its own -- callers show it via `.sheet`). This view
/// neutralizes that side effect: it captures `flow.path`'s count before presenting, and the
/// moment the wrapped screen's own CTA calls `flow.advance` (observed via `.onChange`), it pops
/// the path straight back to where it started, so this session's only observable effect on
/// `flow` is the section's own answers -- never a route into an unrelated step.
///
/// Re-resolution always goes through the same engine the original screening result went
/// through -- `GateResolution.resolve` over the fully merged `flow.answers.screening` -- never a
/// partial or incremental update; a section edit can change which gate binds, and only a full
/// re-resolve over the merged answers gets that right.
///
/// KNOWN LIMITATION (see this plan's SUMMARY.md and `deferred-items.md`): this type requires the
/// *same* `OnboardingFlow` instance whose `answers.screening` already holds the user's complete
/// raw answers from the original onboarding pass -- no raw `ScreeningAnswers` is durably
/// persisted anywhere (01-11's deliberate derived-tags-only storage decision). Presenting this
/// view against a *fresh*, empty `OnboardingFlow` (e.g. reconstructed in a brand-new app launch,
/// with no in-memory answers carried forward) re-resolves over blank answers for every section
/// but the one being edited, and silently wipes every other section's condition tags. That is
/// exactly the under-restriction failure class T-01-103/T-01-104 exist to prevent, and it is
/// not fixable inside this plan's scope without reversing 01-11's storage decision (a Rule 4,
/// architectural change, not a Rule 2 fix). Whichever future plan wires this into real app
/// navigation across process launches must either persist raw `ScreeningAnswers` or hydrate a
/// fresh `OnboardingFlow`'s `answers.screening` from a durable source before presenting this
/// view.
struct EditAnswerFlow: View {
    let flow: OnboardingFlow

    /// Which `EditableSection` this instance re-checks. Always one of the four screening
    /// sections in practice -- `SettingsView` never constructs this type with
    /// `.dietaryPattern`, since that section never routes through here at all.
    let section: EditableSection

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var pathCountAtStart = 0
    @State private var showSaveError = false

    /// The single `OnboardingStep` plan 01-16 registered for this section. `.dietaryPattern` has
    /// no screening-screen equivalent -- `SettingsView` edits it directly, in place, and never
    /// routes it through this type, since it may never touch `GateResolution` or a condition tag
    /// (DIET-01).
    private var step: OnboardingStep? {
        switch section {
        case .gateSection: return .gateSection
        case .conditionChecklist: return .conditionChecklist
        case .severityFollowUps: return .severityFollowUps
        case .scoff: return .scoffFollowUp
        case .dietaryPattern: return nil
        }
    }

    var body: some View {
        Group {
            if let step {
                StepRegistry.view(for: step, flow: flow)
            } else {
                // Unreachable from `SettingsView` by construction -- a plain flat message rather
                // than a trap, so a future misuse fails safe instead of crashing.
                RithamScreen(surface: DecorativeSurface.flat, bodyText: "Nothing to edit here.") {
                    EmptyView()
                }
            }
        }
        .onAppear { pathCountAtStart = flow.path.count }
        .onChange(of: flow.path) { _, newPath in
            guard newPath.count > pathCountAtStart else { return }
            // The wrapped screen's own CTA just called `flow.advance` -- pop it right back off
            // before it can carry this edit session into an unrelated onboarding step, then
            // finish this section's re-check.
            while flow.path.count > pathCountAtStart {
                flow.goBack()
            }
            finishEditing()
        }
        .alert(OnboardingCopy.Errors.savingFailed, isPresented: $showSaveError) {
            Button("OK", role: .cancel) {}
        }
    }

    private func finishEditing() {
        let store = HealthDataStore(context: modelContext)
        let now = Date()
        do {
            try store.invalidateSection(section, now: now)
            let result = GateResolution.resolve(
                answers: flow.answers.screening,
                ageDerivedTags: flow.answers.ageDerivedTags
            )
            try store.saveScreeningResult(result, answers: flow.answers.screening, now: now)
            dismiss()
        } catch {
            showSaveError = true
        }
    }
}
