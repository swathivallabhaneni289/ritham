import SwiftUI

/// MONETIZE-01's in-app statement of the "always free" monetization boundary. Presented as a
/// sheet from `SettingsView`, the same secondary-CTA-plus-sheet pairing that screen already uses
/// for `DietPlanView`.
///
/// Renders `AlwaysFreeCapability.all` verbatim -- the rendered list and any future test read the
/// exact same declared source, so this screen and its own tests can never silently drift apart.
/// Nothing on this screen offers a purchase, a subscription, an upgrade, or a trial: every entry
/// is descriptive text only, with no associated action of any kind.
struct AlwaysFreeListView: View {
    var body: some View {
        RithamScreen(surface: DecorativeSurface.flat, headline: "Always free") {
            VStack(alignment: .leading, spacing: RithamSpacing.lg) {
                Text(AlwaysFreeCapability.commitmentStatement)
                    .font(RithamType.body)
                    .foregroundStyle(RithamColor.paper)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: RithamSpacing.md) {
                    ForEach(AlwaysFreeCapability.all) { capability in
                        capabilityRow(capability)
                    }
                }

                Text(AlwaysFreeCapability.forgivenessStatement)
                    .font(RithamType.body)
                    .foregroundStyle(RithamColor.paper)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func capabilityRow(_ capability: AlwaysFreeCapability) -> some View {
        VStack(alignment: .leading, spacing: RithamSpacing.xs) {
            Text(capability.title)
                .font(RithamType.body.weight(.semibold))
                .foregroundStyle(RithamColor.paper)
                .fixedSize(horizontal: false, vertical: true)

            Text(capability.detail)
                .modifier(RithamType.fineprint())
                .foregroundStyle(RithamColor.paper)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// One named, permanently-free capability. A plain descriptive pair -- no action closure, no
/// affordance of any kind -- so an entry here can never carry a purchase, subscribe, or upgrade
/// action, structurally, not just by convention.
struct AlwaysFreeCapability: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String

    private init(title: String, detail: String) {
        self.id = title
        self.title = title
        self.detail = detail
    }

    /// The single declared source both `AlwaysFreeListView` and `AlwaysFreeListTests` read --
    /// every capability named here corresponds to a symbol or screen that actually exists in
    /// this build (CARDIO-01/02, full retroactive-editable training history, `PlateCalculator`,
    /// the one-rep-max estimate, `SupersetGrouping`, `MovementPattern` tagging).
    ///
    /// MONETIZE-01's original wording also names heart-rate display when a device is paired.
    /// This build has no wearable-pairing capability at all -- multi-wearable fusion is WEAR-01,
    /// an explicit v2 requirement -- so naming heart-rate display here would claim a capability
    /// this build does not actually have, which would break this very list's own "matches what's
    /// actually gated (or not) elsewhere" property (ROADMAP.md's Phase 2 success criterion 6,
    /// corrected 2026-09-04 for exactly this reason). Heart-rate display returns to this list the
    /// moment WEAR-01 ships.
    static let all: [AlwaysFreeCapability] = [
        AlwaysFreeCapability(
            title: "Manual-stopwatch cardio tracking",
            detail: "Track any cardio session with a simple stopwatch -- no GPS or paired device required."
        ),
        AlwaysFreeCapability(
            title: "GPS-tracked cardio",
            detail: "Pace, distance, elevation, and mile/km splits for every GPS-tracked run, walk, or ride."
        ),
        AlwaysFreeCapability(
            title: "Full training history",
            detail: "Every session you log stays available to review, retroactively edit, merge, or split -- never trimmed to a recent window."
        ),
        AlwaysFreeCapability(
            title: "Plate calculator",
            detail: "Work out which plates to load for any target weight, across barbell, EZ, trap, Smith, and stack equipment."
        ),
        AlwaysFreeCapability(
            title: "One-rep-max estimate",
            detail: "Estimate your one-rep max from a logged working set."
        ),
        AlwaysFreeCapability(
            title: "Superset support",
            detail: "Group exercises into supersets during a lift session."
        ),
        AlwaysFreeCapability(
            title: "Movement-pattern tagging",
            detail: "Every lift is auto-tagged by movement pattern, filterable in your training history."
        ),
    ]

    /// Free permanently, never a trial period -- the direct answer to MONETIZE-01's "matches
    /// what's actually gated (or not) elsewhere" test. "No subscription, no premium tier" is the
    /// message MONETIZE-01 asks this screen to communicate, so it's stated in plain language
    /// rather than banned as purchase-adjacent wording.
    static let commitmentStatement = "Everything on this list is free, permanently. Not a trial, not a preview of a paid tier -- there's no subscription and no premium version of any of it."

    /// Documents that forgiveness mechanics are never monetized -- a permanent, locked product
    /// decision (see `PROJECT.md` Key Decisions) -- while being explicit that they ship with the
    /// Momentum streak system, not in this build yet, so this statement never claims a mechanic
    /// that isn't actually present.
    static let forgivenessStatement = "Streak-forgiveness mechanics -- shields, comeback repair, and the injury guardrail -- are a permanent, locked decision: never monetized, ever. They arrive with the Momentum streak system, which isn't part of this build yet."
}
