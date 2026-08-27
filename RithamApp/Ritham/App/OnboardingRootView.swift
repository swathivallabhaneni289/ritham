import SwiftUI
import SwiftData
import RithamCore

// CROSSGEN-05: there is exactly one navigation container for the whole app, for every user
// regardless of age. This file is the only place that may declare a navigation stack or a
// destination resolver for `OnboardingStep` — age never selects a different root, and no screen
// may wrap itself in its own container. Reaching a step through this container is the UI-level
// expression of being permitted to use whatever that step unlocks (see this plan's threat model).
struct OnboardingRootView: View {
    @State private var flow = OnboardingFlow()
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack(path: $flow.path) {
            StepRegistry.view(for: .welcome, flow: flow)
                .navigationDestination(for: OnboardingStep.self) { step in
                    StepRegistry.view(for: step, flow: flow)
                }
        }
        .explanationRegister(currentRegister)
    }

    // EXPLAIN-01: injected once here, at the root, per `RegisterEnvironment.swift`'s own
    // contract -- never derived locally by any screen. Plan 01-12 built the environment key and
    // left this call site to whichever plan owns the root view's next edit (01-13, per the wave
    // sequence); this is that edit, added here rather than in `RithamApp.swift` since the header
    // comment there reserves its three edits for 01-09/01-11/01-18 specifically.
    //
    // Reads `flow.answers.register` first -- set the moment the user picks, even before a
    // profile exists to persist it to (see `ExplanationRegisterStepView`'s deferred-persist doc
    // comment) -- so the environment updates live the instant a selection is made, since `flow`
    // is `@Observable` and this computed property is read from `body`. Falls back to the stored
    // profile's value for a resumed app launch where nothing has been chosen yet this session,
    // and finally to the environment key's own `.plainLanguage` default.
    private var currentRegister: ExplanationRegister {
        if let inFlight = flow.answers.register {
            return inFlight
        }
        let store = HealthDataStore(context: modelContext)
        return (try? store.loadProfile())?.explanationRegister ?? .plainLanguage
    }
}
