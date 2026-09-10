import SwiftUI
import RithamCore

/// The group-only, chronological completion feed (GROUPEVENTS-04) -- the surface every non-
/// comparative rule in this phase becomes something a person actually looks at. Registered under
/// `.groupFeed`, reached from `GroupDetailView`'s own "Feed" entry point, driven by
/// `flow.selectedGroupID` (already set before `GroupDetailView` itself is reachable).
///
/// Loads once on appear, then polls every `GroupFeedModel.pollInterval` seconds while this screen
/// is on top of the navigation stack -- started in `.task`, stopped in `.onDisappear`, so polling
/// never outlives this screen (T-04.1-99). Pull-to-refresh calls the identical
/// `GroupFeedModel.refresh()` load path.
///
/// Six constraints apply to this screen (04.1-UI-SPEC.md's Non-Comparative Structural Visual
/// Rules), each a thing a normal social app would do by default and none of which this screen does:
/// 1. No sort or filter control offering any ordering by time -- the feed is chronological only.
/// 2. No ordinal marker, medal, or first-to-complete treatment on any card.
/// 3. No count, fraction, total, or member figure anywhere, and no navigation to the RSVP screen
///    that holds the pre-event headcount.
/// 4. No row, avatar, or placeholder for anyone who has not completed -- non-completion renders
///    nothing, never an empty row built "for symmetry."
/// 5. No ring, arc, or radial progress form anywhere in the content area.
/// 6. Nothing visually marks an event whose window has closed -- that state lives entirely in
///    `GoalEventsModel.upcoming`'s own filtering, never here.
struct GroupFeedView: View, OnboardingStepPresenting {
    static let step: OnboardingStep = .groupFeed

    static func makeView(flow: OnboardingFlow) -> AnyView {
        AnyView(GroupFeedView(flow: flow))
    }

    let flow: OnboardingFlow

    @State private var model: GroupFeedModel?

    var body: some View {
        RithamScreen(surface: DecorativeSurface.flat, headline: "Group feed") {
            content

            SecondaryCTAButton(title: "Back") {
                flow.goBack()
            }
        }
        .refreshable {
            await model?.refresh()
        }
        .task {
            await load()
        }
        .onDisappear {
            model?.stopPolling()
        }
    }

    /// Branches on `GroupFeedModel.RenderDecision`, never on `model.state` alone -- see that
    /// type's own header comment for why a naive `state`-only switch would blank every card on
    /// screen on the poll timer's own next tick.
    @ViewBuilder
    private var content: some View {
        if let model {
            // Bound once, not re-read inside the switch's own arm -- SwiftUI evaluates `body`
            // synchronously so the two reads agree today, but binding once makes that invariant
            // structural rather than incidental to a future edit (e.g. moving the banner into a
            // child view, or inserting an `await` somewhere in between).
            let decision = model.renderDecision
            switch decision {
            case .nothing:
                EmptyView()
            case .emptyMessage:
                Text("Nothing has been logged yet.")
                    .font(RithamType.body)
                    .foregroundStyle(RithamColor.paper)
            case .failureMessage:
                Text("Couldn't load the feed. Check your connection and try again.")
                    .font(RithamType.body)
                    .foregroundStyle(RithamColor.paper)
                    .fixedSize(horizontal: false, vertical: true)
            case .cards, .cardsWithFailureBanner:
                VStack(spacing: RithamSpacing.sm) {
                    if decision == .cardsWithFailureBanner {
                        Text("Couldn't refresh the feed. Showing what was last loaded.")
                            .font(RithamType.body)
                            .foregroundStyle(RithamColor.paper)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    ForEach(model.items) { item in
                        CompletionCard(item: item) { cheer in
                            Task {
                                await model.toggleCheer(cheer, for: item, on: !currentlySent(cheer, on: item))
                            }
                        }
                        .onAppear {
                            if item.id == model.items.last?.id {
                                Task { await model.loadNextPage() }
                            }
                        }
                    }
                }
            }
        }
    }

    private func currentlySent(_ cheer: Cheer, on item: FeedItem) -> Bool {
        switch cheer {
        case .niceWork: return item.cheers.niceWorkSentByViewer
        case .keepGoing: return item.cheers.keepGoingSentByViewer
        }
    }

    private func load() async {
        guard let groupID = flow.selectedGroupID else { return }
        let feedModel = model ?? GroupFeedModel(source: .group(groupID))
        model = feedModel
        await feedModel.loadFirstPage()
        feedModel.startPolling()
    }
}
