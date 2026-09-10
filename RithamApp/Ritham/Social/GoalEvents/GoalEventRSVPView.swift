import SwiftUI
import RithamCore

/// The pre-event RSVP screen (GROUPEVENTS-02), deliberately separate from the group feed, per
/// `docs/group-events.md` §2's own structural requirement. Reached only from
/// `CreateGoalEventView`'s own forward navigation once creation succeeds (this plan's own scope --
/// a future plan's Goal-Events list screen is the other entry point this screen expects, once
/// built on top of `GoalEventsModel.upcoming`).
///
/// Three constraints on this screen, each load-bearing per `04.1-UI-SPEC.md`, not stylistic:
///
/// 1. **The headcount lives here and only here.** This screen must never be reachable from,
///    referenced by, or navigable to from anything that shows completions -- a headcount rendered
///    near a completion count is exactly the juxtaposition this feature exists to avoid
///    (`docs/group-events.md` §2). No completion-facing screen exists yet anywhere in this
///    codebase's client (plan 04.1-12 shipped only the Go-side feed routes; no client screen
///    consumes them yet), so this constraint is currently one-sided by construction: this file
///    references no completion-facing type or step (`GoalEventsUITests` asserts that source-level
///    absence), but the reciprocal half -- a future completion-facing screen never referencing
///    `.goalEventRSVP` -- can only be re-verified once that screen is actually built.
/// 2. **No ring, arc, or radial progress indicator anywhere on this screen.** This phase extends
///    the existing data-bearing-ring prohibition to its whole surface
///    (`04.1-UI-SPEC.md`'s Non-Comparative Structural Visual Rules, Rule 5) -- an RSVP-headcount
///    ring would itself read as exactly the comparison mechanic this feature is shaped to avoid.
/// 3. **Nothing renders for anyone who has not responded.** No greyed row, no placeholder, no
///    absent list -- non-response is a non-event (`docs/group-events.md` §2's own framing).
///    Building an empty row per non-responder "for symmetry" is the specific mistake this rule
///    rules out; this screen simply never enumerates non-responders at all -- there is no roster
///    to enumerate, since `GoalEventsModel` carries none (see that type's own header comment).
struct GoalEventRSVPView: View, OnboardingStepPresenting {
    static let step: OnboardingStep = .goalEventRSVP

    static func makeView(flow: OnboardingFlow) -> AnyView {
        AnyView(GoalEventRSVPView(flow: flow))
    }

    let flow: OnboardingFlow

    @State private var model = GoalEventsModel()
    @State private var event: GoalEvent?

    var body: some View {
        RithamScreen(surface: DecorativeSurface.flat, headline: event?.name ?? SocialCopy.GoalEvent.createHeadline) {
            if let event {
                HStack(spacing: RithamSpacing.sm) {
                    ActivityTypeIcon(activityType: event.activityType)

                    Text(event.activityType.displayName)
                        .font(RithamType.body)
                        .foregroundStyle(RithamColor.paper)
                }

                Text(SocialCopy.GoalEvent.description)
                    .font(RithamType.body)
                    .foregroundStyle(RithamColor.paper)
                    .fixedSize(horizontal: false, vertical: true)

                PrimaryCTAButton(title: SocialCopy.RSVP.cta) {
                    Task { await respond() }
                }

                // The headcount line -- the number rendered in the app's monospaced-numeral role,
                // like every other counting value (RithamType.numerals()). This is the one and
                // only place in this plan's surfaces this number appears (see constraint 1 above).
                Text(SocialCopy.RSVP.headcount(model.rsvpCount))
                    .font(RithamType.body)
                    .modifier(RithamType.numerals())
                    .foregroundStyle(RithamColor.paper)

                if model.viewerIsIn {
                    Text(SocialCopy.RSVP.confirmation(eventName: event.name))
                        .font(RithamType.body)
                        .foregroundStyle(RithamColor.paper)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            SecondaryCTAButton(title: "Back") {
                flow.goBack()
            }
        }
        .task { await load() }
    }

    private func load() async {
        guard let eventID = flow.selectedGoalEventID else { return }
        event = await model.get(eventID: eventID)
        await model.loadRSVPState(eventID: eventID)
    }

    private func respond() async {
        guard let eventID = flow.selectedGoalEventID else { return }
        await model.rsvp(eventID: eventID)
    }
}
