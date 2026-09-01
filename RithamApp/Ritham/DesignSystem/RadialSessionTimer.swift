import SwiftUI

/// A genuine, data-bearing progress ring for a real-time countdown/count-up -- explicitly NOT
/// the static ring-and-dot brand ornament (`RingAndDot.swift`). 01-UI-SPEC.md's own binding
/// Ring-and-Dot decision anticipates this: "If a future phase needs a genuine progress ring for
/// some other purpose, that is a new design decision requiring its own vetting -- this ornament
/// does not become one by extension." This is that new decision, made distinct on every axis the
/// lock cares about:
///   - Color: `RithamColor.hot` (coral), never `RithamColor.volt` -- volt is reserved ("never a
///     progress indicator", `RithamColor.swift`) for the static ornament alone. Coral already
///     fills the plain linear `ProgressBarStrip` this replaces for walk timing, so the meaning
///     of "coral fill = live progress" stays consistent app-wide.
///   - Behavior: fills/sweeps as a real `fraction` changes; carries that fraction as a parameter,
///     which the static ornament's API deliberately has none of.
///   - Placement: lives in a screen's scrollable content area, never the bounded decorative
///     header `ScreenHeader` draws.
/// Any screen using this must not also show `RingAndDot` in the same viewport --
/// `DecorativeSurface.calibrationSession` (not `.calibration`) enforces that for the one screen
/// that needs both concepts nearby, by turning the header ring off.
///
/// The numeric time readout is a separate, fully Dynamic-Type-scaling `Text` below this ring, not
/// inside it: at accessibility text sizes (AX1-AX5) `RithamType.display` grows well past what a
/// fixed-diameter ring could contain without either overflowing or shrinking the digits below
/// `RithamType`'s own 16pt label-role floor. This view is purely the decorative echo of that
/// number, so it hides itself from the accessibility tree -- the caller is expected to attach a
/// single combined `accessibilityLabel`/`accessibilityValue` to the ring-plus-digits group instead
/// of letting VoiceOver read the ring and the text as two separate, redundant elements.
struct RadialSessionTimer: View {
    /// 0...1 in the caller's own terms; values outside that range are clamped for display so a
    /// caller does not need to clamp before passing progress in.
    var fraction: Double
    var isComplete: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var scaledDiameter: CGFloat = 140

    /// Capped so the ring stays a fixed decorative-scale graphic even at the largest accessibility
    /// text sizes -- unbounded `@ScaledMetric` growth here would let the ring itself consume most
    /// of the screen at AX5, which is exactly the failure mode putting the digits below it (not
    /// inside it) is meant to avoid.
    private var diameter: CGFloat { min(scaledDiameter, 220) }
    private var strokeWidth: CGFloat { max(diameter * 0.06, 6) }
    private var clampedFraction: Double { min(max(fraction, 0), 1) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(RithamColor.paper.opacity(0.2), lineWidth: strokeWidth)

            Circle()
                .trim(from: 0, to: clampedFraction)
                .stroke(RithamColor.hot, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : .linear(duration: 0.9), value: clampedFraction)

            if isComplete {
                Image(systemName: "checkmark")
                    .font(.system(size: diameter * 0.26, weight: .semibold))
                    .foregroundStyle(RithamColor.hot)
            }
        }
        .frame(width: diameter, height: diameter)
        .accessibilityHidden(true)
    }
}
