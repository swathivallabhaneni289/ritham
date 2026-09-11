import Foundation
import SwiftUI
import Testing
import RithamCore
@testable import Ritham

// Plan 04.1-17's phase-wide completeness gate for Phase 4.1, the direct analogue of
// Phase2CoverageTests/Phase3CoverageTests/Phase4CoverageTests. This phase's correctness is mostly
// negative -- a long list of things that must not exist -- and sixteen prior plans each asserted
// their own share of that list locally. This suite adds the gates that span the whole phase and
// would catch a regression introduced anywhere in it.
//
// One lesson from Phase4CoverageTests shapes every walk below: a directory walk guarded only by
// "at least one file was scanned" stayed green after the code it was meant to cover moved
// somewhere else, which is why every source-scanning test here asserts a real floor on what it
// covered (at least 25 files across the client's whole `Social/` directory, which holds 54 as of
// this plan) and records how many it actually scanned.
//
// Nested inside `StepRegistryTouchingSuites` (`StepRegistrySerialization.swift`) because this
// suite resets and re-bootstraps `StepRegistry`'s shared static state, exactly like the other
// registry-touching suites -- it must be ordered relative to them, not only internally. Run this
// suite with `-only-testing:RithamTests/StepRegistryTouchingSuites/SocialCoverageTests`, never the
// bare `-only-testing:RithamTests/SocialCoverageTests` -- the bare form matches zero tests once
// this suite is nested and exits 0, a silent false pass (04.1-07-SUMMARY.md's own documented
// precedent for this exact hazard, also called out by `CertificateTests.swift`'s header comment).
extension StepRegistryTouchingSuites {

@Suite("SocialCoverageTests", .serialized)
@MainActor
struct SocialCoverageTests {

    init() {
        StepRegistry.reset()
        StepBootstrap.registerAllSteps()
    }

    // MARK: - Path resolution and source-reading helpers (Phase4CoverageTests' own technique)

    /// Resolves `RithamApp/Ritham/` relative to this file's own `#filePath`:
    /// RithamApp/RithamTests/SocialCoverageTests.swift -> RithamApp/Ritham.
    private var rithamDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Ritham")
    }

    private var socialDirectory: URL {
        rithamDirectory.appendingPathComponent("Social")
    }

