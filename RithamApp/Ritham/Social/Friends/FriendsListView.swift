import SwiftUI
import RithamCore

/// The friend-circle surface: incoming requests above the established friend list. Registered
/// under `.friendsList`, reached from `HomeHubView`'s signed-in social section
/// (`04.1-05-SUMMARY.md`'s own recorded handoff, closed by this plan).
///
/// Every list here is a plain vertical stack of the existing card shell (a rounded rectangle on a
/// low-opacity `paper` fill, matching `PrivacyZonesView`'s row shape and Phase 4's Dashboard
/// Section Card precedent) -- this codebase has zero uses of the platform's built-in
/// collection/grouping containers, and this screen does not introduce the first one.
///
/// A friend row shows exactly an avatar and a name -- no online/status indicator, no
/// mutual-groups count, no join date, nothing a viewer could use to compare two rows against each
/// other (T-04.1-55). `Friendship.establishedAt` exists on the domain type for completeness but is
/// never read by this file for exactly that reason.
///
/// Declining an incoming request is deliberately not styled as a destructive action: declining
/// deletes nothing and severs no existing connection, so the red/destructive treatment this app
/// reserves for irreversible removals (unfriending, leaving a group) would misrepresent what
/// declining actually does. `RithamColor.hot`, this screen's one accent use, appears only on the
/// accept action -- every other control here uses the neutral `paper` outline/fill vocabulary.
struct FriendsListView: View, OnboardingStepPresenting {
    static let step: OnboardingStep = .friendsList

    static func makeView(flow: OnboardingFlow) -> AnyView {
        AnyView(FriendsListView(flow: flow))
    }

    let flow: OnboardingFlow

    @State private var model = FriendsModel()
    @State private var friendPendingUnfriend: Friendship?

    var body: some View {
        RithamScreen(surface: DecorativeSurface.flat, headline: "Friends") {
            switch model.state {
            case .idle, .loading:
                EmptyView()
            case .failed:
                Text("Couldn't load your friends. Check your connection and try again.")
                    .font(RithamType.body)
                    .foregroundStyle(RithamColor.paper)
                    .fixedSize(horizontal: false, vertical: true)
            case .loaded:
                loadedContent
            }

            SecondaryCTAButton(title: "Add a friend") {
                flow.open(.addFriend)
            }

            SecondaryCTAButton(title: "Back") {
                flow.goBack()
            }
        }
        .task { await model.load() }
        .confirmationDialog(
            "Remove this friend?",
            isPresented: Binding(
                get: { friendPendingUnfriend != nil },
                set: { if !$0 { friendPendingUnfriend = nil } }
            ),
            presenting: friendPendingUnfriend
        ) { friend in
            Button("Remove", role: .destructive) {
                Task {
                    await model.unfriend(friend)
                    friendPendingUnfriend = nil
                }
            }
            Button("Cancel", role: .cancel) {
                friendPendingUnfriend = nil
            }
        }
    }

    @ViewBuilder
    private var loadedContent: some View {
        if !model.incoming.isEmpty {
            VStack(alignment: .leading, spacing: RithamSpacing.sm) {
                Text("Requests")
                    .font(RithamType.heading)
                    .foregroundStyle(RithamColor.paper)

                VStack(spacing: RithamSpacing.sm) {
                    ForEach(model.incoming) { request in
                        incomingRequestRow(request)
                    }
                }
            }
        }

        VStack(alignment: .leading, spacing: RithamSpacing.sm) {
            Text("Your friends")
                .font(RithamType.heading)
                .foregroundStyle(RithamColor.paper)

            if model.friends.isEmpty {
                Text("No friends yet. Add one below.")
                    .font(RithamType.body)
                    .foregroundStyle(RithamColor.paper)
            } else {
                VStack(spacing: RithamSpacing.sm) {
                    ForEach(model.friends) { friend in
                        friendRow(friend)
                    }
                }
            }
        }
    }

    // MARK: - Rows

    @ViewBuilder
    private func incomingRequestRow(_ request: FriendRequest) -> some View {
        HStack(spacing: RithamSpacing.sm) {
            AvatarView(name: request.fromDisplayName, diameter: 36)

            Text(request.fromDisplayName)
                .font(RithamType.body)
                .foregroundStyle(RithamColor.paper)

            Spacer()

            HStack(spacing: RithamSpacing.sm) {
                Button {
                    Task { await model.accept(request) }
                } label: {
                    Text("Accept")
                        .font(RithamType.body.weight(.semibold))
                        .foregroundStyle(RithamColor.label(on: RithamColor.hot))
                        .frame(minWidth: RithamSpacing.minimumTapTarget, minHeight: RithamSpacing.minimumTapTarget)
                        .padding(.horizontal, RithamSpacing.sm)
                        .background(RithamColor.hot)
                        .clipShape(RoundedRectangle(cornerRadius: RithamSpacing.sm))
                }
                .accessibilityLabel("Accept request from \(request.fromDisplayName)")

                Button {
                    Task { await model.decline(request) }
                } label: {
                    Text("Decline")
                        .font(RithamType.body)
                        .foregroundStyle(RithamColor.paper)
                        .frame(minWidth: RithamSpacing.minimumTapTarget, minHeight: RithamSpacing.minimumTapTarget)
                        .padding(.horizontal, RithamSpacing.sm)
                        .overlay(
                            RoundedRectangle(cornerRadius: RithamSpacing.sm)
                                .stroke(RithamColor.paper, lineWidth: 1)
                        )
                }
                .accessibilityLabel("Decline request from \(request.fromDisplayName)")
            }
        }
        .padding(RithamSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: RithamSpacing.sm)
                .fill(RithamColor.paper.opacity(0.06))
        )
    }

    @ViewBuilder
    private func friendRow(_ friend: Friendship) -> some View {
        HStack(spacing: RithamSpacing.sm) {
            AvatarView(name: friend.displayName, diameter: 36)

            Text(friend.displayName)
                .font(RithamType.body)
                .foregroundStyle(RithamColor.paper)

            Spacer()

            Button {
                friendPendingUnfriend = friend
            } label: {
                Text("Remove")
                    .font(RithamType.body)
                    .foregroundStyle(RithamColor.paper)
                    .frame(minWidth: RithamSpacing.minimumTapTarget, minHeight: RithamSpacing.minimumTapTarget)
            }
            .accessibilityLabel("Remove \(friend.displayName) as a friend")
        }
        .padding(RithamSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: RithamSpacing.sm)
                .fill(RithamColor.paper.opacity(0.06))
        )
    }
}
