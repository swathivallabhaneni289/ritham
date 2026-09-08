import Foundation
import SwiftUI
import Testing
import RithamCore
@testable import Ritham

// Plan 04-03's structural gate: converts three of Phase 4 round 1's most important properties --
// the Momentum section's physical file location, the dashboard's inline-not-navigational shape,
// and the diet section's isolation from the screening write path -- from decisions that happen to
// be true today into automated gates that fail tomorrow if someone moves the code back. Follows
// the same per-phase coverage-suite pattern `Phase2CoverageTests`/`Phase3CoverageTests` already
// established.
//
// Nested inside `StepRegistryTouchingSuites` (`StepRegistrySerialization.swift`) because this
// suite resets and re-bootstraps `StepRegistry`'s shared static state, exactly like the other
// registry-touching suites -- it must be ordered relative to them, not only internally.
extension StepRegistryTouchingSuites {

@Suite("Phase4CoverageTests", .serialized)
@MainActor
struct Phase4CoverageTests {

    init() {
        StepRegistry.reset()
        StepBootstrap.registerAllSteps()
    }

    // MARK: - Path resolution helpers

    /// Resolves `RithamApp/Ritham/` relative to this file's own `#filePath`, the same technique
    /// `Phase3CoverageTests` uses: RithamApp/RithamTests/Phase4CoverageTests.swift ->
    /// RithamApp/Ritham.
    private var rithamDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Ritham")
    }

