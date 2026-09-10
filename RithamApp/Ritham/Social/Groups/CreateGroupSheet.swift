import SwiftUI
import RithamCore

// Deviation from this plan's stated file list (Rule 2 -- missing critical functionality): Task
// 2's action text asks for "a create-group action [that] uses the primary CTA" but names no
// mechanism for actually naming the group, and `GroupListView.swift`'s own acceptance criterion
// (`grep -c 'TextField'` == 0) forbids collecting that name inline on the list screen itself. A
// silently auto-named group (e.g. always "New Group") would ship the create action without the
// one piece of information a group fundamentally needs -- its name -- so this sheet exists,
// following `AddPrivacyZoneView.swift`'s own established "the field lives on its own small sheet
// file, never on the list screen it's presented from" shape (plan 04.1-07).

/// A minimal, single-field creation sheet: a name, a create action, and a cancel action. The
/// removal policy is left at the server's own default (`anyMember`) -- this plan builds no
/// policy-picker UI (04.1-UI-SPEC.md's Groups section describes the policy as something explained
/// in plain text, never something chosen through an interactive control on this screen).
struct CreateGroupSheet: View {
    @Environment(\.dismiss) private var dismiss
    let model: GroupsModel

    @State private var name = ""
    @State private var showSaveError = false
    @State private var isSaving = false

    var body: some View {
        RithamScreen(surface: DecorativeSurface.flat, headline: SocialCopy.Groups.createHeadline) {
            nameField

            if showSaveError {
                Text(OnboardingCopy.Errors.savingFailed)
                    .font(RithamType.label)
                    .foregroundStyle(RithamColor.hot)
                    .fixedSize(horizontal: false, vertical: true)
            }

            PrimaryCTAButton(title: SocialCopy.Groups.createCTA) {
                Task { await create() }
            }
            .disabled(isSaving)

            SecondaryCTAButton(title: "Cancel") {
                dismiss()
            }
        }
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: RithamSpacing.xs) {
            Text(SocialCopy.Groups.nameFieldLabel)
                .font(RithamType.label)
                .foregroundStyle(RithamColor.paper)

            TextField(SocialCopy.Groups.nameFieldPlaceholder, text: $name)
                .font(RithamType.body)
                .foregroundStyle(RithamColor.paper)
                .padding(RithamSpacing.sm)
                .frame(minHeight: RithamSpacing.minimumTapTarget)
                .background(
                    RoundedRectangle(cornerRadius: RithamSpacing.sm)
                        .stroke(RithamColor.paper, lineWidth: 1)
                )
                .accessibilityLabel(SocialCopy.Groups.nameFieldLabel)
        }
    }

    private func create() async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            showSaveError = true
            return
        }
        isSaving = true
        let group = await model.create(name: trimmedName, policy: nil)
        isSaving = false
        if group != nil {
            dismiss()
        } else {
            showSaveError = true
        }
    }
}