    /// Reads a file under `Ritham/` and drops every line whose trimmed form begins with `//` (this
    /// also strips `///` doc comments, since `"///".hasPrefix("//")` is true) -- the same comment
    /// filter `Phase3CoverageTests`/`Phase4CoverageTests` already use, so a comment documenting a
    /// prohibition never trips the gate documenting it. Returns `nil` when the file does not
    /// exist, so callers can fail loudly (`Issue.record`) instead of passing vacuously on a path
    /// mistake.
    private func nonCommentSource(of relativePath: String) throws -> String? {
        let fileURL = rithamDirectory.appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let source = try String(contentsOf: fileURL, encoding: .utf8)
        return source
            .components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// Every `.swift` file under `Ritham/Social/`, walked recursively. Non-vacuity is asserted by
    /// each caller against `minScannedSocialFiles`, not here, so every source-scanning test records
    /// and asserts its own count (per this plan's own acceptance criteria) rather than sharing one
    /// assertion a future refactor could silently drop.
    private func allSocialSwiftFiles() -> [URL] {
        var files: [URL] = []
        if let enumerator = FileManager.default.enumerator(at: socialDirectory, includingPropertiesForKeys: nil) {
            for case let fileURL as URL in enumerator where fileURL.pathExtension == "swift" {
                files.append(fileURL)
            }
        }
        return files
    }

    private func nonCommentSource(ofAbsolute fileURL: URL) throws -> String {
        let source = try String(contentsOf: fileURL, encoding: .utf8)
        return source
            .components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// The real floor every source-scanning test below asserts against. `Ritham/Social/` holds 54
    /// `.swift` files across 8 subdirectories as of this plan -- stated here well below that actual
    /// count so a real path mistake (not ordinary future growth) is what trips it.
    private static let minScannedSocialFiles = 25

    // MARK: - Registry completeness: every Phase 4.1 step resolves to its real registered screen

    /// Phase 4.1's thirteen new surfaces (`OnboardingStep.swift`'s own header comment enumerates
    /// them) paired with the real screen type its owning plan registered
    /// (`SocialStepRegistration.registerAll()` and the eight per-area registrars it calls).
    private static let phase41StepsToRealTypes: [(step: OnboardingStep, type: Any.Type)] = [
        (.signInWithApple, SignInWithAppleView.self),
        (.privacyZones, PrivacyZonesView.self),
        (.friendsList, FriendsListView.self),
        (.addFriend, AddFriendView.self),
        (.groupList, GroupListView.self),
        (.groupDetail, GroupDetailView.self),
        (.createGoalEvent, CreateGoalEventView.self),
        (.goalEventRSVP, GoalEventRSVPView.self),
        (.completionLogging, CompletionLoggingView.self),
        (.groupFeed, GroupFeedView.self),
        (.groupHistory, GroupHistoryView.self),
        (.certificate, CertificateRevealView.self),
        (.certificateArchive, CertificateArchiveView.self),
    ]

    @Test("everySocialStepResolvesToARegisteredScreen")
    func everySocialStepResolvesToARegisteredScreen() {
        for entry in Self.phase41StepsToRealTypes {
            let registered = StepRegistry.registeredPresenterType(for: entry.step)
            #expect(registered != nil, "\(entry.step) has no registered presenter type")
            #expect(registered == entry.type, "\(entry.step) resolved to \(String(describing: registered)), expected \(entry.type)")
        }
        // Registry completeness half of Task 1's action text: the registry reports no
        // unregistered steps at all after bootstrap, not just for this phase's own thirteen.
        #expect(StepRegistry.unregisteredSteps.isEmpty)
    }

    // MARK: - Feature-area completeness: the durable, non-vacuous replacement for a bare file count

    /// Deviation from the plan's literal text (Rule 1, matching `Phase4CoverageTests`' own header
    /// comment precedent for handling exactly this kind of plan-text/reality mismatch): the plan
    /// states "at least nine subdirectories." `Ritham/Social/` has exactly **eight** real
    /// subdirectories on disk -- `Certificate`, `Completion`, `Feed`, `Friends`, `GoalEvents`,
    /// `Groups`, `Identity`, `PrivacyZones` -- verified directly before writing this test.
    /// `RithamCore/Sources/RithamCore/Social/` is a different module, is flat (no subdirectories of
    /// its own), and is not a candidate for a ninth entry here. This test asserts the real eight by
    /// name, which is a stronger, more durable floor than any count claim: a future rename or
    /// relocation of any one of them fails this test by name, not just by a number silently
    /// drifting.
    @Test("theSocialDirectoryContainsEveryExpectedFeatureArea")
    func theSocialDirectoryContainsEveryExpectedFeatureArea() {
        let expectedSubdirectories = [
            "Certificate", "Completion", "Feed", "Friends",
            "GoalEvents", "Groups", "Identity", "PrivacyZones",
        ]
        for name in expectedSubdirectories {
            var isDirectory: ObjCBool = false
            let path = socialDirectory.appendingPathComponent(name).path
            let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
            #expect(exists && isDirectory.boolValue, "expected Social feature directory '\(name)' to exist, found none -- Phase4CoverageTests' own lesson is that a bare count check would stay green after this relocates")
        }

        let scannedFiles = allSocialSwiftFiles()
        #expect(scannedFiles.count >= Self.minScannedSocialFiles, "scanned \(scannedFiles.count) files under Ritham/Social/, want at least \(Self.minScannedSocialFiles) -- check directory resolution")
    }

    // MARK: - No ranking or counting field

    /// Word-boundary, case-insensitive identifiers this codebase's structural convention already
    /// forbids for any ranking/contest-shaped surface (`internal/events/noranking_test.go`'s Go
    /// side precedent uses an equivalent list). Deliberately **omits** bare "position": this
    /// client's `Ritham/Social/PrivacyZones/AddPrivacyZoneView.swift` legitimately calls
    /// `Map(position: $cameraPosition)`, MapKit's own camera-position API, which has nothing to do
    /// with a ranking position and would be a false positive under a bare `position` ban -- an
    /// asymmetry from the Go-side gate worth stating explicitly, matching
    /// `internal/feed/nodenominator_test.go`'s own precedent for documenting exactly this kind of
    /// exclusion rather than leaving it silent.
    private static let rankingWordPattern = try! NSRegularExpression(
        pattern: "(?i)\\b(rank|score|leaderboard|winner|kudos|ordinal|contest)\\b"
    )

    /// Matches a collection's size formatted directly into a string-interpolation segment (e.g.
    /// `"\(items.count)"`), the concrete form "any formatting of a collection's size into a
    /// rendered string" would take in this codebase's convention.
    private static let countInterpolationPattern = try! NSRegularExpression(
        pattern: "\\\\\\([^)]*\\.count[^)]*\\)"
    )

    private func matches(_ pattern: NSRegularExpression, in text: String) -> [String] {
        let range = NSRange(text.startIndex..., in: text)
        return pattern.matches(in: text, range: range).compactMap {
            Range($0.range, in: text).map { String(text[$0]) }
        }
    }

    @Test("noSocialSurfaceCarriesARankingOrCountingField")
    func noSocialSurfaceCarriesARankingOrCountingField() throws {
        let scannedFiles = allSocialSwiftFiles()
        #expect(scannedFiles.count >= Self.minScannedSocialFiles, "scanned \(scannedFiles.count) files under Ritham/Social/, want at least \(Self.minScannedSocialFiles)")

        for fileURL in scannedFiles {
            let source = try nonCommentSource(ofAbsolute: fileURL)
            let rankingHits = matches(Self.rankingWordPattern, in: source)
            #expect(rankingHits.isEmpty, "\(fileURL.lastPathComponent) contains a ranking/contest-shaped word outside a comment: \(rankingHits)")
            let countHits = matches(Self.countInterpolationPattern, in: source)
            #expect(countHits.isEmpty, "\(fileURL.lastPathComponent) formats a collection's size directly into a string interpolation: \(countHits)")
        }
    }

    // MARK: - No denominator beside a completion count

    /// The concrete, prohibited juxtaposition: a file that renders completions (identified here by
    /// referencing the `Completion`-named surface at all, matching the plan's own "a file rendering
    /// completions" phrasing) must never also reference the RSVP step or a headcount property --
    /// the pre-event RSVP screen's headcount and a completion's own rendering are structurally kept
    /// apart everywhere in this phase (`GoalEventRSVPView.swift`'s own header comment: "never
    /// reachable from, referenced by, or navigable to from anything that shows completions").
    @Test("noSocialSurfacePairsACompletionCountWithADenominator")
    func noSocialSurfacePairsACompletionCountWithADenominator() throws {
        let scannedFiles = allSocialSwiftFiles()
        #expect(scannedFiles.count >= Self.minScannedSocialFiles, "scanned \(scannedFiles.count) files under Ritham/Social/, want at least \(Self.minScannedSocialFiles)")

        let deniedTokens = [".goalEventRSVP", "rsvpCount", "RSVPState"]
        for fileURL in scannedFiles {
            let source = try nonCommentSource(ofAbsolute: fileURL)
            guard source.contains("Completion") else { continue }
            for token in deniedTokens {
                #expect(!source.contains(token), "\(fileURL.lastPathComponent) renders completions and also references '\(token)' -- the RSVP headcount must never appear beside a completion")
            }
            #expect(!source.lowercased().contains("headcount"), "\(fileURL.lastPathComponent) renders completions and also references a headcount")
        }
    }

    // MARK: - Certificate photo restriction: source-level companion to plan 04.1-16's type check

    /// `CertificateTests.swift` (plan 04.1-16) already pins this at the compile-time-adjacent
    /// level; this test re-asserts the same two files' source text as this phase-wide suite's own
    /// independent copy of the phase's highest-severity structural guarantee, per this plan's own
    /// action text: "both exist because this is the phase's highest-severity structural
    /// guarantee." Uses a slightly wider disallowed-type list (adds a photo-typed `UIImage`
    /// parameter, not just `Data`/`URL`/`PhotosPickerItem`) since this suite is not required to
    /// match `CertificateTests.swift`'s exact list.
    @Test("theCertificateComposerAcceptsOnlyAServerBackedPhotoReference")
    func theCertificateComposerAcceptsOnlyAServerBackedPhotoReference() throws {
        guard let composerSource = try nonCommentSource(of: "Social/Certificate/CertificateComposer.swift") else {
            Issue.record("could not read Ritham/Social/Certificate/CertificateComposer.swift")
            return
        }
        for disallowed in ["URL(fileURLWithPath", "PhotosPickerItem", "photo: UIImage", "photo: Data", "photo: URL"] {
            #expect(!composerSource.contains(disallowed), "CertificateComposer.swift must not reference \(disallowed)")
        }

        guard let contentSource = try nonCommentSource(of: "Social/Certificate/CertificateContent.swift") else {
            Issue.record("could not read Ritham/Social/Certificate/CertificateContent.swift")
            return
        }
        #expect(contentSource.contains("photo: StrippedPhotoAsset?"), "CertificateContent.swift no longer types its photo field as the opaque server-backed asset")
        for disallowed in ["photo: UIImage", "photo: Data", "photo: URL"] {
            #expect(!contentSource.contains(disallowed), "CertificateContent.swift must not reference \(disallowed)")
        }
    }

    // MARK: - Geocoder containment

    /// Asserts exactly one file in the whole client constructs a `CLGeocoder`, and that it is the
    /// one file that owns the capture, zone-check, geocode, discard sequence -- named explicitly,
    /// not just counted, so a rename or a second construction site both fail this test.
    @Test("noSocialSurfaceConstructsAGeocoderOutsideTheOwnedSequence")
    func noSocialSurfaceConstructsAGeocoderOutsideTheOwnedSequence() throws {
        var constructingFiles: [URL] = []
        if let enumerator = FileManager.default.enumerator(at: rithamDirectory, includingPropertiesForKeys: nil) {
            for case let fileURL as URL in enumerator where fileURL.pathExtension == "swift" {
                let source = try nonCommentSource(ofAbsolute: fileURL)
                if source.contains("CLGeocoder(") {
                    constructingFiles.append(fileURL)
                }
            }
        }

        #expect(constructingFiles.count == 1, "expected exactly one file to construct CLGeocoder, found \(constructingFiles.count): \(constructingFiles.map(\.lastPathComponent))")
        #expect(constructingFiles.first?.lastPathComponent == "LocationAttachment.swift", "the sole CLGeocoder-constructing file must be LocationAttachment.swift, found \(constructingFiles.map(\.lastPathComponent))")
    }

    // MARK: - No data-bearing ring

    /// Asserts no social source file constructs a trimmed circular shape or an arc in a content
    /// area. Scoped to `Ritham/Social/` only, which structurally leaves the static header ornament
    /// (`DesignSystem/DecorativeSurface.swift` and friends, outside this directory) untouched.
    @Test("noSocialSurfaceConstructsADataBearingRing")
    func noSocialSurfaceConstructsADataBearingRing() throws {
        let scannedFiles = allSocialSwiftFiles()
        #expect(scannedFiles.count >= Self.minScannedSocialFiles, "scanned \(scannedFiles.count) files under Ritham/Social/, want at least \(Self.minScannedSocialFiles)")

        for fileURL in scannedFiles {
            let source = try nonCommentSource(ofAbsolute: fileURL)
            for token in ["Circle(", "trim(from:"] {
                #expect(!source.contains(token), "\(fileURL.lastPathComponent) contains '\(token)' -- no social surface may construct a trimmed circular shape or an arc in a content area")
            }
        }
    }

    // MARK: - Visibility ladder

    /// `GroupVisibilityScope` ships exactly two reachable rungs (`onlyMe`, `group`); the reserved
    /// household rung is a doc comment only, not a case, so a lookup for its raw value must return
    /// `nil` -- written this way, rather than referencing the reserved case by name, because a
    /// reserved-but-unimplemented case has no symbol to reference and a test naming it would not
    /// compile. Mirrors `MomentumVisibility`'s identical single-case-ladder precedent from Phase 3.
    @Test("theVisibilityScopeShipsTwoRungsWithTheThirdUnresolvable")
    func theVisibilityScopeShipsTwoRungsWithTheThirdUnresolvable() {
        #expect(GroupVisibilityScope.allCases.count == 2, "GroupVisibilityScope must ship exactly two reachable rungs until HOUSEHOLD-01 adds the household rung")
        #expect(GroupVisibilityScope(rawValue: "household") == nil, "the reserved household rung's raw value must resolve to nil -- there is no case for it yet")
    }

    // MARK: - Platform container and control avoidance

    /// No social source file constructs the platform list, form, or switch controls, matching this
    /// codebase's standing conventions (`Phase4CoverageTests.theDashboardIntroducesNoListOrForm`'s
    /// own precedent, extended here to the switch/toggle control). `Toggle(` is matched with a
    /// word-boundary-safe check (not a bare substring): `Ritham/Social/Feed/CheerReactionRow.swift`
    /// legitimately calls a closure parameter named `onToggle(cheer)`, whose text ends in the
    /// literal substring `Toggle(` -- a bare `.contains("Toggle(")` would false-positive on it.
    @Test("noSocialSurfaceUsesThePlatformListFormOrToggle")
    func noSocialSurfaceUsesThePlatformListFormOrToggle() throws {
        let scannedFiles = allSocialSwiftFiles()
        #expect(scannedFiles.count >= Self.minScannedSocialFiles, "scanned \(scannedFiles.count) files under Ritham/Social/, want at least \(Self.minScannedSocialFiles)")

        let togglePattern = try! NSRegularExpression(pattern: "(?<![A-Za-z0-9_])Toggle\\(")

        for fileURL in scannedFiles {
            let source = try nonCommentSource(ofAbsolute: fileURL)
            for token in ["List {", "List(", "Form {", "Form("] {
                #expect(!source.contains(token), "\(fileURL.lastPathComponent) contains '\(token)' -- the codebase has zero List/Form usage")
            }
            let toggleHits = matches(togglePattern, in: source)
            #expect(toggleHits.isEmpty, "\(fileURL.lastPathComponent) constructs a platform Toggle control")
        }
    }

    // MARK: - Typography floor

    /// No social source file uses a type role below the app's `RithamType.label` (16pt) floor.
    /// Matched against the precise SwiftUI font-role invocation shapes this codebase actually uses
    /// (`.font(.caption)`, seen at `App/StepRegistry.swift:189`), not a bare `.caption`/`.footnote`
    /// substring -- this directory has legitimate, unrelated members spelled `draft.caption` and
    /// (per `Feed/FeedClient.swift`'s own header comment) `item.caption`, both ordinary stored
    /// properties, not font roles, which a bare substring ban would have false-positived on.
    @Test("everySocialSurfaceRespectsTheTypographyFloor")
    func everySocialSurfaceRespectsTheTypographyFloor() throws {
        let scannedFiles = allSocialSwiftFiles()
        #expect(scannedFiles.count >= Self.minScannedSocialFiles, "scanned \(scannedFiles.count) files under Ritham/Social/, want at least \(Self.minScannedSocialFiles)")

        let bannedFontRoles = [
            ".font(.caption)", ".font(.footnote)", ".font(.caption2)",
            "Font.caption", "Font.footnote", "Font.caption2",
        ]
        for fileURL in scannedFiles {
            let source = try nonCommentSource(ofAbsolute: fileURL)
            for token in bannedFontRoles {
                #expect(!source.contains(token), "\(fileURL.lastPathComponent) contains '\(token)' -- RithamType.label (16pt) is the hard floor")
            }
        }
    }
}

}
