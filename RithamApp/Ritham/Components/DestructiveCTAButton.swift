import SwiftUI

/// The first activation of `RithamColor.destructive` -- Phase 1 reserved this token with no
/// consumer at all ("Phase 1 has no destructive action"); this phase (plan 04.1-11) is that later
/// phase. Its use is limited to the two confirmations `04.1-UI-SPEC.md`'s Color section names:
/// the Leave Group confirmation (`LeaveGroupSheet`) and the Remove Member confirmation
/// (`GroupDetailView`). No other screen in this app should reach for this button or this token --
/// a future addition needs its own `04.1-UI-SPEC.md`-equivalent sign-off, not an assumption that
/// "destructive-looking" is reason enough.
///
/// Copies `PrimaryCTAButton`'s structural shape exactly -- the same minimum tap target,
/// accessibility label, and rounded-rectangle clip -- substituting `RithamColor.destructive` for
/// `RithamColor.hot` as the fill. `RithamColor.label(on:)` is not used for this fill: that
/// function's own doc comment states it exists to keep `hot`/`volt` fills off `paper` labels
/// specifically (both measured below the 3:1 non-text-contrast floor); `destructive` (#FF3B30, an
/// unmodified iOS system red) was never part of that measured pair, and iOS system red carries
/// its own well-established white-label convention (matching, for instance, the platform's own
/// `role: .destructive` button styling), so this button uses `RithamColor.paper` as its label
/// directly rather than routing through a helper scoped to a different pair of fills.
struct DestructiveCTAButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(RithamType.body.weight(.semibold))
                .foregroundStyle(RithamColor.paper)
                .frame(minWidth: RithamSpacing.minimumTapTarget, minHeight: RithamSpacing.minimumTapTarget)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, RithamSpacing.md)
                .background(RithamColor.destructive)
                .clipShape(RoundedRectangle(cornerRadius: RithamSpacing.sm))
        }
        .accessibilityLabel(title)
    }
}
