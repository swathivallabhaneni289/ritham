import Foundation
import SwiftUI
import Testing
import RithamCore
@testable import Ritham

// Plan 03-10's Phase 3 completeness gate, the direct analogue of plan 02-16's
// `Phase2CoverageTests`. Registration coverage (the `unregisteredSteps`-is-empty check that
// `PhaseCoverageTests` already asserts) only proves a step resolves to *something* -- it cannot
// tell a placeholder apart from the real screen. This suite proves each of Phase 3's three new
// steps (`.momentum`, `.sleepCheckIn`, `.movementSnapshot`) resolves to the exact concrete
// presenter type its owning plan created, and separately proves the structural half of
// MOMENTUM-06's private-by-default requirement: no share-sheet or pasteboard-write trigger
// exists anywhere under the Momentum or MovementSnapshot feature directories.
//
// Nested inside `StepRegistryTouchingSuites` (`StepRegistrySerialization.swift`) because this
// suite resets and re-bootstraps `StepRegistry`'s shared static state, exactly like the other
// registry-touching suites -- it must be ordered relative to them, not only internally.
extension StepRegistryTouchingSuites {

@Suite("Phase3CoverageTests", .serialized)
@MainActor
struct Phase3CoverageTests {

    init() {
        StepRegistry.reset()
        StepBootstrap.registerAllSteps()
    }

    /// Phase 3's three new surfaces (`OnboardingStep.swift`'s header comment: "momentum,
    /// sleepCheckIn, movementSnapshot") paired with the real screen type its owning plan
    /// created (`MomentumRegistration`/`Phase3StepRegistration`/`MovementSnapshotRegistration`).
    private static let phase3StepsToRealTypes: [(step: OnboardingStep, type: Any.Type)] = [
        (.momentum, MomentumView.self),
        (.sleepCheckIn, SleepCheckInView.self),
        (.movementSnapshot, MovementSnapshotView.self),
    ]

    // MARK: - Each of the three Phase 3 steps resolves to its real screen

    @Test("each of the three Phase 3 steps resolves to a presenter whose type is the real screen its owning plan created")
    func eachPhase3StepResolvesToItsRealScreenType() {
        for entry in Self.phase3StepsToRealTypes {
            let registered = StepRegistry.registeredPresenterType(for: entry.step)
            #expect(registered != nil, "\(entry.step) has no registered presenter type")
            #expect(registered == entry.type, "\(entry.step) resolved to \(String(describing: registered)), expected \(entry.type)")
        }
    }

    // MARK: - No resolved presenter is a placeholder type

    @Test("no Phase 3 step resolves to a placeholder presenter type")
    func noPhase3StepResolvesToAPlaceholderType() {
        for entry in Self.phase3StepsToRealTypes {
            let registered = StepRegistry.registeredPresenterType(for: entry.step)
            let typeName = String(describing: registered)
            #expect(!typeName.contains("Placeholder"), "\(entry.step) resolved to \(typeName), which looks like a placeholder type")
        }
    }

    // MARK: - Every Phase 3 step also resolves without trapping, through the real registered factory

    @Test("every Phase 3 step's view(for:flow:) call resolves without trapping")
    func everyPhase3StepResolvesWithoutTrapping() {
        let flow = OnboardingFlow()
        for entry in Self.phase3StepsToRealTypes {
            _ = StepRegistry.view(for: entry.step, flow: flow)
        }
        #expect(true)
    }

    // MARK: - The registry reports no unregistered steps after bootstrap

    @Test("the registry reports no unregistered steps after bootstrap")
    func registryReportsNoUnregisteredSteps() {
        #expect(StepRegistry.unregisteredSteps.isEmpty)
    }

    // MARK: - MOMENTUM-06 structural no-sharing gate (T-3-03)

    /// Technique: reads every `.swift` file found by walking the Momentum and MovementSnapshot
    /// feature directories on disk, resolved relative to this test file's own `#filePath` --
    /// the same "read the real source, relative to this file" technique
    /// `RecoveryAdjustmentTests.theSleepScreenMentionsNoMomentumState` and
    /// `MomentumViewTests.noMomentumControlUsesTheDestructiveColor` already established, extended
    /// here from a single named file to a directory walk since this gate must cover both feature
    /// directories in full, not one file at a time. A checked-in file-name list was the other
    /// option the plan allowed; the directory walk was chosen so a future file added to either
    /// directory is covered automatically, with no list to remember to update.
    ///
    /// Filters out full-line comments before matching (a `//` line documenting this prohibition,
    /// such as this suite's own header, must never trip the gate it documents), and asserts the
    /// scanned-file count is greater than zero so this test cannot pass vacuously if directory
    /// resolution ever silently found nothing.
    @Test("noMomentumSurfaceOffersASharingAffordance")
    func noMomentumSurfaceOffersASharingAffordance() throws {
        let bannedTokens = ["ShareLink", "UIActivityViewController", "UIPasteboard"]

        let thisFile = URL(fileURLWithPath: #filePath)
        // RithamApp/RithamTests/Phase3CoverageTests.swift ->
        // RithamApp/Ritham/{Momentum,MovementSnapshot}
        let rithamDirectory = thisFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Ritham")
        let featureDirectories = ["Momentum", "MovementSnapshot"]
            .map { rithamDirectory.appendingPathComponent($0) }

        var scannedFiles: [URL] = []
        for directory in featureDirectories {
            guard let enumerator = FileManager.default.enumerator(
                at: directory,
                includingPropertiesForKeys: nil
            ) else {
                continue
            }
            for case let fileURL as URL in enumerator where fileURL.pathExtension == "swift" {
                scannedFiles.append(fileURL)
            }
        }

        // Non-vacuous-pass guard: if directory resolution above silently found zero files (a
        // path miscalculation, a renamed directory), every assertion below would trivially pass
        // without ever having scanned anything real.
        #expect(
            scannedFiles.count > 0,
            "expected to scan at least one .swift file under Momentum/ and MovementSnapshot/, found none -- check directory resolution"
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
