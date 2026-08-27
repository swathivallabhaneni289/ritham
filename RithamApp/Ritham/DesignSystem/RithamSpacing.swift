import CoreGraphics

/// The seven-step spacing scale (01-UI-SPEC.md, Spacing Scale). Every value is a multiple of 4.
enum RithamSpacing {
    /// 4pt -- icon gaps, inline padding.
    static let xs: CGFloat = 4

    /// 8pt -- compact element spacing (e.g. a checklist row's label and its checkbox).
    static let sm: CGFloat = 8

    /// 16pt -- default element spacing, standard screen margin.
    static let md: CGFloat = 16

    /// 24pt -- section padding (e.g. between the gate-question framing line and Q1).
    static let lg: CGFloat = 24

    /// 32pt -- layout gaps (e.g. between the disclaimer block and the first question).
    static let xl: CGFloat = 32

    /// 48pt -- major section breaks (e.g. above/below a clearance interstitial's CTA).
    static let xxl: CGFloat = 48

    /// 64pt -- page-level spacing (e.g. top inset on the welcome/hero screen).
    static let xxxl: CGFloat = 64

    /// Apple HIG's minimum interactive control size, non-negotiable given the cross-generational
    /// requirement that teens and grandparents use identical controls. Applies to every
    /// icon-only control: the compact disclaimer tag's expand affordance, back/close buttons,
    /// Yes/No toggle chips.
    static let minimumTapTarget: CGFloat = 44
}
