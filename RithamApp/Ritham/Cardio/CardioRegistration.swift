import SwiftUI
import RithamCore

// The real cardio registrar (rewritten in place, replacing plan 02-06's three placeholder
// presenters). `CardioActivityPickerView` is fully built by this task; `CardioSessionView` and
// `CardioHistoryView` already exist as real (not "Placeholder"-named) presenters registered here,
// and this same plan's later tasks rewrite each of those two files in full -- Task 2 for
// `CardioSessionView`, Task 3 for `CardioHistoryView` -- without ever touching this file again.
@MainActor
enum CardioRegistration {
    static func registerAll() {
        StepRegistry.register(CardioActivityPickerView.self)
        StepRegistry.register(CardioSessionView.self)
        StepRegistry.register(CardioHistoryView.self)
    }
}
