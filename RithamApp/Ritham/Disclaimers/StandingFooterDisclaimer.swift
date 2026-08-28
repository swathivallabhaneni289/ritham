import SwiftUI
import RithamCore

/// §4.7's standing footer disclaimer -- placed at the foot of any screen showing adjusted
/// content. Renders at the `label` role, the same 16pt floor every other element in this
/// directory holds to; 01-UI-SPEC.md rules out the smaller text styles for this element by
/// name, so this view never shrinks it and never wraps it in `fineprint()` either -- the footer
/// itself is the standing disclaimer, not fine print layered on top of something else.
struct StandingFooterDisclaimer: View {
    var body: some View {
        Text(ScreeningCopy.standingFooterDisclaimer)
            .font(RithamType.label)
            .foregroundStyle(RithamColor.paper)
            .fixedSize(horizontal: false, vertical: true)
    }
}
