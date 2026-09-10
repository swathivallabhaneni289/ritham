import SwiftUI
import RithamCore

/// The per-completion feed card (04.1-UI-SPEC.md's Group Feed and History section): a circular
/// avatar and name, the activity badge with the event name and activity type, the completion date,
/// an optional photo, an optional generalized place name, an optional short caption, and the cheer
/// row. Built in the existing dashboard card shell -- a rounded rectangle on the low-opacity `paper`
/// fill, standard internal padding -- matching every other card in the app
/// (`GroupDetailView.swift`'s member row, `FriendsListView.swift`'s friend row).
///
/// **A card with a time and a card without one are structurally identical -- same layout, same
/// colors, same weights, same badge set, same everything -- apart from the trailing time words in
/// the sentence.** No color, no icon, no badge, no weight change marks who added a number. A marker
/// on who shared a time would itself be a subtle comparison signal, exactly what GROUPEVENTS-04
/// exists to remove -- "add a small badge for the time" is precisely the change a later editor
/// would think is an improvement, and it is not one. `RithamType.numerals()` (`.monospacedDigit()`)
/// is applied to the sentence unconditionally, in both branches, for exactly this reason: it is not
/// a difference between the two cases, only a digit-stability property that has zero visible effect
/// when no digit is present.
struct CompletionCard: View {
    let item: FeedItem
    let onToggleCheer: (Cheer) -> Void

    private static let dateFormatter = ISO8601DateFormatter()

    private var activityType: ActivityType {
        ActivityType(rawValue: item.activityType)
    }

    private var completedDate: Date? {
        Self.dateFormatter.date(from: item.completedAt)
    }

    /// The card's one body sentence, composed only through `SocialCopy.Feed`'s two overloads --
    /// never assembled inline. Selecting between them is the only place `item.ownTimeSeconds`'
    /// presence affects this view at all; nothing about color, weight, or layout below reads it.
    private var sentence: String {
        if let ownTimeSeconds = item.ownTimeSeconds {
            return SocialCopy.Feed.card(name: item.actor.displayName, eventName: item.eventName, time: Self.formattedTime(ownTimeSeconds))
        }
        return SocialCopy.Feed.card(name: item.actor.displayName, eventName: item.eventName)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: RithamSpacing.sm) {
            HStack(spacing: RithamSpacing.sm) {
                AvatarView(name: item.actor.displayName, diameter: 40)

                Text(item.actor.displayName)
                    .font(RithamType.body)
                    .foregroundStyle(RithamColor.paper)

                Spacer(minLength: 0)
            }

            HStack(spacing: RithamSpacing.sm) {
                ActivityTypeIcon(activityType: activityType)

                VStack(alignment: .leading, spacing: RithamSpacing.xs) {
                    Text(item.eventName)
                        .font(RithamType.label)
                        .foregroundStyle(RithamColor.paper)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(activityType.displayName)
                        .modifier(RithamType.fineprint())
                        .foregroundStyle(RithamColor.paper)
                }
            }

            Text(sentence)
                .font(RithamType.body)
                .modifier(RithamType.numerals())
                .foregroundStyle(RithamColor.paper)
                .fixedSize(horizontal: false, vertical: true)

            if let completedDate {
                Text(completedDate.formatted(date: .abbreviated, time: .omitted))
                    .modifier(RithamType.fineprint())
                    .foregroundStyle(RithamColor.paper)
            }

            if let photoURL = item.photoURL, let url = URL(string: photoURL) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: RithamSpacing.sm))
                    }
                }
            }

            if let placeName = item.placeName {
                Text(placeName)
                    .font(RithamType.label)
                    .foregroundStyle(RithamColor.paper)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let note = item.note {
                Text(note)
                    .font(RithamType.label)
                    .foregroundStyle(RithamColor.paper)
                    .fixedSize(horizontal: false, vertical: true)
            }

            CheerReactionRow(
                niceWorkSentByViewer: item.cheers.niceWorkSentByViewer,
                keepGoingSentByViewer: item.cheers.keepGoingSentByViewer,
                onToggle: onToggleCheer
            )
        }
        .padding(RithamSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: RithamSpacing.sm)
                .fill(RithamColor.paper.opacity(0.06))
        )
    }

    private static func formattedTime(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
