import PhotosUI
import SwiftUI
import RithamCore

/// GROUPEVENTS-02/03: the completion-logging screen. Logging is binary -- a single primary CTA --
/// and the own-time follow-up offers add and skip with **exactly equal prominence**: both render
/// as `SecondaryCTAButton`, same size, same style, same tap target, side by side. This is the one
/// place in this phase where two secondary buttons side by side is correct, deliberately not a
/// `PrimaryCTAButton` paired with a de-emphasized link -- that shape would itself be a nudge
/// toward sharing a number, which is exactly what this locked requirement exists to prevent
/// (`docs/group-events.md` §2, `04.1-UI-SPEC.md`'s Spacing Scale equal-prominence-pair rule). Do
/// not "improve" this into a primary/link pair; a future editor doing so would be undoing the
/// requirement, not simplifying the layout.
///
/// This does not weaken the "logging a completion takes one action" truth: that statement is about
/// the decision being binary (`docs/group-events.md` §2's "Logging is binary: done"), not about a
/// network request having already left the device the instant the primary CTA is tapped. See
/// `CompletionLoggingModel`'s own header comment for the full sequencing rationale -- the one
/// `POST` this screen ever sends fires only once the own-time decision (add or skip) is finalized,
/// since `internal/events` exposes no update route.
///
/// Photo attach and location attach are two independent, always-visible opt-ins, gathered before
/// the primary CTA is ever tapped, each its own two-option chip control (never the platform's
/// native switch control -- this codebase has zero uses of that; every binary preference here goes
/// through the same chip pattern `AddPrivacyZoneView`'s own generalize/suppress choice and the
/// Daily Movement Snapshot preference screen already established). They are never bundled into
/// one control: choosing to attach a photo never turns
/// location sharing on, and choosing to share a location never turns photo attach on
/// (`CompletionLoggingModel`'s own independence guarantee, asserted in both directions by
/// `CompletionLoggingTests`).
struct CompletionLoggingView: View, OnboardingStepPresenting {
    static let step: OnboardingStep = .completionLogging

    static func makeView(flow: OnboardingFlow) -> AnyView {
        AnyView(CompletionLoggingView(flow: flow))
    }

    let flow: OnboardingFlow

    @Environment(\.modelContext) private var modelContext

    @State private var eventsModel = GoalEventsModel()
    @State private var completionModel = CompletionLoggingModel()
    @State private var event: GoalEvent?
    @State private var zoneStore: PrivacyZoneStore?

    @State private var photoAPIClient = SocialAPIClient(sessionStore: SessionStore())
    @State private var photoSelection: Set<CompletionAttachOption> = [CompletionAttachOption(isOn: false)]
    @State private var locationSelection: Set<CompletionAttachOption> = [CompletionAttachOption(isOn: false)]
    @State private var pickerItem: PhotosPickerItem?
    @State private var isUploadingPhoto = false
    @State private var showPhotoError = false

    @State private var noteText = ""
    @State private var privateDistanceText = ""
    @State private var privateDurationText = ""

    @State private var isEnteringDuration = false
    @State private var durationMinutesText = ""
    @State private var showDurationError = false

    var body: some View {
        RithamScreen(surface: DecorativeSurface.flat, headline: headline) {
            switch completionModel.stage {
            case .ready:
                readySection
            case .addingTime:
                ownTimeSection
            case .logging:
                ProgressView()
            case .logged:
                EmptyView()
            case .failed:
                failedSection
            }

            SecondaryCTAButton(title: "Back") {
                flow.goBack()
            }
        }
        .task { await load() }
        .onChange(of: pickerItem) { _, newItem in
            guard let newItem else { return }
            Task { await handlePhotoPick(newItem) }
        }
        .onChange(of: photoSelection) { _, newValue in
            guard let chosen = newValue.first, !chosen.isOn else { return }
            completionModel.removePhoto()
            pickerItem = nil
            showPhotoError = false
        }
        .onChange(of: locationSelection) { _, newValue in
            guard let chosen = newValue.first else { return }
            Task { await completionModel.setLocationSharingEnabled(chosen.isOn, zones: zoneStore?.zones ?? []) }
        }
        .onChange(of: noteText) { _, newValue in
            completionModel.attachCaption(newValue)
        }
        .onChange(of: privateDistanceText) { _, newValue in
            completionModel.setPrivateDistance(metres: Double(newValue).map { $0 * 1000 })
        }
        .onChange(of: privateDurationText) { _, newValue in
            completionModel.setPrivateDuration(seconds: Double(newValue).map { Int($0 * 60) })
        }
        .onChange(of: completionModel.stage) { _, newStage in
            guard newStage == .logged else { return }
            Task { await generateCertificateAndReveal() }
        }
    }

