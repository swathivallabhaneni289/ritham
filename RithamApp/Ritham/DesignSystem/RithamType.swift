import SwiftUI

/// The four-role type scale (01-UI-SPEC.md, Typography). Exactly four roles exist --
/// `display`, `heading`, `body`, `label` -- and nothing in this phase renders below the
/// `label` role (16pt @ default Large), which explicitly rules out `.footnote`, `.caption`, and
/// `.caption2` for every element, including HEALTH-05's standing footer disclaimer and the
/// compact disclaimer tag. Where copy needs to read as fine print, use `fineprint()` (reduced
/// opacity on the `label` role) -- never a smaller point size. This is a direct requirement of
/// the cross-generational mandate: refusing an age-segmented mode also means refusing a
/// small-type track that only younger users are assumed to read comfortably.
///
/// Numerals: SF Pro's default (non-rounded) numeral style only -- no rounded typeface anywhere
/// in the app (locked from sketch 002 round-2 research; rounded numerals read gamer/toy-coded).
/// Any ticking or counting value uses `numerals()` (`.monospacedDigit()`) to prevent layout
/// jitter, never a rounded typeface.
enum RithamType {
    /// `.title`, Semibold, 28pt @ default Large.
    static var display: Font {
        .title.weight(.semibold)
    }

    /// `.title2`, Semibold, 22pt @ default Large.
    static var heading: Font {
        .title2.weight(.semibold)
    }

    /// `.body`, Regular, 17pt @ default Large.
    static var body: Font {
        .body
    }

    /// `.callout`, Regular, 16pt @ default Large -- the floor. No role below this exists.
    static var label: Font {
        .callout
    }

    /// The sanctioned way to make `label`-role copy read as "fine print": the same 16pt floor
    /// size, reduced opacity only. Never pair fine-print copy with a smaller font.
    static func fineprint() -> some ViewModifier {
        FineprintModifier()
    }

    /// `.monospacedDigit()` for any ticking or counting value (e.g. a future session timer), so
    /// digits don't jitter the layout as they change.
    static func numerals() -> some ViewModifier {
        NumeralsModifier()
    }
}

private struct FineprintModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(RithamType.label)
            .opacity(0.6)
    }
}

private struct NumeralsModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.monospacedDigit()
    }
}
