import SwiftUI
import RithamCore

/// Maps `RithamCore.ActivityType` to an SF Symbol, rendered through the existing
/// `SectionIconBadge` rather than a new badge shell -- the **first** per-activity-type icon
/// mapping in this codebase. `04.1-RESEARCH.md` claimed one already existed; a grep across
/// `RithamApp`/`RithamCore` confirmed only a binary cardio-vs-strength glyph (`figure.run` vs
/// `dumbbell.fill` in `HomeHubView`), never a per-activity-type table. `04.1-UI-SPEC.md`'s own New
/// Components table states this correction directly and supplies the locked mapping this file
/// transcribes.
///
/// The PRD's own activity-type list uses "ride" as display language for the existing `.cycle`
/// case, per `04.1-UI-SPEC.md`'s own note -- Goal-Events reuse `RithamCore.ActivityType` directly,
/// never a second activity vocabulary.
struct ActivityTypeIcon: View {
    let activityType: ActivityType
    var diameter: CGFloat = 32

    var body: some View {
        SectionIconBadge(systemName: Self.symbolName(for: activityType), diameter: diameter)
    }

    /// `nonisolated static`, not an instance/computed property on this `@MainActor`-inferred
    /// `View` -- SwiftUI's `View` protocol is itself `@MainActor`, so isolation is inferred onto
    /// every member of a conforming type by default and traps at runtime when called from Swift
    /// Testing's off-main-actor test functions (`MomentumProgressBlocks.blockStates`'s own
    /// documented precedent for this exact trap, 03-06-SUMMARY.md). Declaring this lookup as a
    /// free-standing `nonisolated` function lets `GoalEventsUITests`' distinctness test call it
    /// directly, with no view instance and no main-actor hop required.
    ///
    /// Any raw value outside the six known cases falls back to `figure.run`, mirroring
    /// `ActivityType.displayName`'s own capitalized-raw-value fallback pattern -- an unrecognized
    /// future activity renders the extensibility path's own default symbol rather than nothing.
    nonisolated static func symbolName(for activityType: ActivityType) -> String {
        switch activityType {
        case .run: return "figure.run"
        case .walk: return "figure.walk"
        case .cycle: return "figure.outdoor.cycle"
        case .hike: return "figure.hiking"
        case .swim: return "figure.pool.swim"
        case .elliptical: return "figure.elliptical"
        default: return "figure.run"
        }
    }
}
