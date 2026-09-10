import SwiftUI
import RithamCore

/// The group's completion history (04.1-UI-SPEC.md's Group Feed and History section): the
/// identical `CompletionCard` reused under the catalog's "Completed by:" heading
/// (`SocialCopy.Feed.groupHistoryHeading`) -- no count, no fraction, ever (Non-Comparative
/// Structural Visual Rules, Rule 2). Registered under `.groupHistory`, reached from
/// `GroupDetailView`'s own "History" entry point, driven by the same `flow.selectedGroupID` as
/// `GroupFeedView`.
///
/// **Group-scoped, not event-scoped, and not polled.** This screen reuses `GroupFeedModel` with
/// `.group(_:)` -- the identical chronological, membership-scoped feed `GroupFeedView` shows live --
/// because the server has no separate "closed events only" query: a Goal-Event's window closing is
/// purely a client-side filtering concern of `GoalEventsModel.upcoming` (which this screen never
/// touches), not a property the feed itself tracks. This screen is deliberately the archive framing
/// of the same data rather than a live monitor: it loads once and offers pull-to-refresh, but never
/// starts `GroupFeedModel`'s poll loop, matching this screen's own "browse what already happened"
/// purpose rather than `GroupFeedView`'s "watch what's happening now" purpose.
///
/// The same six Non-Comparative Structural Visual Rules constraints `GroupFeedView.swift`'s own
/// header comment documents apply here identically -- see that file for the full list. This screen
/// additionally never re-displays the pre-event RSVP headcount, which is Rule 2's own explicit
/// example: "no navigation to the RSVP screen that holds the pre-event headcount."
struct GroupHistoryView: View, OnboardingStepPresenting {
    static let step: OnboardingStep = .groupHistory

    static func makeView(flow: OnboardingFlow) -> AnyView {
        AnyView(GroupHistoryView(flow: flow))
    }

    let flow: OnboardingFlow

    @State private var model: GroupFeedModel?

    var body: some View {
        RithamScreen(surface: DecorativeSurface.flat, headline: SocialCopy.Feed.groupHistoryHeading) {
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
    }

    /// Branches on `GroupFeedModel.RenderDecision`, never on `model.state` alone -- see that
    /// type's own header comment for why a naive `state`-only switch would discard already-loaded
    /// cards on a failed refresh.
    @ViewBuilder
    private var content: some View {
        if let model {
            switch model.renderDecision {
            case .nothing:
                EmptyView()
            case .emptyMessage:
                Text("No completions to show yet.")
                    .font(RithamType.body)
                    .foregroundStyle(RithamColor.paper)
            case .failureMessage:
                Text("Couldn't load this history. Check your connection and try again.")
                    .font(RithamType.body)
                    .foregroundStyle(RithamColor.paper)
                    .fixedSize(horizontal: false, vertical: true)
            case .cards, .cardsWithFailureBanner:
                VStack(spacing: RithamSpacing.sm) {
                    if model.renderDecision == .cardsWithFailureBanner {
                        Text("Couldn't refresh this history. Showing what was last loaded.")
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
    }
}
