import SwiftUI

/// D-07/D-08's twelve-month re-screen reminder. Non-blocking by construction: it never covers
/// content, never gates navigation, and is dismissible for the current session; the wording
/// invites a re-screen without ever implying a restriction has lapsed or been switched off,
/// because per D-08 the existing restriction keeps applying for as long as this banner is
/// showing. No caller may use `isReScreenDue`'s `true` value to gate access -- core's own
/// `ConditionTagValidity.isReScreenDue` doc comment records the identical constraint ("says
/// prompt, never block"); this view is simply the one place that signal reaches the user.
struct ReScreenBanner: View {
    /// Computed by the caller from `HealthDataStore.isReScreenDue(now:)`. This view holds no
    /// `HealthDataStore` reference of its own -- it is handed the already-computed signal so it
    /// stays a plain, previewable view with no persistence dependency.
    let isReScreenDue: Bool
    let onStartReScreen: () -> Void

    @State private var isDismissedThisSession = false

    var body: some View {
        if isReScreenDue, !isDismissedThisSession {
            HStack(alignment: .top, spacing: RithamSpacing.sm) {
                VStack(alignment: .leading, spacing: RithamSpacing.xs) {
                    Text("Time for a quick re-screen")
                        .font(RithamType.body.weight(.semibold))
                        .foregroundStyle(RithamColor.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("It's been a while since you answered these questions. Your current settings still apply -- re-screening just keeps them up to date.")
                        .font(RithamType.label)
                        .foregroundStyle(RithamColor.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    Button(action: onStartReScreen) {
                        Text("Start re-screen")
                            .font(RithamType.body.weight(.semibold))
                            .foregroundStyle(RithamColor.hot)
                            .frame(minHeight: RithamSpacing.minimumTapTarget, alignment: .leading)
                    }
                }

                Spacer(minLength: RithamSpacing.sm)

                Button {
                    isDismissedThisSession = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(RithamColor.ink.opacity(0.6))
                        .frame(minWidth: RithamSpacing.minimumTapTarget, minHeight: RithamSpacing.minimumTapTarget)
                }
                .accessibilityLabel("Dismiss for now")
            }
            .padding(RithamSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RithamColor.paper)
            .clipShape(RoundedRectangle(cornerRadius: RithamSpacing.sm))
        }
    }
}
