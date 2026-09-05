import CoreLocation
import MapKit
import SwiftUI
import RithamCore

// CARDIO-01's full training history: sensor-verified-vs-manual labelling (ROADMAP Phase 3's
// Momentum feature depends on this distinction being visible from the moment sessions exist),
// a date-range filter, and an explicit empty state. Loads through the store accessors plan 02-08
// added and adds no persistence code of its own.
//
// Route map note (T-02-32's neighbouring disclosure boundary): no per-sample location trail is
// persisted anywhere in this milestone. `CardioProgress` (plan 02-01) and `CardioSessionRecord`
// (plan 02-08) store only aggregate distance/elevation/splits, and `GPSTrackingSession` (plan
// 02-09) discards each `CLLocation` once its accumulator has consumed it -- there is no
// coordinate array to render. `routeMap(for:)` below is real, uses MapKit (the native framework,
// no third-party dependency), and is exercised at every build against an empty sample array
// today; a future plan that persists a coordinate trail only has to change what it is called
// with, not add MapKit to this file. Rendering a fabricated line here instead would be worse than
// showing nothing, per the same "omit rather than fake" rule `CardioSessionView` applies to
// grade-adjusted pace (Task 2, T-02-04).

/// The single-user, opt-in comparison surface `CardioHistoryView` may offer for a given session.
/// A plain value, not a live query -- constructing one commits to nothing and touches no store.
struct RouteComparisonEntryPoint: Identifiable, Equatable {
    let activityType: ActivityType
    let referenceDistanceMeters: Double

    var id: String { "\(activityType.rawValue)-\(Int(referenceDistanceMeters))" }
}

/// Drives `CardioHistoryView`'s behavior at the model level, so `CardioHistoryTests` can assert
/// every behavior in the plan's `<behavior>` list without rendering the view.
@MainActor
@Observable
final class CardioHistoryModel {
    private(set) var sessions: [CardioSession] = []
    private(set) var isRouteComparisonEnabled = false

    private let store: HealthDataStore

    init(store: HealthDataStore) {
        self.store = store
    }

    var isEmpty: Bool { sessions.isEmpty }

    /// Loads every stored session, most recent first, or only those in `range` when given.
    /// Also refreshes `isRouteComparisonEnabled` from the store on every load, so turning the
    /// opt-in off and reloading immediately removes every comparison entry point.
    func load(range: ClosedRange<Date>? = nil) {
        if let range {
            sessions = (try? store.loadCardioSessions(in: range)) ?? []
        } else {
            sessions = (try? store.loadCardioSessions()) ?? []
        }
        isRouteComparisonEnabled = (try? store.loadRouteComparisonOptIn()) ?? false
    }

    /// CARDIO-03's opt-in gate at the model level: with the flag off this returns `nil` for
    /// every session, so the comparison entry point structurally does not exist -- it is never
    /// merely hidden behind a visibility modifier a later edit could drop.
    func comparisonEntryPoint(for session: CardioSession) -> RouteComparisonEntryPoint? {
        guard isRouteComparisonEnabled else { return nil }
        return RouteComparisonEntryPoint(
            activityType: session.activityType,
            referenceDistanceMeters: session.progress.distanceMeters
        )
    }
}

struct CardioHistoryView: View, OnboardingStepPresenting {
    static let step: OnboardingStep = .cardioHistory

    static func makeView(flow: OnboardingFlow) -> AnyView {
        AnyView(CardioHistoryView(flow: flow))
    }

    let flow: OnboardingFlow
    @Environment(\.modelContext) private var modelContext

    @State private var model: CardioHistoryModel?
    @State private var filterStart = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var filterEnd = Date()
    @State private var isFilterActive = false
    @State private var presentedComparison: RouteComparisonEntryPoint?

