import SwiftUI

/// A circular person avatar with an initials fallback.
///
/// **Circle vs. `SectionIconBadge`'s rounded square, and why Rule 5 does not apply here:**
/// `04.1-UI-SPEC.md`'s Friends section sanctions the circle specifically for person identity as a
/// standard, universal avatar convention -- distinct from `SectionIconBadge`'s rounded square,
/// which marks an action entry point or a group (never a specific person). This is not a
/// data-bearing ring, arc, or progress form of any kind: it carries no numeric value, no
/// completion fraction, and nothing that could rank or compare two people, so this phase's Rule 5
/// ("no data-bearing ring, arc, or radial progress indicator anywhere in this phase's UI") simply
/// does not describe it. A future editor reading this file in isolation might otherwise flag a
/// circle as an inconsistency with that rule -- it is not one.
struct AvatarView: View {
    let name: String
    var diameter: CGFloat = 44

    var body: some View {
        Circle()
            .fill(RithamColor.paper.opacity(0.12))
            .frame(width: diameter, height: diameter)
            .overlay(
                Text(initials)
                    .font(.system(size: diameter * 0.4, weight: .semibold))
                    .foregroundStyle(RithamColor.paper.opacity(0.85))
            )
            .accessibilityLabel(name)
    }

    /// Up to two initials from the first two whitespace-separated components of `name`, or a
    /// single "?" when `name` is empty -- never a raw index or a blank circle, so a malformed
    /// display name still renders something legible rather than nothing.
    private var initials: String {
        let components = name.split(separator: " ").prefix(2)
        let letters = components.compactMap { $0.first }.map(String.init)
        let joined = letters.joined().uppercased()
        return joined.isEmpty ? "?" : joined
    }
}
