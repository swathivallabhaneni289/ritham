import SwiftUI
import RithamCore

/// §4.6's required-blocking message. Replaces a personalized suggestion within *one domain* --
/// it must never present as an app-level block. §5's third governing principle keeps manual
/// logging and generic information available throughout a required-blocking gate, and the copy
/// itself tells the user they can still track manually, so this view carries no full-screen
/// cover, no modal presentation, and no dead end: it is a plain, off-white card meant to be
/// embedded in place of the blocked domain's content, with the rest of the hosting screen
/// (the other domain, navigation, everything else) left fully usable around it.
///
/// `ScreeningCopy.requiredBlockingMessage` carries `**bold**` markdown markers on its opening
/// sentence, same as `ClearanceInterstitialView`'s two copy blocks -- `Text(.init(...))` is used
/// here for the identical reason: this is one of the few screening copy blocks that actually
/// contains `*` markers, so scoping the markdown-parsing initializer to just these blocks keeps
/// a stray `*` anywhere else in the app from ever being misparsed as emphasis.
struct RequiredBlockingMessageView: View {
    var body: some View {
        Text(.init(ScreeningCopy.requiredBlockingMessage))
            .font(RithamType.body)
            .foregroundStyle(RithamColor.ink)
            .fixedSize(horizontal: false, vertical: true)
            .padding(RithamSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RithamColor.paper)
            .clipShape(RoundedRectangle(cornerRadius: RithamSpacing.sm))
    }
}
