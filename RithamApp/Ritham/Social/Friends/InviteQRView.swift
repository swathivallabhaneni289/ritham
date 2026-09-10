import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

/// Renders a freshly created invite token as a scannable QR code and offers the system share
/// sheet, so one `InviteToken` serves both of `AddFriendView`'s invite-based rows: "Invite link or
/// QR code" presents this screen showing the code for someone right next to you to scan, and
/// "Share directly" presents this same screen with the system share sheet already on top --
/// `autoPresentsShareSheet` is the only thing that differs between the two call sites. Both rows
/// create the identical kind of invite through `FriendsModel.createInvite()`; there is no second,
/// separate "direct share" mechanism to build, since `RithamService` only exposes one
/// invite-token primitive (`docs/group-events.md` §1's third connection path is a text/AirDrop
/// transmission *channel* for that same token, not a second server-side mechanism).
///
/// The expiry is shown plainly, never hidden: a link that dies is this feature's own point
/// (single-use/window-expiring semantics, T-04.1-53), not a limitation to soften.
struct InviteQRView: View {
    let token: InviteToken
    var autoPresentsShareSheet: Bool = false

    @Environment(\.dismiss) private var dismiss
    @State private var isPresentingShareSheet = false

    private static let context = CIContext()
    private static let expiryFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        RithamScreen(surface: DecorativeSurface.boundedHeaderOnly, headline: "Invite a friend") {
            if let qrImage = Self.qrImage(for: token.token) {
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 220, height: 220)
                    .accessibilityLabel("A scannable code for your invite")
            }

            Text("This invite expires \(Self.expiryFormatter.string(from: token.expiresAt)) or as soon as it's used once, whichever comes first.")
                .font(RithamType.body)
                .foregroundStyle(RithamColor.paper)
                .fixedSize(horizontal: false, vertical: true)

            SecondaryCTAButton(title: "Share invite") {
                isPresentingShareSheet = true
            }

            SecondaryCTAButton(title: "Done") {
                dismiss()
            }
        }
        .onAppear {
            if autoPresentsShareSheet {
                isPresentingShareSheet = true
            }
        }
        .sheet(isPresented: $isPresentingShareSheet) {
            SystemActivityView(activityItems: [Self.shareText(for: token.token)])
        }
    }

    private static func shareText(for token: String) -> String {
        "Join me on Ritham: \(token)"
    }

    private static func qrImage(for token: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(token.utf8)
        filter.correctionLevel = "M"
        guard let outputImage = filter.outputImage else { return nil }
        // The raw CIImage renders at roughly 23x23 points -- scaling it up before rasterizing
        // keeps each module a crisp block instead of an interpolated blur.
        let scaled = outputImage.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

/// A thin `UIViewControllerRepresentable` bridge to `UIActivityViewController` -- SwiftUI's own
/// `ShareLink` cannot be presented programmatically (it is a tap-only control), and
/// `autoPresentsShareSheet` above needs the system share sheet to appear without a user tap on
/// this screen itself, since the tap that got the user here already happened on `AddFriendView`'s
/// "Share directly" row.
private struct SystemActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
