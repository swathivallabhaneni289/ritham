import SwiftUI
import RithamCore

/// KIDCONTENT-01/KIDCONTENT-02: the one combined food-and-movement idea screen plus the optional
/// multi-child section, reached from `SettingsView`'s own "Kid Ideas" row (see that file's
/// comment recording the D-04 decision this placement implements).
///
/// (a) This screen is reached only from `SettingsView`'s own sheet and is deliberately not a
/// `HomeHubView` dashboard section, because not every parent has a child (D-04,
/// 04.2-RESEARCH.md Pitfall 1). It does NOT conform to `OnboardingStepPresenting` and takes no
/// `OnboardingFlow` -- unlike `DietPlanView`, this screen writes no screening data, so it needs
/// no `flow`.
/// (b) Food and movement ideas live together on this one screen, not two separate screens (D-05).
/// (c) The ideas are a browsable library the parent may reopen any time, not a shown-once
/// education block (D-08) -- nothing here tracks whether a given visit is the first.
/// (d) This screen persists nothing about which ideas were seen, tried, or liked (D-09); the only
/// write path anywhere on it is the child-entry section, through `ChildEntryStore`.
struct KidIdeasView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var childStore: ChildEntryStore?
    @State private var renamingEntryID: UUID?
    @State private var renameText = ""
    @State private var entryPendingDeletion: ChildEntryRecord?

    var body: some View {
        RithamScreen(surface: DecorativeSurface.flat, headline: KidContentCopy.Screen.headline) {
            VStack(alignment: .leading, spacing: RithamSpacing.lg) {
                Text(KidContentCopy.Screen.intro)
                    .font(RithamType.body)
                    .foregroundStyle(RithamColor.paper)
                    .fixedSize(horizontal: false, vertical: true)

                foodSection
                movementSection

                // Load-bearing ordering: `KidContentCopy.Screen.disclaimer`'s second sentence
                // ("Every idea above is reproduced...") refers to the two idea groups above it.
                Text(KidContentCopy.Screen.disclaimer)
                    .font(RithamType.body)
                    .foregroundStyle(RithamColor.paper)
                    .fixedSize(horizontal: false, vertical: true)

                childSection

                SecondaryCTAButton(title: KidContentCopy.Screen.doneCTA) {
                    dismiss()
                }
            }
        }
        .onAppear(perform: ensureLoaded)
        .confirmationDialog(
            KidContentCopy.Children.deleteConfirmation,
            isPresented: Binding(
                get: { entryPendingDeletion != nil },
                set: { if !$0 { entryPendingDeletion = nil } }
            ),
            presenting: entryPendingDeletion
        ) { entry in
            Button(KidContentCopy.Children.deleteCTA, role: .destructive) {
                childStore?.remove(id: entry.id)
                entryPendingDeletion = nil
            }
            Button(KidContentCopy.Children.cancelCTA, role: .cancel) {
                entryPendingDeletion = nil
            }
        }
    }

    // MARK: - Food and movement groups

    private var foodSection: some View {
        VStack(alignment: .leading, spacing: RithamSpacing.md) {
            Text(KidContentCopy.Screen.foodSectionTitle)
                .font(RithamType.heading)
                .foregroundStyle(RithamColor.paper)

            ideaGroup(
                intro: KidContentCatalog.veggiesAndFruitsIntro,
                ideas: KidContentCatalog.ideas(in: .food).filter { $0.citation == KidContentCatalog.veggiesAndFruitsCitation },
                citation: KidContentCatalog.veggiesAndFruitsCitation
            )

            ideaGroup(
                intro: KidContentCatalog.snackTipsIntro,
                ideas: KidContentCatalog.ideas(in: .food).filter { $0.citation == KidContentCatalog.snackTipsCitation },
                citation: KidContentCatalog.snackTipsCitation
            )
        }
    }

    private var movementSection: some View {
        VStack(alignment: .leading, spacing: RithamSpacing.md) {
            Text(KidContentCopy.Screen.movementSectionTitle)
                .font(RithamType.heading)
                .foregroundStyle(RithamColor.paper)

            ideaGroup(
                intro: nil,
                ideas: KidContentCatalog.ideas(in: .movement),
                citation: KidContentCatalog.physicalActivityCitation
            )
        }
    }

    /// One source-scoped sub-group: an optional preamble, its idea rows, then one attribution
    /// line -- one per sub-group, never per idea.
    @ViewBuilder
    private func ideaGroup(intro: String?, ideas: [KidContentIdea], citation: KidContentCitation) -> some View {
        VStack(alignment: .leading, spacing: RithamSpacing.sm) {
            if let intro {
                Text(intro)
                    .font(RithamType.body)
                    .foregroundStyle(RithamColor.paper)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(ideas) { idea in
                ideaRow(idea)
            }

            Text(KidContentCopy.Screen.sourceLine(attribution: citation.attribution))
                .modifier(RithamType.fineprint())
                .foregroundStyle(RithamColor.paper)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// A plain text row -- no `Button`, no `onTapGesture`, no `NavigationLink`, no disclosure
    /// control, no per-idea state of any kind (D-09).
    private func ideaRow(_ idea: KidContentIdea) -> some View {
        VStack(alignment: .leading, spacing: RithamSpacing.xs) {
            Text(idea.title)
                .font(RithamType.body.weight(.semibold))
                .foregroundStyle(RithamColor.paper)
                .fixedSize(horizontal: false, vertical: true)

            Text(idea.body)
                .font(RithamType.body)
                .foregroundStyle(RithamColor.paper)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Child section

    private var childSection: some View {
        VStack(alignment: .leading, spacing: RithamSpacing.sm) {
            Text(KidContentCopy.Children.sectionTitle)
                .font(RithamType.heading)
                .foregroundStyle(RithamColor.paper)

            Text(KidContentCopy.Children.explainer)
                .font(RithamType.body)
                .foregroundStyle(RithamColor.paper)
                .fixedSize(horizontal: false, vertical: true)

            if let childStore {
                if childStore.entries.isEmpty {
                    Text(KidContentCopy.Children.emptyState)
                        .font(RithamType.label)
                        .foregroundStyle(RithamColor.paper)
                } else {
                    VStack(spacing: RithamSpacing.sm) {
                        ForEach(childStore.entries) { entry in
                            childRow(entry, childStore: childStore)
                        }
                    }
                }
            }

            PrimaryCTAButton(title: KidContentCopy.Children.addCTA) {
                childStore?.add()
            }
        }
    }

    /// Mirrors `PrivacyZonesView.zoneRow` closely: an inline rename `TextField` with Save and
    /// Cancel, otherwise the display label plus Rename and a destructive-outlined Delete button.
    @ViewBuilder
    private func childRow(_ entry: ChildEntryRecord, childStore: ChildEntryStore) -> some View {
        VStack(alignment: .leading, spacing: RithamSpacing.sm) {
            if renamingEntryID == entry.id {
                TextField(KidContentCopy.Children.nicknameFieldLabel, text: $renameText)
                    .font(RithamType.body)
                    .foregroundStyle(RithamColor.paper)
                    .padding(RithamSpacing.sm)
                    .frame(minHeight: RithamSpacing.minimumTapTarget)
                    .background(
                        RoundedRectangle(cornerRadius: RithamSpacing.sm)
                            .stroke(RithamColor.paper, lineWidth: 1)
                    )
                    .accessibilityLabel(KidContentCopy.Children.nicknameFieldLabel)

                HStack(spacing: RithamSpacing.sm) {
                    SecondaryCTAButton(title: KidContentCopy.Children.saveCTA) {
                        // The store and the persistence layer already normalize whitespace
                        // (HealthDataStore.normalizedNickname), so this view must not duplicate
                        // that rule -- the typed text is passed through unmodified.
                        childStore.rename(id: entry.id, to: renameText)
                        renamingEntryID = nil
                    }
                    SecondaryCTAButton(title: KidContentCopy.Children.cancelCTA) {
                        renamingEntryID = nil
                    }
                }
            } else {
                Text(childStore.displayLabel(for: entry))
                    .font(RithamType.body)
                    .foregroundStyle(RithamColor.paper)

                HStack(spacing: RithamSpacing.sm) {
                    SecondaryCTAButton(title: KidContentCopy.Children.renameCTA) {
                        renameText = entry.nickname ?? ""
                        renamingEntryID = entry.id
                    }

                    Button {
                        entryPendingDeletion = entry
                    } label: {
                        Text(KidContentCopy.Children.deleteCTA)
                            .font(RithamType.body)
                            .foregroundStyle(RithamColor.destructive)
                            .frame(minWidth: RithamSpacing.minimumTapTarget, minHeight: RithamSpacing.minimumTapTarget)
                            .frame(maxWidth: .infinity)
                            .overlay(
                                RoundedRectangle(cornerRadius: RithamSpacing.sm)
                                    .stroke(RithamColor.destructive, lineWidth: 1)
                            )
                    }
                    .accessibilityLabel(
                        KidContentCopy.Children.deleteAccessibilityLabel(for: childStore.displayLabel(for: entry))
                    )
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
        let currentStore = childStore ?? ChildEntryStore(store: HealthDataStore(context: modelContext))
        currentStore.load()
        childStore = currentStore
    }
}
