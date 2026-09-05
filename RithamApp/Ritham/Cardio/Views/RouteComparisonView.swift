import SwiftUI
import RithamCore

// T-02-32 boundary, the one this file must never cross: comparison is single-user by
// construction. This screen has no concept of a second person's session, no shared segment, no
// standing versus anyone else, and no sorted or numbered position among sessions. PROJECT.md's
// permanent, milestone-independent exclusion on a cross-user aggregate location surface is
// enforced structurally here -- there is no query, join, network call, or type anywhere in this
// file that could ever reach another person's data -- not by a runtime check that a later edit
// could remove or forget.
//
// "Same route" here means the practical proxy the stored data actually supports today: this
// user's own prior sessions of the same activity type within a distance-tolerance band, not real
// polyline matching -- no coordinate trail is persisted anywhere in this milestone (see
// `CardioHistoryView.swift`'s route-map header comment for the full reasoning). A future plan
// that does persist a coordinate trail can tighten this proxy without touching this screen's
// single-user boundary.
//
// Includes its own opt-in toggle, writing through `HealthDataStore.saveRouteComparisonOptIn` --
// the same accessor plan 02-08 added -- so a user can turn this back off from exactly the screen
// where they turned it on.

@MainActor
@Observable
final class RouteComparisonModel {
    let activityType: ActivityType
    private(set) var matches: [CardioSession] = []
    private(set) var isOptedIn: Bool

    private let store: HealthDataStore
    private let referenceDistanceMeters: Double

    /// How close two sessions' recorded distance must be to count as "the same route" -- the
    /// distance-based proxy this file's header comment explains. 250m is a practical tolerance
    /// for GPS-accumulated distance noise across repeated real-world routes, not a value taken
    /// from any spec.
    private static let routeDistanceToleranceMeters: Double = 250

    init(activityType: ActivityType, referenceDistanceMeters: Double, store: HealthDataStore) {
        self.activityType = activityType
        self.referenceDistanceMeters = referenceDistanceMeters
        self.store = store
        self.isOptedIn = (try? store.loadRouteComparisonOptIn()) ?? false
    }

    /// Every candidate comes from this device's own store, filtered only by this user's own
    /// activity type and a distance band -- there is no path here that can ever reach a second
    /// person's session.
    func loadMatches() {
        guard isOptedIn else {
            matches = []
            return
        }
        let all = (try? store.loadCardioSessions()) ?? []
        matches = all.filter { candidate in
            candidate.activityType == activityType
                && abs(candidate.progress.distanceMeters - referenceDistanceMeters) <= Self.routeDistanceToleranceMeters
        }
    }

    func setOptIn(_ optIn: Bool) {
        isOptedIn = optIn
        try? store.saveRouteComparisonOptIn(optIn)
        loadMatches()
    }
}

struct RouteComparisonView: View {
    let activityType: ActivityType
    let referenceDistanceMeters: Double
    let store: HealthDataStore

    @State private var model: RouteComparisonModel?

    var body: some View {
        RithamScreen(
            surface: DecorativeSurface.flat,
            headline: "Your \(activityType.displayName.lowercased()) sessions on this route"
        ) {
            if let model {
                Toggle(
                    "Compare my own repeated sessions",
                    isOn: Binding(get: { model.isOptedIn }, set: { model.setOptIn($0) })
                )
                .tint(RithamColor.hot)
                .foregroundStyle(RithamColor.paper)

                if model.isOptedIn {
                    matchesSection(model)
                } else {
                    Text("Turn this on to compare your own past sessions on routes you've repeated. This is never compared against anyone else's data.")
                        .font(RithamType.body)
                        .foregroundStyle(RithamColor.paper)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .onAppear {
            let newModel = RouteComparisonModel(
                activityType: activityType,
                referenceDistanceMeters: referenceDistanceMeters,
                store: store
            )
            newModel.loadMatches()
            model = newModel
        }
    }

    @ViewBuilder
    private func matchesSection(_ model: RouteComparisonModel) -> some View {
        if model.matches.isEmpty {
            Text("No other sessions of yours on this route yet.")
                .font(RithamType.body)
                .foregroundStyle(RithamColor.paper)
        } else {
            VStack(alignment: .leading, spacing: RithamSpacing.sm) {
                ForEach(model.matches, id: \.id) { session in
                    HStack {
                        Text(session.startedAt.formatted(date: .abbreviated, time: .omitted))
                        Spacer()
                        Text(formattedPace(session))
                    }
                    .font(RithamType.body)
                    .modifier(RithamType.numerals())
                    .foregroundStyle(RithamColor.paper)
                }
            }
        }
    }

    private func formattedPace(_ session: CardioSession) -> String {
        guard session.progress.distanceMeters > 0 else { return "--" }
        let secondsPerKm = session.progress.continuousDuration / (session.progress.distanceMeters / 1000)
        let totalSeconds = max(0, Int(secondsPerKm))
        return String(format: "%d:%02d / km", totalSeconds / 60, totalSeconds % 60)
    }
}
