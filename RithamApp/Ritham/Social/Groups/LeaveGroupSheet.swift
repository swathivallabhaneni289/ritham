import SwiftUI
import RithamCore

/// The two dispositions a leaver can choose for their past posts, wrapped for
/// `ChoiceQuestionView`'s `Identifiable` requirement -- the same rationale
/// `MovementSnapshotOptInOption`/`WeeklyFrequencyOption` already document: `GroupLeaveDisposition`
/// has no natural single UI-option identity of its own beyond itself.
struct GroupLeaveDispositionOption: Hashable, Identifiable {
    let disposition: GroupLeaveDisposition
    var id: GroupLeaveDisposition { disposition }

    static let all: [GroupLeaveDispositionOption] = GroupLeaveDisposition.allCases.map(GroupLeaveDispositionOption.init)
}

/// The leave-group confirmation: a plain statement of what leaving costs, the explicit
/// keep/remove-past-posts choice, and a destructive confirm action.
///
/// **Neither disposition option is preselected, and the confirm action is disabled until one is
/// chosen.** This is the requirement this file exists to satisfy, not a nicety:
/// `docs/group-events.md` §4 says the app should offer this choice explicitly at the leave step
/// rather than leaving it as an unstated default either way -- and a preselected chip is an
/// unstated default with one extra tap between it and the same silent outcome. `selection` below
/// therefore starts as an empty set (never seeded with either
/// `GroupLeaveDispositionOption`), and the confirm button is disabled for as long as it stays
/// empty. `ChoiceQuestionView`'s `.single` mode is what makes an empty starting `Set` meaningful
/// here: nothing renders as selected until the person taps one of the two chips themselves.
///
/// Replaces Task 2's minimal stub wholesale (04.1-11-SUMMARY.md's own stub-then-extend record).
struct LeaveGroupSheet: View {
    @Environment(\.dismiss) private var dismiss
    let groupID: UUID
    let model: GroupsModel
    let onLeft: () -> Void

    @State private var selection: Set<GroupLeaveDispositionOption> = []
    @State private var isLeaving = false

    var body: some View {
        RithamScreen(surface: DecorativeSurface.flat, headline: SocialCopy.Groups.leaveGroupButton) {
            Text(SocialCopy.Groups.leaveGroupConfirmation)
                .font(RithamType.body)
                .foregroundStyle(RithamColor.paper)
                .fixedSize(horizontal: false, vertical: true)

            ChoiceQuestionView(
                prompt: SocialCopy.Groups.pastPostsPrompt,
                options: GroupLeaveDispositionOption.all,
                mode: .single,
                selection: $selection,
                optionTitle: Self.optionTitle
            )

            DestructiveCTAButton(title: SocialCopy.Groups.leaveGroupButton) {
                Task { await leave() }
            }
            .disabled(selection.isEmpty || isLeaving)

            SecondaryCTAButton(title: "Cancel") {
                dismiss()
            }
        }
    }

    static func optionTitle(_ option: GroupLeaveDispositionOption) -> String {
        switch option.disposition {
        case .keepPastPosts:
            return SocialCopy.Groups.keepPastPostsOption
        case .removePastPosts:
            return SocialCopy.Groups.removePastPostsOption
        }
    }

    private func leave() async {
        guard let chosen = selection.first?.disposition else { return }
        isLeaving = true
        await model.leave(groupID: groupID, disposition: chosen)
        isLeaving = false
        dismiss()
        onLeft()
    }
}
