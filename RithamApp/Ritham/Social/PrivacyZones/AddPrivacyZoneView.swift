import CoreLocation
import MapKit
import SwiftUI
import RithamCore

/// The two effects a new zone can apply, wrapped for `ChoiceQuestionView`'s `Identifiable`
/// requirement -- the same rationale `WeeklyFrequencyOption`/`MomentumTargetOption`/
/// `MovementSnapshotOptInOption` already document: `PrivacyZoneEffect` has no natural single
/// UI-option identity of its own beyond itself, which this wrapper supplies without retroactively
/// conforming the domain type.
struct PrivacyZoneEffectOption: Hashable, Identifiable {
    let effect: PrivacyZoneEffect
    var id: PrivacyZoneEffect { effect }

    static let all: [PrivacyZoneEffectOption] = PrivacyZoneEffect.allCases.map(PrivacyZoneEffectOption.init)
}

/// The zone-creation screen. A native map picker to set the point is unavoidable -- choosing a
/// zone requires choosing a place -- but nothing picked here survives past this screen's own
/// save: `PrivacyZonesView`'s saved-zone row never re-displays it (04.1-UI-SPEC.md's Privacy Zones
/// settings bullet).
///
/// Generalize/suppress uses `ChoiceQuestionView`'s existing two-option chip control -- the same
/// binary-choice pattern the Daily Movement Snapshot preference screen already established --
/// never the platform's native switch control, matching this codebase's zero-uses-of-it
/// convention.
struct AddPrivacyZoneView: View {
    @Environment(\.dismiss) private var dismiss
    let zoneStore: PrivacyZoneStore

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var pickedPoint: CLLocationCoordinate2D?
    @State private var label = ""
    @State private var effectSelection: Set<PrivacyZoneEffectOption> = [PrivacyZoneEffectOption(effect: .suppress)]
    @State private var showMissingPointError = false
    @State private var showSaveError = false

    /// A fixed, reasonable default rather than a user-facing radius control -- `PrivacyZone`'s
    /// own doc comment states the radius is an internal evaluation input only, never displayed or
    /// collected as a number anywhere in this UI.
    private static let defaultRadiusMetres: Double = 150

    var body: some View {
        RithamScreen(surface: DecorativeSurface.flat, headline: "Add Privacy Zone") {
            Text("Tap the map to mark this zone's centre. Once saved, this screen's own map is never shown again -- only the label you give it below.")
                .font(RithamType.body)
                .foregroundStyle(RithamColor.paper)
                .fixedSize(horizontal: false, vertical: true)

            mapPicker

            labelField

            ChoiceQuestionView(
                prompt: "When a shared location falls inside this zone",
                helper: "Generalize shows this zone's own label instead of the real place. Suppress shows nothing about the location at all.",
                options: PrivacyZoneEffectOption.all,
                mode: .single,
                selection: $effectSelection,
                optionTitle: Self.optionTitle
            )

            if showMissingPointError {
                Text("Tap the map to mark this zone before saving.")
                    .font(RithamType.label)
                    .foregroundStyle(RithamColor.hot)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if showSaveError {
                Text(OnboardingCopy.Errors.savingFailed)
                    .font(RithamType.label)
                    .foregroundStyle(RithamColor.hot)
                    .fixedSize(horizontal: false, vertical: true)
            }

            PrimaryCTAButton(title: "Save zone") {
                save()
            }

            SecondaryCTAButton(title: "Cancel") {
                dismiss()
            }
        }
    }

    private var mapPicker: some View {
        MapReader { proxy in
            Map(position: $cameraPosition) {
                if let pickedPoint {
                    Marker(label.isEmpty ? "New zone" : label, coordinate: pickedPoint)
                }
            }
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: RithamSpacing.sm))
            .onTapGesture { screenPoint in
                guard let tapped = proxy.convert(screenPoint, from: .local) else { return }
                pickedPoint = tapped
                showMissingPointError = false
            }
        }
    }

    private var labelField: some View {
        VStack(alignment: .leading, spacing: RithamSpacing.xs) {
            Text("Label")
                .font(RithamType.label)
                .foregroundStyle(RithamColor.paper)

            TextField("e.g. Home", text: $label)
                .font(RithamType.body)
                .foregroundStyle(RithamColor.paper)
                .padding(RithamSpacing.sm)
                .frame(minHeight: RithamSpacing.minimumTapTarget)
                .background(
                    RoundedRectangle(cornerRadius: RithamSpacing.sm)
                        .stroke(RithamColor.paper, lineWidth: 1)
                )
                .accessibilityLabel("Zone label")
        }
    }

    static func optionTitle(_ option: PrivacyZoneEffectOption) -> String {
        switch option.effect {
        case .generalize: return "Generalize"
        case .suppress: return "Suppress"
        }
    }

    private func save() {
        guard let pickedPoint else {
            showMissingPointError = true
            return
        }
        let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let effect = effectSelection.first?.effect ?? .suppress
        let saved = zoneStore.add(
            label: trimmedLabel.isEmpty ? "Zone" : trimmedLabel,
            centre: pickedPoint,
            radiusMetres: Self.defaultRadiusMetres,
            effect: effect
        )
        if saved {
            dismiss()
        } else {
            showSaveError = true
        }
    }
}
