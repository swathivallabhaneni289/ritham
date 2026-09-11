import SwiftUI
import RithamCore

/// GROUPEVENTS-05: the reveal screen shown immediately after `CompletionLoggingView` writes the
/// completion's certificate (`CertificateRecord`) -- see that file's own
/// `generateCertificateAndReveal()` for the single, no-separate-send-step generation path. On the
/// bounded-header surface (`04.1-UI-SPEC.md`'s Layout & Screen Contract assigns this treatment to
/// screens that introduce an artifact rather than collecting or confirming health/consent data).
/// Shows the card and offers the export flow.
struct CertificateRevealView: View, OnboardingStepPresenting {
    static let step: OnboardingStep = .certificate

    static func makeView(flow: OnboardingFlow) -> AnyView {
        AnyView(CertificateRevealView(flow: flow))
    }

    let flow: OnboardingFlow

    @Environment(\.modelContext) private var modelContext
    @State private var content: CertificateContent?
    @State private var isPresentingExport = false

    var body: some View {
        RithamScreen(surface: DecorativeSurface.boundedHeaderOnly, headline: content?.eventDisplayName) {
            if let content {
                CertificateCardView(content: content)

                PrimaryCTAButton(title: SocialCopy.Certificate.exportCTA) {
                    isPresentingExport = true
                }
            } else {
                ProgressView()
            }

            SecondaryCTAButton(title: "Back") {
                flow.goBack()
            }
        }
        .task { await load() }
        .sheet(isPresented: $isPresentingExport) {
            if let content {
                CertificateExportView(content: content)
            }
        }
    }

    /// Reads the most recently accumulated certificate -- the one `CompletionLoggingView` just
    /// wrote, since this screen is reached only from that write's own `flow.open(.certificate)`
    /// call, with no other entry point.
    private func load() async {
        let store = HealthDataStore(context: modelContext)
        guard let latest = try? store.loadCertificates().last else { return }
        content = await latest.content()
    }
}
