import SwiftUI
import RithamCore

/// GROUPEVENTS-03's Privacy Zones settings list. Registered under `.privacyZones` for
/// `StepRegistry` (`PrivacyZoneRegistration.swift`) so `StepRegistry.unregisteredSteps` stays
/// empty, but reached only from `SettingsView`'s own `.sheet` presentation -- the identical
/// "registered for the registry, reached by a different path" shape
/// `SignInWithAppleView`/`OnboardingStep.swift`'s own header comment already established for
/// `.signInWithApple`.
///
/// `04.1-UI-SPEC.md`'s Privacy Zones settings bullet is the load-bearing rule this file exists to
/// implement, not merely to follow: the saved-zones list shows each zone by its own user-given
/// label only, never its underlying point -- the settings screen itself must not re-expose the
/// precision a zone was created to stop retaining, even to the owning user. This file's own
/// acceptance check greps for the total absence of the three field names `PrivacyZone`'s own
/// point-holding properties are declared under, so no future edit can reintroduce that precision
/// here by accident.
struct PrivacyZonesView: View, OnboardingStepPresenting {
    static let step: OnboardingStep = .privacyZones

    /// `flow` is accepted only to satisfy `OnboardingStepPresenting`'s registry contract -- this
    /// screen never routes through it, matching `SignInWithAppleView`'s own precedent for a
    /// screen reached from outside the router.
    static func makeView(flow: OnboardingFlow) -> AnyView {
        AnyView(PrivacyZonesView())
    }

    @Environment(\.modelContext) private var modelContext

    @State private var zoneStore: PrivacyZoneStore?
    @State private var isAddingZone = false
    @State private var renamingZoneID: UUID?
    @State private var renameText = ""
    @State private var zonePendingDeletion: PrivacyZone?

    var body: some View {
        RithamScreen(surface: DecorativeSurface.flat, headline: "Privacy Zones") {
            Text("A place you mark here is never shared by its own point when you post a location -- only its label, or nothing at all, depending on how you set it below.")
                .font(RithamType.body)
                .foregroundStyle(RithamColor.paper)
                .fixedSize(horizontal: false, vertical: true)

            if let zoneStore {
                if zoneStore.zones.isEmpty {
                    Text("No Privacy Zones yet.")
                        .font(RithamType.label)
                        .foregroundStyle(RithamColor.paper)
                } else {
                    VStack(spacing: RithamSpacing.sm) {
                        ForEach(zoneStore.zones) { zone in
                            zoneRow(zone, zoneStore: zoneStore)
                        }
                    }
                }
            }

            PrimaryCTAButton(title: "Add Privacy Zone") {
                isAddingZone = true
            }
        }
        .onAppear(perform: ensureLoaded)
        .sheet(isPresented: $isAddingZone, onDismiss: { zoneStore?.load() }) {
            if let zoneStore {
                AddPrivacyZoneView(zoneStore: zoneStore)
            }
        }
        .confirmationDialog(
            "Delete this Privacy Zone?",
            isPresented: Binding(
                get: { zonePendingDeletion != nil },
                set: { if !$0 { zonePendingDeletion = nil } }
            ),
            presenting: zonePendingDeletion
        ) { zone in
            Button("Delete", role: .destructive) {
                zoneStore?.remove(id: zone.id)
                zonePendingDeletion = nil
            }
            Button("Cancel", role: .cancel) {
                zonePendingDeletion = nil
            }
        }
    }

    // MARK: - Row

    @ViewBuilder
    private func zoneRow(_ zone: PrivacyZone, zoneStore: PrivacyZoneStore) -> some View {
        VStack(alignment: .leading, spacing: RithamSpacing.sm) {
            if renamingZoneID == zone.id {
                TextField("Zone label", text: $renameText)
                    .font(RithamType.body)
                    .foregroundStyle(RithamColor.paper)
                    .padding(RithamSpacing.sm)
                    .frame(minHeight: RithamSpacing.minimumTapTarget)
                    .background(
                        RoundedRectangle(cornerRadius: RithamSpacing.sm)
                            .stroke(RithamColor.paper, lineWidth: 1)
                    )
                    .accessibilityLabel("Zone label")

                HStack(spacing: RithamSpacing.sm) {
                    SecondaryCTAButton(title: "Save") {
                        commitRename(zone: zone, zoneStore: zoneStore)
                    }
                    SecondaryCTAButton(title: "Cancel") {
                        renamingZoneID = nil
                    }
                }
            } else {
                Text(zone.label)
                    .font(RithamType.body)
                    .foregroundStyle(RithamColor.paper)

                HStack(spacing: RithamSpacing.sm) {
                    SecondaryCTAButton(title: "Rename") {
                        beginRename(zone)
                    }

                    Button {
                        zonePendingDeletion = zone
                    } label: {
                        Text("Delete")
                            .font(RithamType.body)
                            .foregroundStyle(RithamColor.destructive)
                            .frame(minWidth: RithamSpacing.minimumTapTarget, minHeight: RithamSpacing.minimumTapTarget)
                            .frame(maxWidth: .infinity)
                            .overlay(
                                RoundedRectangle(cornerRadius: RithamSpacing.sm)
                                    .stroke(RithamColor.destructive, lineWidth: 1)
                            )
                    }
                    .accessibilityLabel("Delete \(zone.label)")
                }
            }
        }
        .padding(RithamSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: RithamSpacing.sm)
                .fill(RithamColor.paper.opacity(0.06))
        )
    }

    // MARK: - Actions

    private func ensureLoaded() {
        let currentStore = zoneStore ?? PrivacyZoneStore(store: HealthDataStore(context: modelContext))
        currentStore.load()
        zoneStore = currentStore
    }

    private func beginRename(_ zone: PrivacyZone) {
        renameText = zone.label
        renamingZoneID = zone.id
    }

    private func commitRename(zone: PrivacyZone, zoneStore: PrivacyZoneStore) {
        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            zoneStore.rename(id: zone.id, to: trimmed)
        }
        renamingZoneID = nil
    }
}
