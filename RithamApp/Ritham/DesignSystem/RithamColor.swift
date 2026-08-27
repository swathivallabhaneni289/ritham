import SwiftUI

/// The four locked palette tokens (01-UI-SPEC.md, Color) plus a fifth reserved token, and the
/// contrast-safe label rule that makes it impossible to pick the intuitive-but-wrong label color
/// for a filled surface.
///
/// This is the ONLY file in the app where a six-digit hex literal may appear -- every other view
/// reaches color exclusively through `RithamColor`'s static tokens.
///
/// Measured WCAG 2.1 relative-luminance contrast ratios (01-UI-SPEC.md, Contrast Verification),
/// recorded here so a future reader does not re-litigate the rule below from appearance alone:
///   - paper on ink   17.2:1  PASS
///   - volt  on ink   14.8:1  PASS
///   - hot   on ink    6.2:1  PASS
///   - ink   on hot    6.2:1  PASS
///   - ink   on volt   14.8:1 PASS
///   - paper on hot     2.8:1 FAIL
///   - paper on volt    1.2:1 FAIL
enum RithamColor {
    /// Charcoal -- the dominant (60%) base field for every screen in this phase.
    static let ink = value(0x0E100D)

    /// Coral -- primary accent/signal. Reserved for the primary CTA fill, an active
    /// Yes/No or checklist chip, and the compact disclaimer tag's leading accent mark.
    static let hot = value(0xFF5C39)

    /// Acid lime -- secondary accent/ornament. Reserved for the static ring-and-dot brand
    /// ornament and the gate-pass affirmation micro-accent -- never a progress indicator.
    static let volt = value(0xC6F24E)

    /// Off-white -- secondary surface and the primary text color for content on charcoal.
    static let paper = value(0xF5F3EC)

    /// iOS system red. Reserved for a later phase -- Phase 1 has no destructive action (editing
    /// an answer is a normal edit, not a delete/irreversible action). Recorded now so a later
    /// phase does not improvise a different red.
    static let destructive = value(0xFF3B30)

    /// Returns the contrast-safe label color for content drawn on top of `fill`.
    ///
    /// Off-white (`paper`) on a coral or lime fill fails AA badly (2.8:1 and 1.2:1 above) even
    /// though it is the intuitive default -- so this function makes that choice unreachable
    /// through the sanctioned API: a coral or lime fill always gets charcoal labels, and every
    /// other fill (charcoal itself) gets paper labels.
    static func label(on fill: Color) -> Color {
        if fill == hot || fill == volt {
            return ink
        }
        return paper
    }

    /// Constructs a `Color` from a six-digit RGB hex value. Private so no other file needs (or
    /// is able) to introduce its own hex-parsing helper.
    private static func value(_ hex: UInt32) -> Color {
        Color(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
