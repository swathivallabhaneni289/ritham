import Foundation

// The single aggregate registrar for every Phase 2 feature area, calling each area's own
// registrar exactly once. `StepBootstrap` calls only this file -- the same single-call-site
// pattern Phase 1 established (see `StepBootstrap.swift`'s own header comment) so five parallel
// feature plans (02-10 through 02-13, 02-15) each rewrite their own registrar file in place
// without ever touching `StepBootstrap` or each other's files.
@MainActor
enum Phase2StepRegistration {
    static func registerAll() {
        CardioRegistration.registerAll()
        StrengthLoggingRegistration.registerAll()
        StrengthHistoryRegistration.registerAll()
        GuidanceRegistration.registerAll()
        RecommendationsRegistration.registerAll()
    }
}
