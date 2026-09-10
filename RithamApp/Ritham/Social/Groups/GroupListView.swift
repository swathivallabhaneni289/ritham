import SwiftUI
import RithamCore

/// The group surface's entry screen: a plain stack of the user's groups, each a card carrying a
/// rounded-square group badge (`SectionIconBadge`, never circular -- distinguishing group
/// identity from a person's circular `AvatarView` at a glance, per `04.1-UI-SPEC.md`'s Groups
/// section) and the group's own name. Registered under `.groupList`, reached from `HomeHubView`'s
/// signed-in social section alongside `.friendsList`.
///
/// There is no search field and no browse affordance anywhere on this screen -- no such tier
/// exists to browse (`docs/group-events.md` §1, T-04.1-65). Every list here is a plain vertical
/// stack of the existing card shell, matching `FriendsListView`'s own precedent; this codebase has
/// zero uses of the platform's built-in collection/grouping containers.
///
/// **No pending-invitations section.** `groups_handler.go` exposes exactly nine routes
/// (04.1-08-SUMMARY.md); there is no route to list a user's own pending invitations, and
/// `groups.Service` has no method to produce that list at all. Rendering an "Invitations" section
/// here would be a hardcoded-empty-value stub that can never populate -- see
/// `GroupsModel.swift`'s header comment and `04.1-11-SUMMARY.md`'s Known Stubs for the full
/// record of this gap.
struct GroupListView: View, OnboardingStepPresenting {
    static let step: OnboardingStep = .groupList

    static func makeView(flow: OnboardingFlow) -> AnyView {
        AnyView(GroupListView(flow: flow))
    }

    let flow: OnboardingFlow

    @State private var model = GroupsModel()
    @State private var isPresentingCreateGroup = false

    var body: some View {
        RithamScreen(surface: DecorativeSurface.flat, headline: "Groups") {
            switch model.state {
            case .idle, .loading:
                EmptyView()
            case .failed:
                Text(SocialCopy.Groups.loadFailed)
                    .font(RithamType.body)
                    .foregroundStyle(RithamColor.paper)
                    .fixedSize(horizontal: false, vertical: true)
            case .loaded:
                loadedContent
            }

            PrimaryCTAButton(title: SocialCopy.Groups.createCTA) {
                isPresentingCreateGroup = true
            }

            SecondaryCTAButton(title: "Back") {
                flow.goBack()
            }
        }
        .task { await model.load() }
        .sheet(isPresented: $isPresentingCreateGroup) {
            CreateGroupSheet(model: model)
        }
    }

    @ViewBuilder
    private var loadedContent: some View {
        if model.groups.isEmpty {
            Text(SocialCopy.Groups.noGroupsYet)
                .font(RithamType.body)
                .foregroundStyle(RithamColor.paper)
        } else {
            VStack(spacing: RithamSpacing.sm) {
                ForEach(model.groups, id: \.id) { group in
                    groupRow(group)
                }
            }
        }
    }

    @ViewBuilder
    private func groupRow(_ group: SocialGroup) -> some View {
        Button {
            flow.selectedGroupID = group.id
            flow.open(.groupDetail)
        } label: {
            HStack(spacing: RithamSpacing.sm) {
                SectionIconBadge(systemName: "person.3.fill")

                Text(group.name)
                    .font(RithamType.body)
                    .foregroundStyle(RithamColor.paper)

                Spacer()
            }
            .padding(RithamSpacing.md)
            .frame(minHeight: RithamSpacing.minimumTapTarget)
            .background(
                RoundedRectangle(cornerRadius: RithamSpacing.sm)
                    .fill(RithamColor.paper.opacity(0.06))
            )
        }
        .accessibilityLabel(group.name)
    }
}
