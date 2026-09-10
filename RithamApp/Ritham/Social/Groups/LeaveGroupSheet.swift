import SwiftUI
import RithamCore

// Stub-then-extend (this codebase's own 02-03/04.1-09 precedent): Task 2 needs this type to
// exist so GroupDetailView.swift compiles and can present a leave entry point, but the real,
// required, no-preselected-default keep/remove-past-posts choice is Task 3's own scope. This
// minimal stub is replaced wholesale in Task 3 -- see that task's commit for the real
// implementation and its own header comment.
struct LeaveGroupSheet: View {
    @Environment(\.dismiss) private var dismiss
    let groupID: UUID
    let model: GroupsModel
    let onLeft: () -> Void

    var body: some View {
        RithamScreen(surface: DecorativeSurface.flat, headline: SocialCopy.Groups.leaveGroupButton) {
            Text(SocialCopy.Groups.leaveGroupConfirmation)
                .font(RithamType.body)
                .foregroundStyle(RithamColor.paper)
                .fixedSize(horizontal: false, vertical: true)

            DestructiveCTAButton(title: SocialCopy.Groups.leaveGroupButton) {
                Task {
                    await model.leave(groupID: groupID, disposition: .keepPastPosts)
                    dismiss()
                    onLeft()
                }
            }

            SecondaryCTAButton(title: "Cancel") {
                dismiss()
            }
        }
    }
}
