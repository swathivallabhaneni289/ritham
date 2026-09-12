import SwiftUI
import SwiftData
import RithamCore

/// `EditAnswerFlow`/`SettingsView`'s first consumer of `EditableSection` as a `.sheet(item:)`
/// identity -- the same retroactive-`Identifiable` pattern `ChecklistItem`/`DietaryPattern`
/// already use at their own first UI-layer consumer.
extension EditableSection: @retroactive Identifiable {
    public var id: Self { self }
}

// DIET-01: `DietaryPattern` needs `Identifiable` to drive `ChoiceQuestionView`'s `ForEach`
// without a separate id parameter -- the same retroactive-conformance pattern above applies.
// `DietaryPattern` is already `Hashable` (raw-value-backed `CaseIterable` enums get that
// automatically); only `Identifiable` is missing. This conformance used to live in
// `DietaryPatternStepView.swift`, the onboarding screen for this question -- per direct product
// feedback (2026-08-29) that question moved out of onboarding entirely (see
// `OnboardingRouter`'s doc comment), making this view its sole remaining consumer.
extension DietaryPattern: @retroactive Identifiable {
    public var id: Self { self }
}

// Same reasoning as `DietaryPattern` above, for the allergens picker this view also renders.
extension FoodAllergen: @retroactive Identifiable {
    public var id: Self { self }
}

/// The diet plan (DIET-01's dietary-pattern choice plus the allergens picker) is opened as its
/// own screen via `DietPlanView`, a `.sheet`, rather than shown inline here -- direct product
/// feedback (2026-09-01): the two pickers belong together on a screen the user opens, not
/// spilled across this main Settings list. `DietaryPattern`/`FoodAllergen`'s `Identifiable`
/// conformances stay declared in this file since `DietPlanView` needs them and this is their
/// first UI-layer consumer.
///
/// Also offers an entry point to the health profile, plus one per-section entry point for each
/// of the four screening sections (`.gateSection`, `.conditionChecklist`, `.severityFollowUps`,
/// `.scoff`), each routed through `EditAnswerFlow` as a `.sheet` -- D-09 scopes each of those
/// edits to its own section, never the whole questionnaire, and CROSSGEN-05 reserves the app's
/// one `NavigationStack` for `OnboardingRootView`, so a section edit here is always a sheet,
/// never a push.
struct SettingsView: View {
    let flow: OnboardingFlow
    var onOpenHealthProfile: () -> Void = {}

    @Environment(\.modelContext) private var modelContext
    @State private var editingSection: EditableSection?
    @State private var isEditingDietPlan = false
    @State private var isShowingAlwaysFreeList = false
    @State private var isEditingWorkoutFrequency = false
    @State private var isEditingMomentumTarget = false
    @State private var isEditingMovementSnapshot = false
    @State private var isEditingPrivacyZones = false
    @State private var isShowingKidIdeas = false
    @State private var isReScreenDue = false

    init(flow: OnboardingFlow, onOpenHealthProfile: @escaping () -> Void = {}) {
        self.flow = flow
        self.onOpenHealthProfile = onOpenHealthProfile
    }