    // MARK: - Headline

    /// The locked confirmation copy renders only once the server has actually confirmed the
    /// write (`.logged`) -- never earlier, and never optimistically. Every other stage shows the
    /// event's own name, matching every other screen in this phase's headline convention.
    private var headline: String? {
        switch completionModel.stage {
        case .logged:
            return event.map { SocialCopy.Completion.confirmation(eventName: $0.name) }
        default:
            return event?.name ?? SocialCopy.Completion.logCTA
        }
    }

    // MARK: - .ready

    @ViewBuilder
    private var readySection: some View {
        photoSection
        locationSection
        noteSection
        privateSection

        PrimaryCTAButton(title: SocialCopy.Completion.logCTA) {
            completionModel.logDone()
        }
    }

    @ViewBuilder
    private var photoSection: some View {
        ChoiceQuestionView(
            prompt: SocialCopy.Completion.photoPrompt,
            options: CompletionAttachOption.all,
            mode: .single,
            selection: $photoSelection,
            optionTitle: Self.photoOptionTitle
        )

        if photoSelection.contains(where: { $0.isOn }) {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Text(completionModel.draft.photo == nil ? SocialCopy.Completion.choosePhotoCTA : SocialCopy.Completion.photoAttachedConfirmation)
                    .font(RithamType.body)
                    .foregroundStyle(RithamColor.paper)
                    .frame(minHeight: RithamSpacing.minimumTapTarget)
            }

            if isUploadingPhoto {
                ProgressView()
            }

            if showPhotoError {
                Text(SocialCopy.Completion.photoUploadFailed)
                    .font(RithamType.label)
                    .foregroundStyle(RithamColor.hot)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var locationSection: some View {
        ChoiceQuestionView(
            prompt: SocialCopy.Completion.locationPrompt,
            options: CompletionAttachOption.all,
            mode: .single,
            selection: $locationSelection,
            optionTitle: Self.locationOptionTitle
        )

        switch completionModel.lastLocationOutcome {
        case .place(let name):
            Text(name)
                .font(RithamType.label)
                .foregroundStyle(RithamColor.paper)
        case .generalizedByZone(let label):
            Text(label)
                .font(RithamType.label)
                .foregroundStyle(RithamColor.paper)
        case .suppressedByZone:
            Text(SocialCopy.PrivacyZone.suppressedNote)
                .font(RithamType.label)
                .foregroundStyle(RithamColor.paper)
                .fixedSize(horizontal: false, vertical: true)
        case .none:
            EmptyView()
        }
    }

    @ViewBuilder
    private var noteSection: some View {
        VStack(alignment: .leading, spacing: RithamSpacing.sm) {
            Text(SocialCopy.Completion.noteFieldLabel)
                .font(RithamType.label)
                .foregroundStyle(RithamColor.paper)

            TextField(SocialCopy.Completion.noteFieldLabel, text: $noteText, axis: .vertical)
                .font(RithamType.body)
                .foregroundStyle(RithamColor.paper)
                .padding(RithamSpacing.sm)
                .overlay(
                    RoundedRectangle(cornerRadius: RithamSpacing.sm)
                        .stroke(RithamColor.paper.opacity(0.2), lineWidth: 1)
                )
        }
    }

    /// The personal, private-to-you measurement fields -- visually separated under their own
    /// heading so the structural client/server separation `CompletionDraft` already guarantees
    /// (these values never reach `outgoingRequest()`) has a matching visual separation a reviewer
    /// can eyeball at a glance, per this plan's own artifact list.
    @ViewBuilder
    private var privateSection: some View {
        VStack(alignment: .leading, spacing: RithamSpacing.sm) {
            Text(SocialCopy.Completion.privateSectionHeading)
                .font(RithamType.heading)
                .foregroundStyle(RithamColor.paper)

            privateField(SocialCopy.Completion.privateDistanceFieldLabel, text: $privateDistanceText)
            privateField(SocialCopy.Completion.privateDurationFieldLabel, text: $privateDurationText)
        }
        .padding(.top, RithamSpacing.lg)
    }

    @ViewBuilder
    private func privateField(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: RithamSpacing.xs) {
            Text(label)
                .font(RithamType.label)
                .foregroundStyle(RithamColor.paper)

            TextField(label, text: text)
                .keyboardType(.decimalPad)
                .foregroundStyle(RithamColor.paper)
                .padding(RithamSpacing.md)
                .frame(minHeight: RithamSpacing.minimumTapTarget)
                .background(
                    RoundedRectangle(cornerRadius: RithamSpacing.sm)
                        .fill(RithamColor.paper.opacity(0.06))
                )
        }
    }

    // MARK: - .addingTime

    /// The locked own-time prompt, then the equal-prominence pair -- see this view's own header
    /// comment for why both are `SecondaryCTAButton`.
    @ViewBuilder
    private var ownTimeSection: some View {
        Text(SocialCopy.Completion.ownTimePrompt)
            .font(RithamType.body)
            .foregroundStyle(RithamColor.paper)
            .fixedSize(horizontal: false, vertical: true)

        if isEnteringDuration {
            VStack(alignment: .leading, spacing: RithamSpacing.sm) {
                Text(SocialCopy.Completion.durationFieldLabel)
                    .font(RithamType.label)
                    .foregroundStyle(RithamColor.paper)

                TextField(SocialCopy.Completion.durationFieldLabel, text: $durationMinutesText)
                    .keyboardType(.numberPad)
                    .modifier(RithamType.numerals())
                    .foregroundStyle(RithamColor.paper)
                    .padding(RithamSpacing.md)
                    .frame(minHeight: RithamSpacing.minimumTapTarget)
                    .background(
                        RoundedRectangle(cornerRadius: RithamSpacing.sm)
                            .fill(RithamColor.paper.opacity(0.06))
                    )
            }

            if showDurationError {
                Text(OnboardingCopy.Errors.savingFailed)
                    .font(RithamType.label)
                    .foregroundStyle(RithamColor.hot)
                    .fixedSize(horizontal: false, vertical: true)
            }

            PrimaryCTAButton(title: SocialCopy.Completion.saveTimeCTA) {
                Task { await saveTime() }
            }

            SecondaryCTAButton(title: SocialCopy.Completion.neverMindCTA) {
                isEnteringDuration = false
                showDurationError = false
            }
        } else {
            HStack(spacing: RithamSpacing.md) {
                SecondaryCTAButton(title: SocialCopy.Completion.addTimeCTA) {
                    isEnteringDuration = true
                }
                SecondaryCTAButton(title: SocialCopy.Completion.skipCTA) {
                    Task { await skip() }
                }
            }
        }
    }

    // MARK: - .failed

    @ViewBuilder
    private var failedSection: some View {
        Text(SocialCopy.Completion.logFailed)
            .font(RithamType.label)
            .foregroundStyle(RithamColor.hot)
            .fixedSize(horizontal: false, vertical: true)

        PrimaryCTAButton(title: SocialCopy.Completion.retryCTA) {
            Task { await retry() }
        }
    }

    // MARK: - Actions

    private func load() async {
        guard let eventID = flow.selectedCompletionEventID else { return }
        event = await eventsModel.get(eventID: eventID)

        let store = HealthDataStore(context: modelContext)
        let loadedZoneStore = PrivacyZoneStore(store: store)
        loadedZoneStore.load()
        zoneStore = loadedZoneStore
    }

    private func skip() async {
        guard let eventID = flow.selectedCompletionEventID else { return }
        await completionModel.skipTime(eventID: eventID)
    }

    private func saveTime() async {
        guard let minutes = Double(durationMinutesText), minutes > 0 else {
            showDurationError = true
            return
        }
        showDurationError = false
        guard let eventID = flow.selectedCompletionEventID else { return }
        await completionModel.addTime(seconds: Int(minutes * 60), eventID: eventID)
    }

    private func retry() async {
        guard let eventID = flow.selectedCompletionEventID else { return }
        await completionModel.retry(eventID: eventID)
    }

    /// GROUPEVENTS-05: completing the event is what generates and posts the certificate -- there
    /// is no separate send step. Fires exactly once, on the completion model's own `.logged`
    /// transition (which itself fires at most once per completion, since `internal/events` exposes
    /// no update route). Reads only this screen's own already-server-confirmed values
    /// (`completionModel.lastCompletion`) -- never any other member's data, since this screen never
    /// held any to begin with. A write failure here must never hide or block the completion's own
    /// already-rendered success confirmation, so it is swallowed rather than surfaced as a second
    /// error state layered onto `.logged`.
    private func generateCertificateAndReveal() async {
        guard let response = completionModel.lastCompletion, let event else { return }
        let store = HealthDataStore(context: modelContext)
        let completionID = UUID(uuidString: response.id) ?? UUID()
        let completionDate = CompletionCard.parseTimestamp(response.completedAt) ?? completionModel.draft.completedAt
        do {
            try store.saveCertificate(
                completionID: completionID,
                eventName: event.name,
                activityType: event.activityType,
                participantName: response.displayName,
                completionDate: completionDate,
                ownTimeSeconds: response.ownTimeSeconds ?? completionModel.draft.ownTimeSeconds,
                photoAssetID: completionModel.draft.photo?.assetID
            )
            flow.open(.certificate)
        } catch {
            // See this function's own header comment: a certificate write failure must never
            // block or hide the completion's own already-confirmed success.
        }
    }

    private func handlePhotoPick(_ item: PhotosPickerItem) async {
        isUploadingPhoto = true
        showPhotoError = false
        do {
            let jpegData = try await PhotoAttachment.encodableJPEG(from: item)
            let asset = try await PhotoAttachment.upload(jpegData, via: photoAPIClient)
            completionModel.attachPhoto(asset)
            isUploadingPhoto = false
        } catch {
            isUploadingPhoto = false
            showPhotoError = true
            photoSelection = [CompletionAttachOption(isOn: false)]
        }
    }

    private static func photoOptionTitle(_ option: CompletionAttachOption) -> String {
        option.isOn ? SocialCopy.Completion.photoOnOption : SocialCopy.Completion.photoOffOption
    }

    private static func locationOptionTitle(_ option: CompletionAttachOption) -> String {
        option.isOn ? SocialCopy.Completion.locationOnOption : SocialCopy.Completion.locationOffOption
    }
}

/// The shared on/off option type both attach chips use, matching
/// `MovementSnapshotOptInOption`/`PrivacyZoneEffectOption`'s own "wrap a bare value for
/// `ChoiceQuestionView`'s `Identifiable` requirement" precedent -- a bare `Bool` has no natural
/// single UI-option identity of its own. `photoSelection` and `locationSelection` are two entirely
/// separate `@State` bindings over this same option type; sharing the option type is not the same
/// as sharing the switch -- see this file's own header comment on why the two opt-ins stay
/// independent.
struct CompletionAttachOption: Hashable, Identifiable {
    let isOn: Bool
    var id: Bool { isOn }

    /// Off first, matching every other opt-in preference default in this phase
    /// (`MovementSnapshotOptInOption.all`'s own "On first" note is the opposite convention for a
    /// settings toggle already known to be user-controlled; these two attach opt-ins default to
    /// off per GROUPEVENTS-03, so the off option renders first here to match the pre-selected
    /// value).
    static let all: [CompletionAttachOption] = [
        CompletionAttachOption(isOn: false),
        CompletionAttachOption(isOn: true),
    ]
}
