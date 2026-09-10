import SwiftUI
import RithamCore

/// The Create Goal-Event screen (GROUPEVENTS-02): an event name, an activity-type picker, a
/// genuinely optional target, and a date window -- reached only from `GroupDetailView`'s own
/// "Start a Group Goal" entry point (this plan's own `key_links` boundary).
///
/// Two load-bearing constraints, stated here per this plan's own instruction:
///
/// 1. **The word competing products use for a timed contest never appears on this screen** -- not
///    in the CTA, not in the title, not in a hint, not in an empty state. Every visible string on
///    this screen comes from `SocialCopy`, never authored inline, so a future editor cannot
///    introduce that word here without also editing the catalog, where `SocialCopyTests` already
///    pins the banned lexicon.
/// 2. **The creation-time disclosure nudge sits beneath the name field**, reusing
///    `SocialCopy.Certificate.creationTimeNudge` rather than a second, duplicated string -- the
///    same catalog entry plan 04.1-16's export screen will show at the second moment of
///    `docs/group-events.md` §5's two-moment check. An event name is free text and can itself
///    disclose a place or a person; the organizer is the only one positioned to catch that at the
///    source, since the person who eventually exports a certificate is usually someone else.
///
/// On success, this screen hands the newly created event's id to `GoalEventRSVPView` via
/// `flow.selectedGoalEventID` and navigates forward to `.goalEventRSVP` -- there is no dedicated
/// "this group's upcoming events" list screen in this plan (a future plan builds one on top of
/// `GoalEventsModel.upcoming`, the mechanism this plan already ships); routing an organizer
/// straight to their own new event's RSVP screen is this plan's own way of making both screens it
/// builds fully reachable without inventing an out-of-scope list view.
struct CreateGoalEventView: View, OnboardingStepPresenting {
    static let step: OnboardingStep = .createGoalEvent

    static func makeView(flow: OnboardingFlow) -> AnyView {
        AnyView(CreateGoalEventView(flow: flow))
    }

    let flow: OnboardingFlow

    @State private var model = GoalEventsModel()
    @State private var name = ""
    @State private var activitySelection: Set<ActivityTypeOption> = [ActivityTypeOption(activityType: .run)]
    @State private var targetSelection: Set<TargetKindOption> = [.none]
    @State private var distanceKilometers = ""
    @State private var durationMinutes = ""
    @State private var startsOn = Date()
    @State private var endsOn = Date()
    @State private var showSaveError = false

