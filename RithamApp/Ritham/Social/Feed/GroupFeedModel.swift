import Foundation
import RithamCore

/// Which feed `GroupFeedModel` loads from -- a group's whole feed, or a single event's. Both
/// `GroupFeedView` and `GroupHistoryView` (plan 04.1-15) construct this model with `.group(_:)`,
/// reached from `GroupDetailView`'s own two entry points and driven by `flow.selectedGroupID`
/// (already set by `GroupListView` before either screen is reachable); `.event(_:)` exists so
/// `FeedClient.eventFeed(eventID:cursor:)` has a model-level caller for full route coverage, even
/// though no screen in this plan constructs one -- matching `GroupsModel.join(groupID:)`'s own
/// "implemented, no UI caller yet" precedent from this same phase.
enum FeedSource: Equatable {
    case group(UUID)
    case event(UUID)
}

/// Drives the group feed and group history screens (GROUPEVENTS-04) at the model level, following
/// `CardioHistoryModel`'s `@Observable`-load-from-source shape, extended here with a poll timer per
/// `04.1-PATTERNS.md`'s own stated precedent for this type.
///
/// **This model never sorts, reverses, or re-keys a page's items -- it only ever appends them in
/// the order the server returned them.** That absence is load-bearing, not an oversight a later
/// editor should "improve": the server's own order is safe specifically because there is no
/// synchronized start line and no completion is ever compared to another (GROUPEVENTS-02/04). Any
/// client-side re-ordering -- even something as innocent-looking as "sort by activity type" or "put
/// photos first" -- would reintroduce exactly the ranking the server refuses to compute.
/// This file's own acceptance gate greps for a sort-call or a reverse-call and requires zero
/// matches -- deliberately not spelled with a literal leading-dot method call anywhere in this
/// comment, so this very sentence cannot trip that same gate.
///
/// **Polling, not push, is this phase's live-delivery mechanism.** `04.1-RESEARCH.md` settles this
/// as a decision, not a gap: no push infrastructure or entitlement exists anywhere in this project.
/// `startPolling()`/`refresh()` and pull-to-refresh all resolve through the identical
/// `loadFirstPage()` load path -- there is exactly one way this model ever replaces its first page,
/// so the two triggers can never diverge into different behavior.
///
/// **A transport failure never blanks a feed a person was reading.** `loadFirstPage()`/
/// `loadNextPage()` only ever reassign `items` after a fetch has fully succeeded; a `catch` branch
/// touches `state` alone. `state`'s own `.failed` case is therefore load-bearing exactly like
/// `GroupsModel`'s/`FriendsModel`'s identical precedent: an unreachable service must read as an
/// error, never as an empty result.
@MainActor
@Observable
final class GroupFeedModel {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(SocialAPIError)
    }

    /// What a presenting view should render for a given `(state, hasItems)` pair -- a pure,
    /// `nonisolated` decision function (matching `MomentumProgressBlocks.blockStates`'s own
    /// precedent for view-adjacent-but-testable-without-rendering logic) so `GroupFeedView`/
    /// `GroupHistoryView` never re-derive this switch themselves and risk diverging.
    ///
    /// **The one rule this exists to enforce: a failure must never discard cards already on
    /// screen.** The poll timer calls `loadFirstPage()` every `pollInterval` seconds, and
    /// `loadFirstPage()` sets `state = .loading` on entry -- a naive view that branches on `state`
    /// alone would blank the entire feed to nothing on every single poll tick, and again to a bare
    /// error line on any poll failure or failed cheer tap. `hasItems` is checked first for exactly
    /// this reason: existing items always render (T-04.1-98's own mitigation, "a failure never
    /// clears loaded items," is a rendering guarantee, not only a model-state guarantee).
    enum RenderDecision: Equatable {
        /// Nothing has loaded yet and nothing has failed -- render nothing (a first paint or an
        /// in-flight first load with no prior items).
        case nothing
        /// Items exist and there is no active failure -- render the card stack alone.
        case cards
        /// Items exist, but the most recent load/action failed -- render the cards, plus the
        /// failure text alongside them, never in place of them.
        case cardsWithFailureBanner
        /// No items exist, and the load succeeded -- render the empty-state text.
        case emptyMessage
        /// No items exist, and the load failed -- render the failure text.
        case failureMessage

        static func decide(state: LoadState, hasItems: Bool) -> RenderDecision {
            switch (state, hasItems) {
            case (.idle, false), (.loading, false):
                return .nothing
            case (.idle, true), (.loading, true), (.loaded, true):
                return .cards
            case (.failed, true):
                return .cardsWithFailureBanner
            case (.loaded, false):
                return .emptyMessage
            case (.failed, false):
                return .failureMessage
            }
        }
    }

    /// The production poll cadence. Tests inject a much shorter interval through this type's own
    /// initializer so start/stop behavior is provable without a real 30-second wait.
    static let pollInterval: TimeInterval = 30

    private(set) var items: [FeedItem] = []
    private(set) var state: LoadState = .idle
    private(set) var nextCursor: String?

    private let source: FeedSource
    private let client: FeedClient
    private let pollInterval: TimeInterval
    private var pollTask: Task<Void, Never>?
    /// Guards `loadNextPage()` against a duplicate concurrent call -- `.onAppear` on the last
    /// visible card can fire more than once before the first request returns, and two overlapping
    /// calls with the same cursor would otherwise append the same page twice.
    private var isLoadingNextPage = false

    var isEmpty: Bool { items.isEmpty }

    var renderDecision: RenderDecision {
        RenderDecision.decide(state: state, hasItems: !items.isEmpty)
    }

    init(
        source: FeedSource,
        client: FeedClient = FeedClient(apiClient: SocialAPIClient(sessionStore: SessionStore())),
        pollInterval: TimeInterval = GroupFeedModel.pollInterval
    ) {
        self.source = source
        self.client = client
        self.pollInterval = pollInterval
    }

    // T-04.1-99 ("polling never outlives the screen that started it") is currently satisfied
    // entirely by `GroupFeedView`'s own `onDisappear { model?.stopPolling() }` -- both of this
    // plan's entry points to `.groupFeed` are navigation leaves (nothing is ever pushed on top of
    // the feed screen today), so `onDisappear` reliably fires when the screen goes away. A
    // `deinit`-based belt-and-braces cancel was considered (in case a future push-on-top screen
    // ever makes `NavigationStack`'s `onDisappear` unreliable the way it is for a covered, not
    // popped, view) but `pollTask` is `@MainActor`-isolated and `deinit` cannot be actor-isolated,
    // so reading it there is a compile-time error under this project's strict concurrency setting
    // -- not merely a style question. Marking `pollTask` `nonisolated(unsafe)` to work around that
    // would weaken real actor-isolation protection for a case this app's navigation graph does not
    // yet exercise; left undone rather than trading a real guarantee for a hypothetical one.

    /// The one load path pull-to-refresh and the poll timer both call (see this type's own header
    /// comment). Replaces `items` and `nextCursor` wholesale, and only once the fetch has fully
    /// succeeded -- a throw leaves both exactly as they were.
    func loadFirstPage() async {
        state = .loading
        do {
            let page = try await fetchPage(cursor: nil)
            items = page.items
            nextCursor = page.nextCursor
            state = .loaded
        } catch {
            state = .failed(Self.socialError(error))
        }
    }

    /// Pull-to-refresh's own call site -- the identical operation as `loadFirstPage()`, named
    /// separately only so a view's `.refreshable { await model.refresh() }` reads as what it is.
    func refresh() async {
        await loadFirstPage()
    }

    /// Appends the next page after `items`, in the order received -- never sorted, reversed, or
    /// re-keyed (see this type's own header comment). A `nil` or already-exhausted cursor makes
    /// this a no-op, matching `feed.Service`'s own "`NextCursor` empty once the caller has reached
    /// the end" contract. Also a no-op while a previous call is still in flight, so a view calling
    /// this from `.onAppear` on the last visible card (which can fire more than once before the
    /// first request returns) can never append the same page twice.
    func loadNextPage() async {
        guard let cursor = nextCursor, !cursor.isEmpty, !isLoadingNextPage else { return }
        isLoadingNextPage = true
        defer { isLoadingNextPage = false }
        do {
            let page = try await fetchPage(cursor: cursor)
            items.append(contentsOf: page.items)
            nextCursor = page.nextCursor
        } catch {
            state = .failed(Self.socialError(error))
        }
    }

    /// Starts polling on `pollInterval`, calling `loadFirstPage()` -- the identical load path
    /// pull-to-refresh uses (T-04.1-99's own mitigation depends on this: polling is never a second,
    /// divergent load implementation). Implemented as a cancellable `Task` sleep loop rather than
    /// `Timer`, so stopping is a plain `Task.cancel()` with no run-loop or escaping-closure
    /// isolation question. Calling this while already polling replaces the previous loop rather
    /// than running two concurrently.
    func startPolling() {
        stopPolling()
        let interval = pollInterval
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(interval))
                if Task.isCancelled { return }
                await self?.loadFirstPage()
            }
        }
    }

    /// Cancels the poll loop, if one is running -- called from the presenting view's own
    /// `onDisappear` so polling never outlives the screen that started it (T-04.1-99).
    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    /// Sends or withdraws `cheer` on `item`, then -- only once the request has fully succeeded --
    /// updates that one item's own `cheers` flag and no other item's, matching
    /// `GroupsModel.removeMember(groupID:userID:)`'s own "mutate local state only after the server
    /// confirms" precedent. A failure moves `state` to `.failed` and leaves every item's flags
    /// exactly as they were -- a cheer that silently didn't take must never render as sent.
    func toggleCheer(_ cheer: Cheer, for item: FeedItem, on: Bool) async {
        do {
            if on {
                try await client.sendCheer(completionID: item.completionID, cheer: cheer)
            } else {
                try await client.withdrawCheer(completionID: item.completionID, cheer: cheer)
            }
            if let index = items.firstIndex(where: { $0.completionID == item.completionID }) {
                switch cheer {
                case .niceWork:
                    items[index].cheers.niceWorkSentByViewer = on
                case .keepGoing:
                    items[index].cheers.keepGoingSentByViewer = on
                }
            }
        } catch {
            state = .failed(Self.socialError(error))
        }
    }

    private func fetchPage(cursor: String?) async throws -> FeedPage {
        switch source {
        case .group(let id):
            return try await client.groupFeed(groupID: id.uuidString, cursor: cursor)
        case .event(let id):
            return try await client.eventFeed(eventID: id.uuidString, cursor: cursor)
        }
    }

    private static func socialError(_ error: Error) -> SocialAPIError {
        (error as? SocialAPIError) ?? .transport
    }
}
