import SwiftUI
import RithamCore

// MOMENTUM-01's weekly progress display: a block-grid strip, never a ring or arc.
//
// Binding decision (03-UI-SPEC.md Component 1, transcribed here rather than re-derived
// per-screen): a block grid, never a ring/arc, for three reasons.
//   1. It is the form the codebase's own prior research already named for exactly this feature
//      (01-UI-SPEC.md's own binding Ring-and-Dot decision: "data forms -- bar strips, block
//      grids -- are used for Momentum instead, per that research") -- not a new exception
//      requiring its own vetting, the way `RadialSessionTimer` had to justify itself against
//      the same rule for a session timer's different use case.
//   2. `HomeHubView` currently renders with `DecorativeSurface.boundedHeaderOnly`
//      (`ringAndDot: true`). A ring anywhere in this feature's viewport would recreate the "two
//      circular motifs in one viewport" collision `.calibrationSession` exists specifically to
//      prevent. This component is placed in the scrollable content area, never a decorative
//      header region, so the adjacency rule `RingAndDot.swift`'s own header comment states
//      ("must never sit adjacent to Momentum data") is satisfied by placement alone -- no
//      enforcement mechanism is added here beyond simply never rendering inside a header.
//   3. The weekly target is a small discrete count (2-5), which a segmented block grid
//      represents more legibly than a fraction of a continuous arc -- each block *is* one
//      qualifying session, not a slice of one.
//
// Never uses `RithamColor.volt` -- coral (`RithamColor.hot`) is this app's "genuine data-bearing
// progress" color everywhere, matching `RadialSessionTimer`'s own precedent; volt stays reserved
// for the static ornament alone.
struct MomentumProgressBlocks: View {
    let filled: Int
    let target: Int

    var body: some View {
        VStack(alignment: .leading, spacing: RithamSpacing.sm) {
            Text(MomentumCopy.Progress.weekly(count: filled, target: target))
                .font(RithamType.body)
                .modifier(RithamType.numerals())
                .foregroundStyle(RithamColor.paper)

            HStack(spacing: RithamSpacing.sm) {
                ForEach(Array(Self.blockStates(filled: filled, target: target).enumerated()), id: \.offset) { _, isFilled in
                    RoundedRectangle(cornerRadius: RithamSpacing.sm)
                        .fill(isFilled ? RithamColor.hot : RithamColor.paper.opacity(0.2))
                        .frame(minHeight: RithamSpacing.minimumTapTarget)
                }
            }
        }
        // Combines the count label and the block strip into one VoiceOver announcement, matching
        // `RadialSessionTimer`'s own precedent for combining a decorative visual with its numeric
        // readout rather than announcing two separate elements.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(MomentumCopy.Progress.weeklyAccessibility(count: filled, target: target))
    }
}

extension MomentumProgressBlocks {
    /// Returns exactly `target` booleans (`true` = filled, left to right), or an empty array when
    /// `target <= 0`. A pure, view-independent function so the filled/unfilled block counts for
    /// representative `(filled, target)` pairs -- including `filled == target` and `filled == 0`
    /// -- are directly testable without rendering the view.
    ///
    /// `nonisolated`: SwiftUI's `View` protocol is itself `@MainActor`, which infers
    /// `@MainActor` isolation onto every member of a conforming type by default -- including this
    /// static function, even though it touches no UI state. Swift Testing runs test functions off
    /// the main actor, so calling an inferred-`@MainActor` static function directly (not via
    /// `await`) traps at runtime with an actor-isolation assertion failure rather than failing to
    /// compile (caught by this file's own test suite crashing on first run, before this fix).
    /// Marking this `nonisolated` is the same fix the codebase already applies elsewhere for a
    /// pure helper that must be callable from a nonisolated context (see e.g.
    /// `HealthDataStore.swift`'s and `WorkoutFrequencyView.swift`'s own `nonisolated` helpers).
    nonisolated static func blockStates(filled: Int, target: Int) -> [Bool] {
        guard target > 0 else { return [] }
        return (0..<target).map { $0 < filled }
    }
}