    /// Reads a file under `Ritham/` and drops every line whose trimmed form begins with `//`
    /// (this also strips `///` doc comments, since `"///".hasPrefix("//")` is true) -- the same
    /// comment filter `Phase3CoverageTests.noMomentumSurfaceOffersASharingAffordance` already
    /// uses, so a comment documenting a prohibition never trips the gate it documents. Returns
    /// `nil` when the file does not exist, so callers can fail loudly (`Issue.record`) instead of
    /// passing vacuously on a path mistake.
    private func nonCommentSource(of relativePath: String) throws -> String? {
        let fileURL = rithamDirectory.appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let source = try String(contentsOf: fileURL, encoding: .utf8)
        return source
            .components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    // MARK: - Registry completeness (04-RESEARCH.md Pitfall 4)

    /// Deviation from the plan's literal text: `.home` is not registered directly against
    /// `HomeHubView` -- `OnboardingCompletionRegistration.registerAll()` registers `HomeStepView`
    /// (an `OnboardingStepPresenting` shim whose `makeView(flow:)` constructs `HomeHubView`), the
    /// same indirection `ScreeningCompleteStepView` uses for `.screeningComplete`. Asserting
    /// `registeredPresenterType(for: .home) == HomeHubView.self` as the plan literally specifies
    /// would fail against the real registry shape (a Rule 1 bug in the plan text, not the code).
    /// This test asserts the real registered type, `HomeStepView.self`, and separately proves the
    /// must_haves truth (".home resolves to HomeHubView") by source-scanning `HomeStepView.swift`
    /// for the literal construction `HomeHubView(`.
    @Test("the .home step resolves to a presenter that constructs the dashboard screen")
    func theHomeStepResolvesToTheDashboardScreen() throws {
        let registered = StepRegistry.registeredPresenterType(for: .home)
        #expect(registered != nil, ".home has no registered presenter type")
        #expect(registered == HomeStepView.self, ".home resolved to \(String(describing: registered)), expected HomeStepView")

        guard let source = try nonCommentSource(of: "Onboarding/Steps/HomeStepView.swift") else {
            Issue.record("could not read Onboarding/Steps/HomeStepView.swift to verify it constructs HomeHubView")
            return
        }
        #expect(source.contains("HomeHubView("), "HomeStepView.swift no longer constructs HomeHubView -- .home would resolve to a different screen")
    }

    @Test("the .recommendations step stays registered though nothing pushes to it from the dashboard")
    func theRecommendationsStepStaysRegisteredThoughNothingPushesToIt() {
        // The dashboard embeds the workout plan inline now (D-04); StepRegistry.unregisteredSteps
        // is asserted empty per-case, not per-reachability, so .recommendations must remain
        // registered regardless of whether the running app still calls flow.open(.recommendations)
        // (04-RESEARCH.md Pitfall 4).
        let registered = StepRegistry.registeredPresenterType(for: .recommendations)
        #expect(registered != nil, ".recommendations has no registered presenter type")
        #expect(registered == RecommendationsView.self, ".recommendations resolved to \(String(describing: registered)), expected RecommendationsView")
    }

    @Test("the registry reports no unregistered steps after bootstrap")
    func theRegistryReportsNoUnregisteredStepsAfterBootstrap() {
        #expect(StepRegistry.unregisteredSteps.isEmpty)
    }

    // MARK: - Momentum relocation: non-vacuity proof for 04-RESEARCH.md Pitfall 2

    /// This is the assertion that makes `Phase3CoverageTests.noMomentumSurfaceOffersASharingAffordance`
    /// genuinely cover the dashboard's Momentum rendering: that gate's only non-vacuity guard is
    /// "at least one file scanned", already satisfied by the three pre-existing components in
    /// `Ritham/Momentum/Components/`, so it would stay green even if `MomentumDashboardSection.swift`
    /// were moved to `Ritham/Home/`. This test is the durable replacement for Pitfall 2's
    /// suggested temporary-`ShareLink` manual check.
    @Test("the Momentum dashboard section lives under the Momentum feature directory")
    func theMomentumDashboardSectionLivesUnderTheMomentumFeatureDirectory() {
        let path = rithamDirectory
            .appendingPathComponent("Momentum")
            .appendingPathComponent("Components")
            .appendingPathComponent("MomentumDashboardSection.swift")
            .path
        #expect(FileManager.default.fileExists(atPath: path), "MomentumDashboardSection.swift is not at Ritham/Momentum/Components/ -- Phase3CoverageTests' no-sharing directory walk would silently stop covering it")
    }

    // MARK: - Dashboard shape (CROSSGEN-01 / D-01), all over HomeHubView.swift's comment-filtered source

    private func homeHubViewSource() throws -> String? {
        try nonCommentSource(of: "Home/HomeHubView.swift")
    }

    @Test("the dashboard hosts every section inline")
    func theDashboardHostsEverySectionInline() throws {
        guard let source = try homeHubViewSource() else {
            Issue.record("could not read Ritham/Home/HomeHubView.swift")
            return
        }
        for symbol in ["MomentumDashboardSection", "RecommendationsSectionContent", "DietPlanSectionContent"] {
            #expect(source.contains(symbol), "HomeHubView.swift no longer references \(symbol) -- a section may have been moved behind navigation instead of rendered inline")
        }
    }

    @Test("the dashboard carries no placeholder framing")
    func theDashboardCarriesNoPlaceholderFraming() throws {
        guard let source = try homeHubViewSource() else {
            Issue.record("could not read Ritham/Home/HomeHubView.swift")
            return
        }
        let lowercased = source.lowercased()
        for token in ["interim", "temporary", "placeholder"] {
            #expect(!lowercased.contains(token), "HomeHubView.swift's non-comment source contains '\(token)' -- the dashboard must never describe itself as temporary or a placeholder")
        }
    }

    @Test("the dashboard introduces no List or Form")
    func theDashboardIntroducesNoListOrForm() throws {
        guard let source = try homeHubViewSource() else {
            Issue.record("could not read Ritham/Home/HomeHubView.swift")
            return
        }
        for token in ["List {", "List(", "Form {", "Form("] {
            #expect(!source.contains(token), "HomeHubView.swift contains '\(token)' -- the codebase has zero List/Form usage and 04-RESEARCH.md rules them out here")
        }
    }

    @Test("the dashboard holds no sub-label typography")
    func theDashboardHoldsNoSubLabelTypography() throws {
        guard let source = try homeHubViewSource() else {
            Issue.record("could not read Ritham/Home/HomeHubView.swift")
            return
        }
        for token in [".caption", ".footnote"] {
            #expect(!source.contains(token), "HomeHubView.swift contains '\(token)' -- RithamType.label (16pt) is the hard floor per 04-UI-SPEC.md")
        }
    }

    @Test("the dashboard introduces no second navigation container")
    func theDashboardIntroducesNoSecondNavigationContainer() throws {
        guard let source = try homeHubViewSource() else {
            Issue.record("could not read Ritham/Home/HomeHubView.swift")
            return
        }
        for token in ["NavigationStack", "NavigationView", "ScrollView"] {
            #expect(!source.contains(token), "HomeHubView.swift contains '\(token)' -- CROSSGEN-05 reserves navigation/scroll scaffolding to RithamScreen/OnboardingRootView")
        }
    }

    // MARK: - Safety-control reachability (the regression D-05's narrowing would otherwise permit)

    @Test("the Settings route to the screening question survives")
    func theSettingsRouteToTheScreeningQuestionSurvives() throws {
        // D-05's narrowing (the dashboard embeds only DIET-01-isolated diet controls, never the
        // food-allergy screening checkbox) is only safe while the Settings route to that
        // screening question still exists.
        guard let hubSource = try homeHubViewSource() else {
            Issue.record("could not read Ritham/Home/HomeHubView.swift")
            return
        }
        #expect(hubSource.contains("SettingsView("), "HomeHubView.swift no longer presents SettingsView -- the only surviving route to the food-allergy screening question would be gone")

        guard let settingsSource = try nonCommentSource(of: "Settings/SettingsView.swift") else {
            Issue.record("could not read Ritham/Settings/SettingsView.swift")
            return
        }
        #expect(settingsSource.contains("DietPlanView(flow:"), "SettingsView.swift no longer routes to DietPlanView -- D-05's narrowing depends on this route existing")
    }

    // MARK: - No-sharing coverage extension (closes the other half of Pitfall 2's gap)

    /// `Phase3CoverageTests` walks only `Momentum/` and `MovementSnapshot/`; `Ritham/Home/` has
    /// never been covered even though it has rendered Momentum state since Phase 3. Deliberately
    /// not added to `Phase3CoverageTests.swift` -- that file is Phase 3's, and 04-RESEARCH.md's
    /// assumption A2 prefers not touching it.
    @Test("no Home surface offers a sharing affordance")
    func noHomeSurfaceOffersASharingAffordance() throws {
        let bannedTokens = ["ShareLink", "UIActivityViewController", "UIPasteboard"]
        let homeDirectory = rithamDirectory.appendingPathComponent("Home")

        var scannedFiles: [URL] = []
        if let enumerator = FileManager.default.enumerator(at: homeDirectory, includingPropertiesForKeys: nil) {
            for case let fileURL as URL in enumerator where fileURL.pathExtension == "swift" {
                scannedFiles.append(fileURL)
            }
        }

        #expect(
            scannedFiles.count > 0,
            "expected to scan at least one .swift file under Ritham/Home/, found none -- check directory resolution"
        )

        for fileURL in scannedFiles {
            let source = try String(contentsOf: fileURL, encoding: .utf8)
            let nonCommentSource = source
                .components(separatedBy: .newlines)
                .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
                .joined(separator: "\n")
            for token in bannedTokens {
                #expect(
                    !nonCommentSource.contains(token),
                    "\(fileURL.lastPathComponent) contains a sharing-affordance trigger outside a comment: \(token)"
                )
            }
        }
    }
}

}
