import Foundation
import SwiftUI
import Testing
import RithamCore
@testable import Ritham

// Plan 04.2-05's structural gate: converts Phase 04.2's locked decisions -- the Settings-only
// entry point (D-04), the one combined screen (D-05), the browsable-not-shown-once framing
// (D-08), the read-only no-saved-state rule (D-09), and the verbatim citation discipline (D-01)
// -- from things that happen to be true today into automated gates that fail tomorrow if someone
// changes them back. Follows the same per-phase coverage-suite pattern
// `Phase3CoverageTests`/`Phase4CoverageTests` already established.
//
// Nested inside `StepRegistryTouchingSuites` (`StepRegistrySerialization.swift`), NOT inside
// `MomentumContainerTouchingSuites` where this phase's other two new suites
// (`ChildEntryTests`/`KidIdeasTests`) live: this suite touches `StepRegistry`'s shared static
// state (gate 1 asserts `unregisteredSteps.isEmpty`), so it must be ordered relative to the other
// registry-touching suites, not the container-creating ones. A Swift Testing suite cannot nest
// under two parents at once, and this file creates no in-memory SwiftData container at all -- every gate below
// is a pure source scan or a static catalog read, so it never needed one.
extension StepRegistryTouchingSuites {

@Suite("Phase42CoverageTests", .serialized)
@MainActor
struct Phase42CoverageTests {

    init() {
        StepRegistry.reset()
        StepBootstrap.registerAllSteps()
    }

    // MARK: - Path resolution helpers

    /// Resolves `RithamApp/Ritham/` relative to this file's own `#filePath`, the same technique
    /// `Phase4CoverageTests` uses: RithamApp/RithamTests/Phase42CoverageTests.swift ->
    /// RithamApp/Ritham.
    private var rithamDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Ritham")
    }

    /// Reads a file under `Ritham/` and drops every line whose trimmed form begins with `//`
    /// (this also strips `///` doc comments, since `"///".hasPrefix("//")` is true) -- the same
    /// comment filter `Phase4CoverageTests.nonCommentSource(of:)` already uses, so a comment
    /// documenting a prohibition never trips the gate it documents. Returns `nil` when the file
    /// does not exist, so callers can fail loudly (`Issue.record`) instead of passing vacuously
    /// on a path mistake.
    private func nonCommentSource(of relativePath: String) throws -> String? {
        let fileURL = rithamDirectory.appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let source = try String(contentsOf: fileURL, encoding: .utf8)
        return source
            .components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// Every `.swift` file under `relativePath` (resolved relative to `rithamDirectory`), for the
    /// two directory walks below (Onboarding/ and Persistence/). Mirrors
    /// `Phase3CoverageTests.noMomentumSurfaceOffersASharingAffordance`'s directory-walk technique.
    private func swiftFiles(under relativePath: String) -> [URL] {
        let directory = rithamDirectory.appendingPathComponent(relativePath)
        var files: [URL] = []
        if let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil) {
            for case let fileURL as URL in enumerator where fileURL.pathExtension == "swift" {
                files.append(fileURL)
            }
        }
        return files
    }

    // MARK: - Gate 1: registry completeness

    @Test("the registry reports no unregistered steps after bootstrap")
    func theRegistryReportsNoUnregisteredStepsAfterBootstrap() {
        #expect(StepRegistry.unregisteredSteps.isEmpty)
    }

    // MARK: - Gate 2: the screen is not an onboarding step (D-04)

