import SwiftUI
import RithamCore

// EXPLAIN-01: the register lives in the environment, injected once at the root from the value
// stored on `UserProfile`, so changing it in Settings updates every definition in the app at
// once with no screen holding its own copy. No view anywhere may store a register in local
// `@State`, and nothing may derive one from age, tier, or any other profile attribute --
// EXPLAIN-01 states the register is user-selected and never inferred, and register selection is
// a completely independent axis from MINOR-01's 13+ eligibility floor. Deriving one from age
// would reintroduce exactly the age-based fork CROSSGEN-05 forbids.

private struct ExplanationRegisterKey: EnvironmentKey {
    static let defaultValue: ExplanationRegister = .plainLanguage
}

extension EnvironmentValues {
    /// The user's chosen explanation register (EXPLAIN-01), read by `GlossaryTerm` and any
    /// other view rendering register-dependent copy. Defaults to `.plainLanguage` only for
    /// contexts that never called `.explanationRegister(_:)` (e.g. a preview) -- the app's real
    /// root always injects the value loaded from `UserProfile`.
    var explanationRegister: ExplanationRegister {
        get { self[ExplanationRegisterKey.self] }
        set { self[ExplanationRegisterKey.self] = newValue }
    }
}

extension View {
    /// Injects `register` into the environment for this view and everything beneath it. Called
    /// once at the app root with the register loaded from `UserProfile`.
    func explanationRegister(_ register: ExplanationRegister) -> some View {
        environment(\.explanationRegister, register)
    }
}
