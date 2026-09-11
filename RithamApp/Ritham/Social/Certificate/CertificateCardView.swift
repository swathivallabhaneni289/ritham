import SwiftUI
import RithamCore

/// The rendered certificate card, used both on screen (`CertificateRevealView`/
/// `CertificateArchiveView`) and as `CertificateComposer`'s own render source -- one view, so the
/// exported image is always pixel-for-pixel what a person already saw on screen, never a second,
/// divergent "export-only" layout that could drift out of sync with it.
///
/// A deliberate local inversion of this app's usual `ink`-dominant chrome: a `paper`-colored
/// surface, because this artifact is designed to be exported and viewed outside Ritham's own
/// charcoal-dominant screens, and needs to read correctly as a standalone image on someone else's
/// phone, not just inside this app (`04.1-UI-SPEC.md`'s Digital Certificate section).
///
/// Content, in the UI-SPEC's own order: the Ritham wordmark, the activity badge (icon + event
/// name + activity type), the participant's own name at the `body` role (the card's focal point),
/// the completion date at the `label` role, the generalized place name when present (also
/// `label`), and the own time at the `label` role with `numerals()` only when present. No field
/// renders below the `label` floor, including the wordmark credit line -- this file contains no
/// `.caption`/`.footnote` use anywhere.
///
/// The frame reuses `BandMotif` (the same three-stripe hot/volt/paper diagonal this app's screen
/// headers already draw) as a static corner accent -- a brand ornament, not a data-bearing ring,
/// so this phase's Ring Collision rule does not apply to it.
struct CertificateCardView: View {
    let content: CertificateContent

    /// The card's own fixed intrinsic size -- both this view's on-screen rendering and
    /// `CertificateComposer`'s `ImageRenderer` capture use exactly this size, so what a person
    /// sees on screen and what leaves the device as an image are the same pixels, only scaled.
    static let size = CGSize(width: 320, height: 460)

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RithamColor.paper

            cornerAccent

            VStack(alignment: .leading, spacing: RithamSpacing.md) {
                Text("Ritham")
                    .font(RithamType.label.weight(.semibold))
                    .foregroundStyle(RithamColor.ink.opacity(0.6))

                HStack(spacing: RithamSpacing.sm) {
                    activityBadge

                    VStack(alignment: .leading, spacing: RithamSpacing.xs) {
                        Text(content.eventDisplayName)
                            .font(RithamType.label)
                            .foregroundStyle(RithamColor.ink)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(content.activityType.displayName)
                            .font(RithamType.label)
                            .foregroundStyle(RithamColor.ink.opacity(0.6))
                    }
                }

                Spacer(minLength: RithamSpacing.md)

                Text(content.participantName)
                    .font(RithamType.body.weight(.semibold))
                    .foregroundStyle(RithamColor.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text(content.completionDate.formatted(date: .abbreviated, time: .omitted))
                    .font(RithamType.label)
                    .foregroundStyle(RithamColor.ink.opacity(0.6))

                if let placeName = content.placeName {
                    Text(placeName)
                        .font(RithamType.label)
                        .foregroundStyle(RithamColor.ink.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let ownTimeSeconds = content.ownTimeSeconds {
                    Text(Self.formattedTime(ownTimeSeconds))
                        .font(RithamType.label)
                        .modifier(RithamType.numerals())
                        .foregroundStyle(RithamColor.ink)
                }

                if let photo = content.photo {
                    AsyncImage(url: photo.sharedURL) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .scaledToFill()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: RithamSpacing.sm))
                    .clipped()
                }
            }
            .padding(RithamSpacing.md)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .clipShape(RoundedRectangle(cornerRadius: RithamSpacing.sm))
    }

    /// A small activity-type glyph, styled for this card's own light (`paper`) surface -- not
    /// `ActivityTypeIcon`/`SectionIconBadge`, which fill and tint for the app's usual dark `ink`
    /// screens (a `paper`-on-`paper` badge would render nearly invisible here). Reuses only
    /// `ActivityTypeIcon.symbolName(for:)`'s icon-name lookup, never its view body, so the glyph
    /// mapping stays the single source of truth this app already established while the contrast
    /// stays correct on this locally-inverted surface.
    private var activityBadge: some View {
        RoundedRectangle(cornerRadius: RithamSpacing.xs + 2)
            .fill(RithamColor.ink.opacity(0.08))
            .frame(width: 28, height: 28)
            .overlay(
                Image(systemName: ActivityTypeIcon.symbolName(for: content.activityType))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(RithamColor.ink.opacity(0.85))
            )
            .accessibilityHidden(true)
    }

    /// The static three-stripe brand band, reused verbatim as a corner ornament -- not a ring, and
    /// not data-bearing, so this phase's Ring Collision rule (`04.1-UI-SPEC.md`'s Non-Comparative
    /// Structural Visual Rules, Rule 5) does not apply to it.
    private var cornerAccent: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { band in
                BandMotif(band: band)
                    .fill(bandFill(for: band))
            }
        }
        .frame(width: 96, height: 96)
        .clipped()
    }

    private func bandFill(for band: Int) -> Color {
        switch band {
        case 0: return RithamColor.hot
        case 1: return RithamColor.volt
        default: return RithamColor.paper
        }
    }

    private static func formattedTime(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
