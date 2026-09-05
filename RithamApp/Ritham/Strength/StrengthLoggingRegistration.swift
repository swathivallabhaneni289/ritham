import SwiftUI
import RithamCore

// Plan 02-11 replaces this file's placeholder with the real strength-session screen. This file
// stays the sole owner of the strength-logging registration for the rest of the phase -- a future
// change registers `StrengthSessionView` here, never by adding a second registrar file.
@MainActor
enum StrengthLoggingRegistration {
    static func registerAll() {
        StepRegistry.register(StrengthSessionView.self)
    }
}
