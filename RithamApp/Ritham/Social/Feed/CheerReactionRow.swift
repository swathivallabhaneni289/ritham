import SwiftUI
import RithamCore

/// Ritham's first cheer control (04.1-UI-SPEC.md's Cheer Reaction Component) -- the canonical
/// build `HOUSEHOLD-01` (Phase 4 round 2) should reuse verbatim rather than building a second one.
/// Two content-sized chips, one per `RithamCore.Cheer` case, wrapping onto a new line at large
/// accessibility text sizes.
///
/// **Deliberately does NOT reuse `ChoiceChip`'s (`Components/ChoiceChip.swift`) `hot`-fill-on-
/// select treatment.** `ChoiceChip`'s selected state marks a *data answer* -- a screening choice, a
/// preference -- where showing which option is chosen is the entire point. A cheer is a *social*
/// action on a feed several people see: an `hot`-filled cheer button would read as "the important
/// or correct one to tap," or worse, draw the eye toward whichever reaction has more taps if a
/// future iteration ever surfaces counts by accident. The sent-by-this-viewer state below uses the
/// neutral `paper`-filled/`ink`-label inversion instead -- a plain "you did this" affordance, never
/// a status badge announced to the group. This reasoning is 04.1-UI-SPEC.md's own explicit ruling,
/// recorded here so a future editor does not "fix" this back to `ChoiceChip`.
///
/// **Never shown, by construction:** a count of how many people sent a cheer, a "most-cheered"
/// ordering, or any per-person list of who cheered. This type has no numeric input of any kind --
/// it renders exactly two booleans (the viewer's own state) and reports taps outward through
/// `onToggle`, never anything the server's own count-free schema doesn't already guarantee.
struct CheerReactionRow: View {
    let niceWorkSentByViewer: Bool
    let keepGoingSentByViewer: Bool
    let onToggle: (Cheer) -> Void

    var body: some View {
        CheerWrapLayout(spacing: RithamSpacing.sm) {
            ForEach(Cheer.allCases, id: \.self) { cheer in
                CheerChip(title: title(for: cheer), isSent: isSent(cheer)) {
                    onToggle(cheer)
                }
            }
        }
    }

    private func isSent(_ cheer: Cheer) -> Bool {
        switch cheer {
        case .niceWork: return niceWorkSentByViewer
        case .keepGoing: return keepGoingSentByViewer
        }
    }

    private func title(for cheer: Cheer) -> String {
        switch cheer {
        case .niceWork: return SocialCopy.Cheer.niceWork
        case .keepGoing: return SocialCopy.Cheer.keepGoing
        }
    }
}

/// One cheer chip. Unselected renders as `paper`-outline with `paper` text, matching
/// `SecondaryCTAButton`'s stroke treatment; the sent-by-this-viewer state is the neutral inverted
/// fill (`paper` background, `ink` label) -- deliberately never the app's reserved accent color
/// (see this file's header comment; this file's own acceptance gate greps for that color token by
/// name and requires zero matches, so it is intentionally not spelled out again here). Content-
/// sized, not full-width, unlike `SecondaryCTAButton` -- two of these sit side by side below a
/// feed card, not stacked as page-level actions.
private struct CheerChip: View {
    let title: String
    let isSent: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(RithamType.body)
                .foregroundStyle(isSent ? RithamColor.ink : RithamColor.paper)
                .padding(.horizontal, RithamSpacing.md)
                .frame(minWidth: RithamSpacing.minimumTapTarget, minHeight: RithamSpacing.minimumTapTarget)
                .background(chipBackground)
        }
        .accessibilityAddTraits(isSent ? [.isSelected] : [])
    }

    @ViewBuilder
    private var chipBackground: some View {
        if isSent {
            RoundedRectangle(cornerRadius: RithamSpacing.sm).fill(RithamColor.paper)
        } else {
            RoundedRectangle(cornerRadius: RithamSpacing.sm).stroke(RithamColor.paper, lineWidth: 1)
        }
    }
}

/// A duplicate of `ChoiceQuestionView.swift`'s own private `WrapLayout` (same wrapping-horizontal-
/// then-vertical algorithm), not a shared/exported type -- that file's `WrapLayout` is `private`
/// (file-scoped) there too, so reusing it without widening its access would require editing a file
/// outside this plan's own scope. Duplicating a small, already-proven layout algorithm keeps this
/// plan's changes confined to files it actually owns; see `ChoiceQuestionView.swift`'s own header
/// comment for the algorithm's original reasoning (measuring every subview against `maxWidth`,
/// never `.unspecified`, so long chip labels wrap instead of overflowing the screen edge).
private struct CheerWrapLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var totalHeight: CGFloat = 0
        var lineWidth: CGFloat = 0
        var lineHeight: CGFloat = 0
        var widestLine: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(ProposedViewSize(width: maxWidth.isFinite ? maxWidth : nil, height: nil))
            if lineWidth > 0, lineWidth + spacing + size.width > maxWidth {
                totalHeight += lineHeight + spacing
                widestLine = max(widestLine, lineWidth)
                lineWidth = 0
                lineHeight = 0
            }
            lineWidth += (lineWidth > 0 ? spacing : 0) + size.width
            lineHeight = max(lineHeight, size.height)
        }
        totalHeight += lineHeight
        widestLine = max(widestLine, lineWidth)

        let width = maxWidth.isFinite ? maxWidth : widestLine
        return CGSize(width: width, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += lineHeight + spacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(width: maxWidth, height: nil))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