    var body: some View {
        RithamScreen(surface: DecorativeSurface.flat, headline: "Cardio history") {
            filterControls

            if let model {
                if model.isEmpty {
                    emptyState
                } else {
                    VStack(alignment: .leading, spacing: RithamSpacing.md) {
                        ForEach(model.sessions, id: \.id) { session in
                            sessionRow(session, model: model)
                        }
                    }
                }
            }

            SecondaryCTAButton(title: "Back") {
                flow.goBack()
            }
        }
        .onAppear(perform: load)
        .sheet(item: $presentedComparison) { entry in
            RouteComparisonView(
                activityType: entry.activityType,
                referenceDistanceMeters: entry.referenceDistanceMeters,
                store: HealthDataStore(context: modelContext)
            )
        }
    }

    // MARK: - Filter

    private var filterControls: some View {
        VStack(alignment: .leading, spacing: RithamSpacing.sm) {
            DatePicker("From", selection: $filterStart, displayedComponents: .date)
                .foregroundStyle(RithamColor.paper)
            DatePicker("To", selection: $filterEnd, displayedComponents: .date)
                .foregroundStyle(RithamColor.paper)

            HStack(spacing: RithamSpacing.sm) {
                SecondaryCTAButton(title: "Apply date filter") {
                    isFilterActive = true
                    load()
                }
                SecondaryCTAButton(title: "Clear filter") {
                    isFilterActive = false
                    load()
                }
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: RithamSpacing.sm) {
            Text("No cardio sessions yet")
                .font(RithamType.display)
                .foregroundStyle(RithamColor.paper)
                .fixedSize(horizontal: false, vertical: true)

            Text("Sessions you track will show up here, most recent first.")
                .font(RithamType.body)
                .foregroundStyle(RithamColor.paper)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Session row

    @ViewBuilder
    private func sessionRow(_ session: CardioSession, model: CardioHistoryModel) -> some View {
        VStack(alignment: .leading, spacing: RithamSpacing.xs) {
            HStack {
                Text(session.activityType.displayName)
                    .font(RithamType.body)
                    .foregroundStyle(RithamColor.paper)
                Spacer()
                Text(session.source.isSensorVerified ? "Sensor-verified" : "Manually entered")
                    .font(RithamType.label)
                    .foregroundStyle(RithamColor.paper)
            }

            Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                .font(RithamType.label)
                .foregroundStyle(RithamColor.paper)

            Text("\(formattedDuration(session.progress.continuousDuration)) \u{00b7} \(formattedDistanceKm(session.progress.distanceMeters)) km")
                .font(RithamType.body)
                .modifier(RithamType.numerals())
                .foregroundStyle(RithamColor.paper)

            routeMap(for: [])

            if let entry = model.comparisonEntryPoint(for: session) {
                SecondaryCTAButton(title: "Compare with your other sessions on this route") {
                    presentedComparison = entry
                }
            }
        }
        .padding(RithamSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: RithamSpacing.sm)
                .stroke(RithamColor.paper.opacity(0.3), lineWidth: 1)
        )
    }

    /// Renders `samples` as a MapKit polyline when non-empty. See this file's header comment --
    /// no coordinate trail exists in this milestone, so every call site passes `[]` today, and
    /// the absent-data branch below states that plainly rather than showing an empty or
    /// fabricated map.
    @ViewBuilder
    private func routeMap(for samples: [LocationSample]) -> some View {
        if samples.isEmpty {
            Text("This session recorded distance and elevation, not a location trail.")
                .font(RithamType.label)
                .foregroundStyle(RithamColor.paper)
        } else {
            Map {
                MapPolyline(coordinates: samples.map {
                    CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
                })
                .stroke(RithamColor.hot, lineWidth: 3)
            }
            .frame(height: 180)
            .clipShape(RoundedRectangle(cornerRadius: RithamSpacing.sm))
        }
    }

    // MARK: - Loading / formatting

    private func load() {
        let store = HealthDataStore(context: modelContext)
        let currentModel = model ?? CardioHistoryModel(store: store)
        currentModel.load(range: isFilterActive ? filterStart...filterEnd : nil)
        model = currentModel
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = max(0, Int(duration))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func formattedDistanceKm(_ meters: Double) -> String {
        String(format: "%.2f", meters / 1000)
    }
}
