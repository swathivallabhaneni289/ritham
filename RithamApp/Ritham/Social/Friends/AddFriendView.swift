import SwiftUI
import RithamCore

/// Exactly three closed-loop ways to connect (`docs/group-events.md` §1), no fourth anywhere on
/// this screen, and no field for typing a person's name at all -- that absence is the requirement,
/// not an omission. §1 rules out public profile search entirely, citing Peloton's May 2024
/// incident, where full legal names and searchable profiles became visible by default (opt-out,
/// not opt-in) and caught users off guard about years of activity suddenly tied to a discoverable
/// identity. A later editor reading this file should read the missing search entry point as a
/// deliberate structural choice, not a gap to fill in.
///
/// Row copy comes from `SocialCopy.AddFriend` exclusively, never re-authored inline here.
///
/// **Row 2 and row 3 share one server mechanism.** Both "Invite link or QR code" and "Share
/// directly" create the identical kind of invite through `FriendsModel.createInvite()` and present
/// `InviteQRView` -- there is no second, separate "direct share" server primitive to call. §1's
/// third connection path (in-person/direct share, "text, AirDrop-style") describes a transmission
/// *channel* for the same expiring invite token, not a second mechanism: row 2 presents the QR
/// code for someone right next to you to scan, row 3 presents the identical screen with the
/// system share sheet already open on top of it, so the text/AirDrop path is one tap away instead
/// of two. `FriendConnectionPath.directShare` (`FriendsClient.send(toUserID:path:)`'s own
/// direct-request path) stays unwired by this screen -- a genuine, separate in-person mechanism
/// would need URL-scheme or universal-link handling that exists nowhere in this app yet, and
/// nothing in this plan names building it.
///
/// **Contact matching's opt-in records the flag only, and submits no digests.** The two-option
/// chip control below follows the established precedent for a binary preference in this app (the
/// Daily Movement Snapshot's own opt-in screen), never a native switch control, matching this
/// codebase's zero precedent for that control and the measured-contrast reasoning that precedent
/// documents. Turning the opt-in on calls `FriendsModel.setContactMatchOptIn(_:)`, which records
/// `contact_match_optins.opted_in = true` server-side -- genuinely enough, on its own, to unlock
/// `MatchContacts` for a future caller, since that route gates on the opted-in flag alone
/// (`RithamService/internal/friends/contactmatch.go`). What this screen does NOT do, and this is a
/// deliberate scope boundary rather than an oversight: request the device's Contacts permission,
/// read the address book, or submit any digest. `SetContactMatchOptIn`'s own `identifierDigests`
/// field is for a user's OWN identifiers (e.g. their own phone number), never someone else's --
/// this app has no source for a user's own phone/email today (`SessionStore` holds a display name
/// only; the Sign in with Apple request asks for `.fullName`, never an email or phone scope), so
/// `contact_match_digests` stays empty for every user of this app version regardless of what any
/// individual screen submits. Requesting Contacts access here and hashing the address book would
/// put real data on the wire (and require the permission prompt to justify itself) for a query
/// that is structurally guaranteed to return zero matches until a future plan adds a legitimate
/// way to collect a user's own identifier. See this plan's own Known Stubs section for the
/// tracked follow-up.
struct AddFriendView: View, OnboardingStepPresenting {
    static let step: OnboardingStep = .addFriend

    static func makeView(flow: OnboardingFlow) -> AnyView {
        AnyView(AddFriendView(flow: flow))
    }

    let flow: OnboardingFlow

    @State private var model = FriendsModel()
    @State private var isContactMatchExpanded = false
    @State private var contactMatchSelection: Set<ContactMatchOptInOption> = [ContactMatchOptInOption(isOn: false)]
    @State private var presentedInvite: PresentedInvite?
    @State private var isCreatingInvite = false

    var body: some View {
        RithamScreen(surface: DecorativeSurface.flat, headline: "Add a friend") {
            connectionRow(icon: "person.crop.circle.badge.questionmark", title: SocialCopy.AddFriend.contactMatchingRow) {
                isContactMatchExpanded.toggle()
            }

            if isContactMatchExpanded {
                ChoiceQuestionView(
                    prompt: "Let contacts who also opted in find you",
                    options: ContactMatchOptInOption.all,
                    mode: .single,
                    selection: $contactMatchSelection,
                    optionTitle: Self.optionTitle
                )
            }

            connectionRow(icon: "qrcode", title: SocialCopy.AddFriend.inviteLinkRow) {
                Task { await presentInvite(autoShare: false) }
            }

            connectionRow(icon: "square.and.arrow.up", title: SocialCopy.AddFriend.inPersonRow) {
                Task { await presentInvite(autoShare: true) }
            }

            SecondaryCTAButton(title: "Back") {
                flow.goBack()
            }
        }
        .onChange(of: contactMatchSelection) { _, newValue in
            guard let chosen = newValue.first else { return }
            Task { await model.setContactMatchOptIn(chosen.isOn) }
        }
        .sheet(item: $presentedInvite) { invite in
            InviteQRView(token: invite.token, autoPresentsShareSheet: invite.autoShare)
        }
    }

    private func presentInvite(autoShare: Bool) async {
        guard !isCreatingInvite else { return }
        isCreatingInvite = true
        defer { isCreatingInvite = false }
        if let token = await model.createInvite() {
            presentedInvite = PresentedInvite(token: token, autoShare: autoShare)
        }
    }

    @ViewBuilder
    private func connectionRow(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: RithamSpacing.sm) {
                SectionIconBadge(systemName: icon)
                Text(title)
                    .font(RithamType.body)
                    .foregroundStyle(RithamColor.paper)
                Spacer()
            }
            .frame(minHeight: RithamSpacing.minimumTapTarget)
            .padding(.horizontal, RithamSpacing.md)
            .overlay(
                RoundedRectangle(cornerRadius: RithamSpacing.sm)
                    .stroke(RithamColor.paper, lineWidth: 1)
            )
        }
        .accessibilityLabel(title)
    }

    private static func optionTitle(_ option: ContactMatchOptInOption) -> String {
        option.isOn ? "On" : "Off"
    }
}

/// Wraps a freshly created `InviteToken` with which of `AddFriendView`'s two invite rows produced
/// it, so `.sheet(item:)` can present `InviteQRView` with the right `autoPresentsShareSheet` value
/// for either row from one shared presentation point.
private struct PresentedInvite: Identifiable {
    let token: InviteToken
    let autoShare: Bool
    var id: String { token.token }
}

/// The two states the contact-match opt-in can be in, wrapped for `ChoiceQuestionView`'s
/// `Identifiable` requirement -- the same rationale `WeeklyFrequencyOption`/`MomentumTargetOption`
/// already document: a bare `Bool` has no natural single UI-option identity of its own.
private struct ContactMatchOptInOption: Hashable, Identifiable {
    let isOn: Bool
    var id: Bool { isOn }

    static let all: [ContactMatchOptInOption] = [
        ContactMatchOptInOption(isOn: true),
        ContactMatchOptInOption(isOn: false),
    ]
}
