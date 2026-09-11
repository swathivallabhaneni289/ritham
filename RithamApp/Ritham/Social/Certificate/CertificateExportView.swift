import SwiftUI
import RithamCore

/// GROUPEVENTS-05's export flow: a preview of exactly what leaves Ritham, an editable display-name
/// field, and the multi-person consent gate over a photo-bearing certificate.
///
/// **Why the display-name field exists, and what it does and does not touch.** This is the second
/// half of the two-moment disclosure check plan 04.1-13 started at Goal-Event creation time. An
/// event name is free text, and free text can itself disclose a place or a person -- the organizer
/// already got a brief nudge about that when they typed it. The person exporting a certificate is
/// usually someone else entirely, who did not write that name and may not have noticed what it
/// gives away. Renaming here changes only the composed export image this screen builds locally --
/// it is never sent anywhere, never touches the group's own copy of the event name, and needs
/// nobody else's involvement. This is the one sanctioned free-text field in this phase's export
/// path, distinct from the health screening questionnaire's own no-free-text rule, which governs a
/// different surface entirely.
///
/// **Why the default export is the branded graphic, not the person's photo.** The default carries
/// no image containing other people to leak by accident -- closing `docs/group-events.md` §5's
/// first named leak path before consent is even a question, structurally rather than by review.
/// Swapping to it is always available and always needs no consent query at all.
struct CertificateExportView: View {
    let content: CertificateContent

    @State private var model = CertificateExportModel()
    @State private var displayName: String
    @State private var useDefaultTemplate = false
    @State private var isPresentingShareSheet = false

    init(content: CertificateContent, model: CertificateExportModel = CertificateExportModel()) {
        self.content = content
        self._model = State(initialValue: model)
        self._displayName = State(initialValue: content.eventDisplayName)
    }

    /// The content this screen actually composes and, on export, shares -- `content` with the
    /// editable display name substituted in, and the photo dropped entirely when the default
    /// template is chosen. Never read anywhere on the network path: `displayName`'s only effect is
    /// on this locally-composed value.
    private var exportContent: CertificateContent {
        var exported = content
        exported.eventDisplayName = displayName
        if useDefaultTemplate {
            exported.photo = nil
        }
        return exported
    }

    var body: some View {
        RithamScreen(surface: DecorativeSurface.flat, headline: SocialCopy.Certificate.exportCTA) {
            Text(SocialCopy.Certificate.exportPreviewLabel)
                .font(RithamType.body)
                .foregroundStyle(RithamColor.paper)
                .fixedSize(horizontal: false, vertical: true)

            CertificateCardView(content: exportContent)

            displayNameField

            if content.photo != nil && !useDefaultTemplate {
                gateSection
            }

            exportButton
        }
        .task(id: useDefaultTemplate) {
            await model.checkExportGate(for: useDefaultTemplate ? nil : content.photo)
        }
        .sheet(isPresented: $isPresentingShareSheet) {
            if let image = CertificateComposer.render(exportContent) {
                CertificateShareSheet(activityItems: [image])
            }
        }
    }

    @ViewBuilder
    private var displayNameField: some View {
        VStack(alignment: .leading, spacing: RithamSpacing.sm) {
            Text(SocialCopy.Certificate.displayNameFieldLabel)
                .font(RithamType.label)
                .foregroundStyle(RithamColor.paper)

            TextField(SocialCopy.Certificate.displayNameFieldLabel, text: $displayName)
                .font(RithamType.body)
                .foregroundStyle(RithamColor.paper)
                .padding(RithamSpacing.sm)
                .overlay(
                    RoundedRectangle(cornerRadius: RithamSpacing.sm)
                        .stroke(RithamColor.paper.opacity(0.2), lineWidth: 1)
                )
        }
    }

    @ViewBuilder
    private var gateSection: some View {
        switch model.gateState {
        case .blocked:
            Text(SocialCopy.Certificate.multiPersonExportBlock)
                .font(RithamType.label)
                .foregroundStyle(RithamColor.hot)
                .fixedSize(horizontal: false, vertical: true)

            SecondaryCTAButton(title: SocialCopy.Certificate.useDefaultTemplateCTA) {
                useDefaultTemplate = true
            }
        case .checking:
            ProgressView()
        case .failed:
            Text(SocialCopy.Certificate.exportGateCheckFailed)
                .font(RithamType.label)
                .foregroundStyle(RithamColor.hot)
                .fixedSize(horizontal: false, vertical: true)

            SecondaryCTAButton(title: SocialCopy.Certificate.retryExportGateCheckCTA) {
                Task { await model.checkExportGate(for: useDefaultTemplate ? nil : content.photo) }
            }

            SecondaryCTAButton(title: SocialCopy.Certificate.useDefaultTemplateCTA) {
                useDefaultTemplate = true
            }
        case .notNeeded, .allowed:
            EmptyView()
        }
    }

    private var exportButton: some View {
        PrimaryCTAButton(title: SocialCopy.Certificate.exportCTA) {
            isPresentingShareSheet = true
        }
        .disabled(!model.canExport)
    }
}

/// The export gate this screen queries before enabling its own export action -- a small,
/// file-scoped `@Observable` model rather than a separate file, matching
/// `CompletionAttachOption`'s own "declare a helper type in the same file it's used" precedent
/// from this same phase.
@MainActor
@Observable
final class CertificateExportModel {
    enum GateState: Equatable {
        /// No photo is being exported at all (the default template, or a certificate that never
        /// carried one) -- no consent query is ever made in this state.
        case notNeeded
        case checking
        case allowed
        /// `awaitingCount` is exposed for callers that want it, but the block message itself never
        /// names a number -- naming who or how many remain would itself be exactly the kind of
        /// count this phase's non-comparative rules forbid on a completion-adjacent surface.
        case blocked(awaitingCount: Int)
        case failed
    }

    private(set) var gateState: GateState = .notNeeded

    /// Exposed only so a test can prove a default-template certificate never queries the network
    /// at all -- never read by this type's own logic.
    private(set) var queryCount = 0

    private let client: FeedClient

    init(client: FeedClient = FeedClient(apiClient: SocialAPIClient(sessionStore: SessionStore()))) {
        self.client = client
    }

    /// Export is enabled whenever no photo needs anyone else's consent, or every recorded subject
    /// has already granted it -- never while a query is in flight, and never on a failed query
    /// (fails closed, matching the server's own `ExportAllowed` default-deny-until-proven
    /// precedent for a check that could not complete).
    var canExport: Bool {
        switch gateState {
        case .notNeeded, .allowed: return true
        case .checking, .blocked, .failed: return false
        }
    }

    /// Queries the export-consent gate for `photo`, or skips the query entirely when `photo` is
    /// `nil` (the default-template / no-photo case) -- `queryCount` proves this by staying at zero
    /// in exactly that case.
    func checkExportGate(for photo: StrippedPhotoAsset?) async {
        guard let photo else {
            gateState = .notNeeded
            return
        }
        gateState = .checking
        queryCount += 1
        do {
            let response = try await client.exportConsentStatus(photoAssetID: photo.assetID.uuidString)
            gateState = response.allowed ? .allowed : .blocked(awaitingCount: response.awaitingSubjectIDs.count)
        } catch {
            gateState = .failed
        }
    }
}

/// A thin `UIViewControllerRepresentable` bridge to `UIActivityViewController`, matching
/// `InviteQRView.swift`'s own identical `SystemActivityView` precedent -- declared again here
/// under its own name rather than shared, since that type is `private` to its own file.
private struct CertificateShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