    var body: some View {
        RithamScreen(surface: DecorativeSurface.flat, headline: "Settings") {
            // D-07: shown when overdue, non-blocking, dismissible for the session. "Start
            // re-screen" opens the gate section -- the first screen of the real screening --
            // through the same section-scoped `EditAnswerFlow` every other entry point here
            // uses; this plan builds no separate full-questionnaire restart wizard.
            ReScreenBanner(isReScreenDue: isReScreenDue) {
                editingSection = .gateSection
            }

            SecondaryCTAButton(title: "Diet plan") {
                isEditingDietPlan = true
            }

            SecondaryCTAButton(title: "Health profile", action: onOpenHealthProfile)

            // MONETIZE-01: the visible "always free" list -- reachable from Settings in one tap,
            // per this plan's own requirement.
            SecondaryCTAButton(title: "Always free") {
                isShowingAlwaysFreeList = true
            }

            // Claude's Discretion (`02-CONTEXT.md`): the weekly workout-frequency preference,
            // same sheet-presented pattern as the diet plan.
            SecondaryCTAButton(title: "Workout frequency") {
                isEditingWorkoutFrequency = true
            }

            // MOMENTUM-01's adjustable weekly target (Claude's Discretion, `03-CONTEXT.md`):
            // placed directly next to Workout frequency since both are weekly-cadence
            // preferences. This is a preference entry only -- Settings shows no Momentum state
            // (streak, shields) of its own; that lives exclusively on `HomeHubView`/`MomentumView`.
            SecondaryCTAButton(title: Self.momentumTargetRowTitle) {
                isEditingMomentumTarget = true
            }

            // MOMENTUM-07/D-09: the Daily Movement Snapshot opt-in, off by default. This is a
            // preference entry only, exactly like the Momentum-target row above it -- Settings
            // shows no snapshot state (calendar days, marked/unmarked) of its own; that lives
            // exclusively on `MovementSnapshotView`, reachable only from the hub once opted in.
            SecondaryCTAButton(title: Self.movementSnapshotRowTitle) {
                isEditingMovementSnapshot = true
            }

            // GROUPEVENTS-03: the on-device-only Privacy Zones a shared location is checked
            // against before it is ever geocoded (`Social/PrivacyZones/LocationAttachment.swift`).
            // A preference entry only, exactly like the two rows above it -- this row shows no
            // zone state of its own; `PrivacyZonesView` owns that list.
            SecondaryCTAButton(title: "Privacy Zones") {
                isEditingPrivacyZones = true
            }

            // KIDCONTENT-01/KIDCONTENT-02: a sibling Settings row rather than a link nested
            // inside `DietPlanView` -- D-04's placement decision, chosen because this feature
            // spans both food and movement rather than diet alone (04.2-CONTEXT.md's Claude's
            // Discretion paragraph and 04.2-RESEARCH.md Open Question 3 both land on this).
            // `KidIdeasView()` takes no `flow`, unlike the `DietPlanView(flow:)` row above it --
            // this preference is not a screening answer, so it sits outside that group below.
            SecondaryCTAButton(title: Self.kidIdeasRowTitle) {
                isShowingKidIdeas = true
            }

            VStack(alignment: .leading, spacing: RithamSpacing.sm) {
                Text("Screening answers")
                    .font(RithamType.heading)
                    .foregroundStyle(RithamColor.paper)

                sectionEntryPoint(.gateSection, title: "Health questions")
                sectionEntryPoint(.conditionChecklist, title: "Condition checklist")
                sectionEntryPoint(.severityFollowUps, title: "Follow-up questions")
                sectionEntryPoint(.scoff, title: "Eating-pattern questions")
            }
        }
        .onAppear(perform: refreshReScreenDue)
        .sheet(item: $editingSection) { section in
            EditAnswerFlow(flow: flow, section: section)
                .onDisappear(perform: refreshReScreenDue)
        }
        .sheet(isPresented: $isEditingDietPlan) {
            DietPlanView(flow: flow)
        }
        .sheet(isPresented: $isShowingAlwaysFreeList) {
            AlwaysFreeListView()
        }
        .sheet(isPresented: $isEditingWorkoutFrequency) {
            WorkoutFrequencyView(initialFrequency: currentWeeklyFrequency())
        }
        .sheet(isPresented: $isEditingMomentumTarget) {
            MomentumTargetView(initialTarget: currentMomentumTarget())
        }
        .sheet(isPresented: $isEditingMovementSnapshot) {
            MovementSnapshotToggleView(initialOptIn: currentMovementSnapshotOptIn())
        }
        .sheet(isPresented: $isEditingPrivacyZones) {
            PrivacyZonesView()
        }
        .sheet(isPresented: $isShowingKidIdeas) {
            KidIdeasView()
        }
    }

    /// The Momentum-target row's label, extracted as a single source of truth so
    /// `MomentumTargetPickerTests` can pin it without rendering this view.
    static let momentumTargetRowTitle = "Momentum target"

    /// The Movement Snapshot row's label, extracted the same way `momentumTargetRowTitle` is so
    /// `MovementSnapshotViewTests` can pin it without rendering this view.
    static let movementSnapshotRowTitle = "Daily Movement Snapshot"

    /// The Kid Ideas row's label, extracted the same way `momentumTargetRowTitle`/
    /// `movementSnapshotRowTitle` are so `KidIdeasTests` can pin it without rendering this view.
    static let kidIdeasRowTitle = KidContentCopy.Screen.headline

    private func sectionEntryPoint(_ section: EditableSection, title: String) -> some View {
        SecondaryCTAButton(title: title) {
            editingSection = section
        }
    }

    private func refreshReScreenDue() {
        let store = HealthDataStore(context: modelContext)
        isReScreenDue = (try? store.isReScreenDue(now: Date())) ?? false
    }

    /// Loaded fresh at sheet-presentation time (not cached in `SettingsView`'s own state) so a
    /// reopen always reflects whatever was persisted the last time this sheet was dismissed.
    /// `HealthDataStore.loadWeeklyFrequency` already supplies the stated default (3) when nothing
    /// is stored yet.
    private func currentWeeklyFrequency() -> Int {
        let store = HealthDataStore(context: modelContext)
        return (try? store.loadWeeklyFrequency()) ?? 3
    }

    /// Loaded fresh at sheet-presentation time (not cached in `SettingsView`'s own state),
    /// exactly mirroring `currentWeeklyFrequency()`'s own pattern above -- a reopen always
    /// reflects whatever target was persisted the last time this sheet was dismissed.
    /// `HealthDataStore.loadMomentumTarget` already supplies `MomentumTarget.defaultTarget` when
    /// nothing is stored yet.
    private func currentMomentumTarget() -> Int {
        let store = HealthDataStore(context: modelContext)
        return (try? store.loadMomentumTarget()) ?? MomentumTarget.defaultTarget
    }

    /// Loaded fresh at sheet-presentation time (not cached in `SettingsView`'s own state),
    /// mirroring `currentWeeklyFrequency()`/`currentMomentumTarget()`'s own pattern above.
    /// `HealthDataStore.loadMovementSnapshotOptIn` already supplies `false` when nothing is
    /// stored yet.
    private func currentMovementSnapshotOptIn() -> Bool {
        let store = HealthDataStore(context: modelContext)
        return (try? store.loadMovementSnapshotOptIn()) ?? false
    }
}
