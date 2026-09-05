import SwiftUI
import RithamCore

/// HEALTH-03/HEALTH-04's dedicated guidance screen, reachable from the hub -- the second of the
/// two surfaces this plan builds, alongside the inline banners plan 02-12's Task 2 embedded
/// directly into the two session-logging screens. Composes a workout section from
/// `AdjustedGuidanceBanner` and a nutrition section from `NutritionGuidanceSection`, both reading
/// the same `GuidanceContext` so the two sections never disagree about which tags apply.
struct GuidanceView: View, OnboardingStepPresenting {
    static let step: OnboardingStep = .guidance

    static func makeView(flow: OnboardingFlow) -> AnyView {
        AnyView(GuidanceView())
    }

    @Environment(\.modelContext) private var modelContext
    @State private var context: GuidanceContext?

    var body: some View {
        RithamScreen(surface: DecorativeSurface.flat, headline: "Guidance") {
            if let context {
                VStack(alignment: .leading, spacing: RithamSpacing.xl) {
                    workoutSection(context)
                    NutritionGuidanceSection(context: context)
                }
            }
        }
        .onAppear(perform: setup)
    }

    private func workoutSection(_ context: GuidanceContext) -> some View {
        VStack(alignment: .leading, spacing: RithamSpacing.sm) {
            Text("Workout")
                .font(RithamType.heading)
                .foregroundStyle(RithamColor.paper)

            AdjustedGuidanceBanner(context: context, domain: .workout)
        }
    }

    private func setup() {
        guard context == nil else { return }
        context = GuidanceContext(context: modelContext)
    }
}
