import SwiftUI
import RithamCore

/// GROUPEVENTS-05: a plain stack of every certificate this device holds, in the person's own order
/// of accumulation (oldest first, matching `HealthDataStore.loadCertificates()`'s own ordering) at
/// reduced scale. This is a personal keepsake trail, not a leaderboard or a progress tracker: it is
/// never ranked, never ordered against anyone else's, and shows no count and no comparison of any
/// kind anywhere on this screen -- `04.1-UI-SPEC.md`'s Non-Comparative Structural Visual Rules
/// apply here exactly as they do to the group feed.
struct CertificateArchiveView: View, OnboardingStepPresenting {
    static let step: OnboardingStep = .certificateArchive

    static func makeView(flow: OnboardingFlow) -> AnyView {
        AnyView(CertificateArchiveView(flow: flow))
    }

    let flow: OnboardingFlow

    /// Shown at roughly 60% of the card's own on-screen size -- a thumbnail-scale echo of the same
    /// card `CertificateRevealView` shows at full size, never a redesigned "compact" layout.
    private static let archiveScale: CGFloat = 0.6

    @Environment(\.modelContext) private var modelContext
    @State private var contents: [CertificateContent] = []

    var body: some View {
        RithamScreen(surface: DecorativeSurface.flat, headline: "Your certificates") {
            ForEach(Array(contents.enumerated()), id: \.offset) { _, content in
                CertificateCardView(content: content)
                    .frame(width: CertificateCardView.size.width, height: CertificateCardView.size.height)
                    .scaleEffect(Self.archiveScale)
                    .frame(
                        width: CertificateCardView.size.width * Self.archiveScale,
                        height: CertificateCardView.size.height * Self.archiveScale
                    )
            }

            SecondaryCTAButton(title: "Back") {
                flow.goBack()
            }
        }
        .task { await load() }
    }

    private func load() async {
        let store = HealthDataStore(context: modelContext)
        guard let records = try? store.loadCertificates() else { return }
        var loaded: [CertificateContent] = []
        for record in records {
            loaded.append(await record.content())
        }
        contents = loaded
    }
}
