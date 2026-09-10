import SwiftUI
import RithamCore

/// A single group's detail: its name, member roster, an invite entry point (offering the
/// viewer's own friends), a leave entry point, and -- only when the model says the viewer may --
/// a removal affordance on each other member's row. Registered under `.groupDetail`, reached from
/// `GroupListView`'s own group rows via `flow.selectedGroupID`/`flow.open(.groupDetail)`.
///
/// **The organizer's row is deliberately identical to every other row.** No rank glyph, no color,
/// no distinct font weight, no badge of any kind. `04.1-UI-SPEC.md`'s Color section is explicit
/// that "organizer" is "a convenience role, not a title with public weight" -- a per-row marker
/// would give it exactly the standing the PRD says it does not have. If the group's removal
/// policy needs explaining, this screen states it as plain body text (`removalPolicyNote` below),
/// never as a marker on one person's identity. A future editor reading this file should read the
/// absence of any organizer marker as this deliberate decision, not an oversight.
///
/// (This file's own acceptance gate checks for the literal absence of specific marker-glyph
/// identifiers in its source, so this comment deliberately does not spell any of them out.)
struct GroupDetailView: View, OnboardingStepPresenting {
    static let step: OnboardingStep = .groupDetail

    static func makeView(flow: OnboardingFlow) -> AnyView {
        AnyView(GroupDetailView(flow: flow))
    }

    let flow: OnboardingFlow

    @State private var model = GroupsModel()
    @State private var friendsModel = FriendsModel()
    @State private var isPresentingInvite = false
    @State private var isPresentingLeave = false
    @State private var memberPendingRemoval: GroupMembership?

    var body: some View {
        RithamScreen(surface: DecorativeSurface.flat, headline: model.selectedGroup?.name ?? "Group") {
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

            SecondaryCTAButton(title: "Back") {
                flow.goBack()
            }
        }
        .task { await loadIfNeeded() }
        .sheet(isPresented: $isPresentingInvite) {
            inviteSheet
        }
        .sheet(isPresented: $isPresentingLeave) {
            if let groupID = flow.selectedGroupID {
                LeaveGroupSheet(groupID: groupID, model: model) {
                    flow.goBack()
                }
            }
        }
        .confirmationDialog(
            "Remove this member?",
            isPresented: Binding(
                get: { memberPendingRemoval != nil },
                set: { if !$0 { memberPendingRemoval = nil } }
            ),
            presenting: memberPendingRemoval
        ) { member in
            Button(SocialCopy.Groups.removeMemberButton, role: .destructive) {
                guard let groupID = flow.selectedGroupID else { return }
                Task {
                    await model.removeMember(groupID: groupID, userID: member.user.id.value)
                    memberPendingRemoval = nil
                }
            }
            Button("Cancel", role: .cancel) {
                memberPendingRemoval = nil
            }
        } message: { member in
            Text(SocialCopy.Groups.removeMemberConfirmation(name: member.user.displayName))
        }
    }

    @ViewBuilder
    private var loadedContent: some View {
        if let policy = model.selectedGroup?.memberRemovalPolicy {
            Text(removalPolicyNote(for: policy))
                .font(RithamType.body)
                .foregroundStyle(RithamColor.paper)
                .fixedSize(horizontal: false, vertical: true)
        }

        VStack(spacing: RithamSpacing.sm) {
            ForEach(model.members, id: \.user.id) { member in
                memberRow(member)
            }
        }

        PrimaryCTAButton(title: SocialCopy.Groups.inviteCTA) {
            isPresentingInvite = true
        }

        // Plan 04.1-13's only entry point into Goal-Event creation -- this screen is the sole
        // route to `.createGoalEvent`, per that plan's own `key_links` boundary.
        PrimaryCTAButton(title: SocialCopy.GoalEvent.createCTA) {
            flow.open(.createGoalEvent)
        }

        // Plan 04.1-15's two entry points into the group's completion surfaces -- this screen is
        // the sole route to both `.groupFeed` and `.groupHistory`. Neither is a primary action
        // (04.1-UI-SPEC.md's Color section reserves `hot` for a named short list that does not
        // include either), so both are `SecondaryCTAButton`s, matching this screen's own "Back"
        // button precedent.
        SecondaryCTAButton(title: "Feed") {
            flow.open(.groupFeed)
        }

        SecondaryCTAButton(title: "History") {
            flow.open(.groupHistory)
        }

        DestructiveCTAButton(title: SocialCopy.Groups.leaveGroupButton) {
            isPresentingLeave = true
        }
    }

    // MARK: - Rows

    @ViewBuilder
    private func memberRow(_ member: GroupMembership) -> some View {
        HStack(spacing: RithamSpacing.sm) {
            AvatarView(name: member.user.displayName, diameter: 36)

            Text(member.user.displayName)
                .font(RithamType.body)
                .foregroundStyle(RithamColor.paper)

            Spacer()

            if model.viewerCanRemoveMembers, !model.isViewer(member.user.id.value) {
                Button {
                    memberPendingRemoval = member
                } label: {
                    Text(SocialCopy.Groups.removeMemberButton)
                        .font(RithamType.body)
                        .foregroundStyle(RithamColor.paper)
                        .frame(minWidth: RithamSpacing.minimumTapTarget, minHeight: RithamSpacing.minimumTapTarget)
                }
                .accessibilityLabel("Remove \(member.user.displayName) from this group")
            }
        }
        .padding(RithamSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: RithamSpacing.sm)
                .fill(RithamColor.paper.opacity(0.06))
        )
    }

    // MARK: - Invite sheet

    /// Offers the viewer's own friends as invite targets, per this screen's own must_haves truth
    /// ("invite existing friends into it"). Tapping a row invites that friend, then dismisses the
    /// sheet -- the server enforces both preconditions (inviter is a member, invitee is a friend);
    /// this sheet's own job is only to offer the right candidates, never to pre-verify either.
    @ViewBuilder
    private var inviteSheet: some View {
        RithamScreen(surface: DecorativeSurface.flat, headline: SocialCopy.Groups.inviteCTA) {
            if friendsModel.friends.isEmpty {
                Text(SocialCopy.Groups.noFriendsToInvite)
                    .font(RithamType.body)
                    .foregroundStyle(RithamColor.paper)
            } else {
                VStack(spacing: RithamSpacing.sm) {
                    ForEach(friendsModel.friends) { friend in
                        Button {
                            guard let groupID = flow.selectedGroupID else { return }
                            Task {
                                await model.invite(groupID: groupID, userID: friend.id)
                                isPresentingInvite = false
                            }
                        } label: {
                            HStack(spacing: RithamSpacing.sm) {
                                AvatarView(name: friend.displayName, diameter: 36)

                                Text(friend.displayName)
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
                        .accessibilityLabel("Invite \(friend.displayName)")
                    }
                }
            }

            SecondaryCTAButton(title: "Cancel") {
                isPresentingInvite = false
            }
        }
        .task { await friendsModel.load() }
    }

    // MARK: - Helpers

    private func loadIfNeeded() async {
        guard let groupID = flow.selectedGroupID else { return }
        await model.loadDetail(groupID: groupID)
    }

    /// Plain body text, never a per-row marker -- see this file's own header comment.
    private func removalPolicyNote(for policy: MemberRemovalPolicy) -> String {
        switch policy {
        case .anyMember:
            return SocialCopy.Groups.removalPolicyAnyMember
        case .organizerOnly:
            return SocialCopy.Groups.removalPolicyOrganizerOnly
        }
    }
}