    @Test("KidIdeasView is not an onboarding step")
    func kidIdeasViewIsNotAnOnboardingStep() throws {
        guard let source = try nonCommentSource(of: "Settings/KidIdeasView.swift") else {
            Issue.record("could not read Ritham/Settings/KidIdeasView.swift")
            return
        }
        for token in ["OnboardingStepPresenting", "static let step", "OnboardingFlow"] {
            #expect(
                !source.contains(token),
                "KidIdeasView.swift contains '\(token)' -- D-04 requires this screen be reached only from Settings, never registered as an onboarding step. Unlike PrivacyZonesView (registered but not routed from onboarding), no OnboardingStep case exists for kid content, so that precedent does NOT apply here -- this screen must never conform to OnboardingStepPresenting at all."
            )
        }
    }

    // MARK: - Gate 3: the one route exists -- blocking reachability gate

    @Test("SettingsView still constructs KidIdeasView")
    func settingsViewStillConstructsKidIdeasView() throws {
        guard let source = try nonCommentSource(of: "Settings/SettingsView.swift") else {
            Issue.record("could not read Ritham/Settings/SettingsView.swift")
            return
        }
        #expect(
            source.contains("KidIdeasView("),
            "SettingsView.swift no longer constructs KidIdeasView -- the only route to the Kid Ideas screen is gone and the screen is now unreachable dead code. Plan 04.1-14 shipped exactly this failure mode (a screen registered but reachable from nothing), discovered only at phase close; this gate exists to prevent repeating it."
        )
    }

    // MARK: - Gate 4: the dashboard never mentions this feature (D-04, Pitfall 1)

    @Test("HomeHubView never mentions kid content")
    func homeHubViewNeverMentionsKidContent() throws {
        guard let source = try nonCommentSource(of: "Home/HomeHubView.swift") else {
            Issue.record("could not read Ritham/Home/HomeHubView.swift")
            return
        }
        for symbol in ["KidIdeasView", "KidContentCatalog", "KidContentCopy", "ChildEntryStore", "ChildEntryRecord"] {
            #expect(
                !source.contains(symbol),
                "HomeHubView.swift references \(symbol) -- D-04 and 04.2-RESEARCH.md Pitfall 1 both require this feature stay off the dashboard: not every user has a child, which is the entire reason this is not a dashboard section."
            )
        }
    }

    // MARK: - Gate 5: onboarding never mentions this feature

    @Test("no Onboarding surface mentions kid content")
    func noOnboardingSurfaceMentionsKidContent() throws {
        let bannedTokens = ["KidIdeasView", "KidContentCatalog", "ChildEntryRecord"]
        let scannedFiles = swiftFiles(under: "Onboarding")

        #expect(
            scannedFiles.count > 0,
            "expected to scan at least one .swift file under Ritham/Onboarding/, found none -- check directory resolution"
        )

        for fileURL in scannedFiles {
            let source = try String(contentsOf: fileURL, encoding: .utf8)
            let filtered = source
                .components(separatedBy: .newlines)
                .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
                .joined(separator: "\n")
            for token in bannedTokens {
                #expect(
                    !filtered.contains(token),
                    "\(fileURL.lastPathComponent) contains '\(token)' -- no onboarding surface may reference kid content (D-04)"
                )
            }
        }
    }

    // MARK: - Gate 6: no per-idea state (D-09)

    /// The first two tokens (`favorite`/`favourite`) are checked against KidIdeasView's own
    /// source only, deliberately NOT against `KidContentCatalog`: two shipped USDA tips
    /// legitimately contain that word in their own published text ("Choose your favorites" /
    /// "Let kids choose their own favorites"), and this catalog's verbatim-citation discipline
    /// (D-01) forbids editing that source text to dodge this gate.
    @Test("KidIdeasView persists no per-idea state")
    func kidIdeasViewPersistsNoPerIdeaState() throws {
        guard let source = try nonCommentSource(of: "Settings/KidIdeasView.swift") else {
            Issue.record("could not read Ritham/Settings/KidIdeasView.swift")
            return
        }
        let bannedTokens = [
            "favorite", "favourite", "bookmark", "isTried", "markTried",
            "viewedIdea", "seenIdea", "@Model", "FetchDescriptor<",
        ]
        let lowercased = source.lowercased()
        for token in bannedTokens {
            #expect(
                !lowercased.contains(token.lowercased()),
                "KidIdeasView.swift contains '\(token)' -- D-09 forbids anything that could read as a log of what a specific child ate or did."
            )
        }
    }

    // MARK: - Gate 7: no persisted content-interaction type

    @Test("no Persistence type declares a kid-content-interaction name")
    func noPersistenceTypeDeclaresAKidContentInteractionName() throws {
        let bannedTokens = ["Idea", "KidContent", "Favorite", "Favourite", "Viewed"]
        let scannedFiles = swiftFiles(under: "Persistence")

        #expect(
            scannedFiles.count >= 10,
            "expected to scan at least ten .swift files under Ritham/Persistence/, found \(scannedFiles.count) -- check directory resolution"
        )

        for fileURL in scannedFiles {
            let source = try String(contentsOf: fileURL, encoding: .utf8)
            let filtered = source
                .components(separatedBy: .newlines)
                .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
                .joined(separator: "\n")
            for token in bannedTokens {
                #expect(
                    !filtered.contains(token),
                    "\(fileURL.lastPathComponent) contains '\(token)' -- no persisted type anywhere may record which ideas were viewed, tried, or liked (D-09)."
                )
            }
        }
    }

    // MARK: - Gate 8: screening isolation

    @Test("KidIdeasView and ChildEntryStore never touch the screening/clearance path")
    func kidIdeasViewAndChildEntryStoreNeverTouchTheScreeningPath() throws {
        let bannedTokens = ["contentPermission", "ConditionTag", "GateResolution", "saveScreeningResult", "TagDerivation"]

        for relativePath in ["Settings/KidIdeasView.swift", "Settings/ChildEntryStore.swift"] {
            guard let source = try nonCommentSource(of: relativePath) else {
                Issue.record("could not read Ritham/\(relativePath)")
                continue
            }
            for token in bannedTokens {
                #expect(
                    !source.contains(token),
                    "\(relativePath) contains '\(token)' -- a child entry must never influence the user's own clearance gate, and this content carries no condition-tag dimension (04.2-RESEARCH.md Pitfall 4)."
                )
            }
        }
    }

    // MARK: - Gate 9: no sharing affordance

    @Test("KidIdeasView offers no sharing affordance")
    func kidIdeasViewOffersNoSharingAffordance() throws {
        guard let source = try nonCommentSource(of: "Settings/KidIdeasView.swift") else {
            Issue.record("could not read Ritham/Settings/KidIdeasView.swift")
            return
        }
        for token in ["ShareLink", "UIActivityViewController", "UIPasteboard"] {
            #expect(
                !source.contains(token),
                "KidIdeasView.swift contains '\(token)' -- pediatric content and a child entry are exactly the data this project's privacy posture keeps unshareable, extending the same structural discipline Phase3CoverageTests/Phase4CoverageTests already apply to their own directories."
            )
        }
    }

    // MARK: - Gate 10: content reachability -- non-vacuity anchor

    @Test("the structural gates above cannot pass on an empty feature")
    func theStructuralGatesCannotPassOnAnEmptyFeature() {
        #expect(KidContentCatalog.ideas.count == 27)
        #expect(KidContentCopy.Screen.headline == SettingsView.kidIdeasRowTitle)
    }
}

}