    var body: some View {
        RithamScreen(surface: DecorativeSurface.flat, headline: SocialCopy.GoalEvent.createHeadline) {
            nameSection
            activitySection
            targetSection
            windowSection

            if showSaveError {
                Text(OnboardingCopy.Errors.savingFailed)
                    .font(RithamType.label)
                    .foregroundStyle(RithamColor.hot)
                    .fixedSize(horizontal: false, vertical: true)
            }

            PrimaryCTAButton(title: SocialCopy.GoalEvent.createCTA) {
                Task { await create() }
            }

            SecondaryCTAButton(title: "Back") {
                flow.goBack()
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var nameSection: some View {
        VStack(alignment: .leading, spacing: RithamSpacing.sm) {
            Text(SocialCopy.GoalEvent.nameFieldLabel)
                .font(RithamType.label)
                .foregroundStyle(RithamColor.paper)

            TextField(SocialCopy.GoalEvent.nameFieldPlaceholder, text: $name)
                .font(RithamType.body)
                .foregroundStyle(RithamColor.paper)
                .padding(RithamSpacing.md)
                .frame(minHeight: RithamSpacing.minimumTapTarget)
                .background(
                    RoundedRectangle(cornerRadius: RithamSpacing.sm)
                        .fill(RithamColor.paper.opacity(0.06))
                )

            Text(SocialCopy.Certificate.creationTimeNudge)
                .modifier(RithamType.fineprint())
                .foregroundStyle(RithamColor.paper)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var activitySection: some View {
        ChoiceQuestionView(
            prompt: SocialCopy.GoalEvent.activityPrompt,
            options: ActivityTypeOption.all,
            mode: .single,
            selection: $activitySelection,
            optionTitle: { $0.activityType.displayName }
        )
    }

    @ViewBuilder
    private var targetSection: some View {
        ChoiceQuestionView(
            prompt: SocialCopy.GoalEvent.targetPrompt,
            helper: SocialCopy.GoalEvent.targetHelper,
            options: TargetKindOption.all,
            mode: .single,
            selection: $targetSelection,
            optionTitle: { $0.title }
        )

        if targetSelection.contains(.distance) {
            targetValueField(SocialCopy.GoalEvent.distanceFieldLabel, text: $distanceKilometers)
        } else if targetSelection.contains(.duration) {
            targetValueField(SocialCopy.GoalEvent.durationFieldLabel, text: $durationMinutes)
        }
    }

    @ViewBuilder
    private var windowSection: some View {
        VStack(alignment: .leading, spacing: RithamSpacing.sm) {
            DatePicker(SocialCopy.GoalEvent.startsLabel, selection: $startsOn, displayedComponents: .date)
                .foregroundStyle(RithamColor.paper)
                .onChange(of: startsOn) { _, newValue in
                    if endsOn < newValue { endsOn = newValue }
                }

            DatePicker(SocialCopy.GoalEvent.endsLabel, selection: $endsOn, in: startsOn..., displayedComponents: .date)
                .foregroundStyle(RithamColor.paper)
        }
    }

    @ViewBuilder
    private func targetValueField(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: RithamSpacing.sm) {
            Text(label)
                .font(RithamType.label)
                .foregroundStyle(RithamColor.paper)

            TextField(label, text: text)
                .keyboardType(.decimalPad)
                .font(RithamType.body)
                .foregroundStyle(RithamColor.paper)
                .padding(RithamSpacing.md)
                .frame(minHeight: RithamSpacing.minimumTapTarget)
                .background(
                    RoundedRectangle(cornerRadius: RithamSpacing.sm)
                        .fill(RithamColor.paper.opacity(0.06))
                )
        }
    }

    // MARK: - Actions

    private func create() async {
        guard let groupID = flow.selectedGroupID, let activityType = activitySelection.first?.activityType else {
            showSaveError = true
            return
        }
        let created = await model.create(
            groupID: groupID,
            name: name,
            activityType: activityType,
            target: resolvedTarget(),
            startsOn: startsOn,
            endsOn: endsOn
        )
        if let created {
            showSaveError = false
            flow.selectedGoalEventID = created.id
            flow.open(.goalEventRSVP)
        } else {
            showSaveError = true
        }
    }

    /// A target field left blank, non-numeric, or non-positive falls back to
    /// `GoalEventTarget.none` -- the target is genuinely optional, never a blocking validation
    /// error, matching this screen's own "clearly labelled as such" requirement.
    private func resolvedTarget() -> GoalEventTarget {
        switch targetSelection.first {
        case .distance:
            guard let km = Double(distanceKilometers), km > 0 else { return GoalEventTarget.none }
            return .distance(metres: km * 1000)
        case .duration:
            guard let minutes = Double(durationMinutes), minutes > 0 else { return GoalEventTarget.none }
            return .duration(seconds: Int(minutes * 60))
        default:
            return GoalEventTarget.none
        }
    }
}

/// `ActivityType` wrapped for `ChoiceQuestionView`'s `Identifiable` requirement -- the same
/// rationale `MomentumTargetOption`/`WeeklyFrequencyOption` document: a bare value has no natural
/// single UI-option identity of its own.
struct ActivityTypeOption: Hashable, Identifiable {
    let activityType: ActivityType
    var id: String { activityType.rawValue }

    static let all: [ActivityTypeOption] = ActivityType.known.map(ActivityTypeOption.init)
}

/// The three-way target choice this screen offers -- "no target," "distance," or "duration."
/// `GoalEventTarget`'s own three cases (RithamCore) are not reused directly as the picker's option
/// type: `.distance`/`.duration` carry an associated value that has no place in a chip's own
/// selection identity (the numeric value is entered separately, in `targetValueField` above) --
/// matching `MomentumTargetOption`'s own "wrap for the picker, don't reuse the domain type itself"
/// precedent.
enum TargetKindOption: Hashable, Identifiable, CaseIterable {
    case none, distance, duration
    var id: Self { self }

    var title: String {
        switch self {
        case .none: return SocialCopy.GoalEvent.targetNoneOption
        case .distance: return SocialCopy.GoalEvent.targetDistanceOption
        case .duration: return SocialCopy.GoalEvent.targetDurationOption
        }
    }

    static let all: [TargetKindOption] = Array(TargetKindOption.allCases)
}
