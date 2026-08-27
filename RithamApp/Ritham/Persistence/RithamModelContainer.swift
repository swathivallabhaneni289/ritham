import Foundation
import SwiftData

// The single `ModelContainer` over the three health-screening models. 01-RESEARCH.md's Security
// Domain V6 finding names condition tags and eating-disorder-derived data as sensitive within
// LAUNCH-04's GDPR/CCPA review scope, so the store carries an explicit file protection class
// rather than relying on the platform default (T-01-59).
public enum RithamModelContainer {

    /// Every model this container persists.
    private static let models: [any PersistentModel.Type] = [
        UserProfile.self,
        ConditionTagRecord.self,
        CalibrationBaselineRecord.self,
    ]

    /// Builds a `ModelContainer`. `inMemory: true` is used by tests — an in-memory store has no
    /// file to protect, so `applyFileProtection` is skipped entirely in that case.
    public static func make(inMemory: Bool) throws -> ModelContainer {
        let schema = Schema(models)
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        } else {
            configuration = ModelConfiguration(schema: schema, url: try storeURL())
        }

        let container = try ModelContainer(for: schema, configurations: [configuration])

        if !inMemory {
            try applyFileProtection(storeURL: configuration.url)
        }

#if DEBUG
        // Debug-only, and deliberately prints no stored value — logging profile contents (age,
        // condition tags, screening outcome, or anything else read from this container) would
        // place health data in the device console, which is exactly the disclosure T-01-63
        // guards against. This confirms only that initialization reached this point.
        print("RithamModelContainer: initialized (inMemory: \(inMemory))")
#endif

        return container
    }

    /// The app's single shared container, attached in `RithamApp.swift`.
    public static let shared: ModelContainer = {
        do {
            return try make(inMemory: false)
        } catch {
            fatalError("RithamModelContainer.shared failed to initialize: \(error)")
        }
    }()

    /// A fixed, predictable store location (rather than SwiftData's implicit default naming)
    /// so `applyFileProtection` always knows exactly which file — and which sidecars — to
    /// protect.
    private static func storeURL() throws -> URL {
        let appSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return appSupport.appendingPathComponent("Ritham.store")
    }

    /// Applies `.completeUntilFirstUserAuthentication` to the store file and its SQLite
    /// sidecar files (`-wal`, `-shm`), then reads the attribute back to confirm it actually
    /// took effect, rather than assuming a silent no-op succeeded.
    ///
    /// The baseline is `.completeUntilFirstUserAuthentication`, not the stronger `.complete`:
    /// `.complete` makes the store unreadable whenever the device is locked, which would break
    /// any background work that touches the profile, while
    /// `.completeUntilFirstUserAuthentication` still protects against extraction from an
    /// unencrypted backup or a powered-off/never-yet-unlocked device. If a later phase adds no
    /// background access to this store, tightening to `.complete` is worth revisiting.
    ///
    /// Data Protection is an on-device feature backed by the Secure Enclave-derived class
    /// keys — the iOS Simulator runs on the host Mac's ordinary APFS volume, which does not
    /// implement it. `setAttributes`/`attributesOfItem` are real, callable APIs in the
    /// Simulator (they do not throw), but the read-back verification below cannot observe real
    /// protection there, only on a physical device. Guarding the *throw* to on-device only
    /// (never silently skipping the call itself) preserves the plan's actual intent — a silent
    /// failure surfacing at startup — on the one environment where the OS can enforce the
    /// class, while keeping the Simulator (the only environment this repo can currently test
    /// against, per 01-09-SUMMARY.md) usable for the rest of the app. This mirrors 01-09's
    /// Deviation #1 in kind: a plan gate that is unreachable as literally written in the only
    /// runnable environment.
    private static func applyFileProtection(storeURL: URL) throws {
        let attributes: [FileAttributeKey: Any] = [
            .protectionKey: FileProtectionType.completeUntilFirstUserAuthentication,
        ]

        var candidateURLs = [storeURL]
        candidateURLs.append(contentsOf: ["-wal", "-shm"].map { suffix in
            URL(fileURLWithPath: storeURL.path + suffix)
        })

        for url in candidateURLs {
            guard FileManager.default.fileExists(atPath: url.path) else { continue }

            try FileManager.default.setAttributes(attributes, ofItemAtPath: url.path)

            let readBack = try FileManager.default.attributesOfItem(atPath: url.path)
            let appliedProtection = readBack[.protectionKey] as? FileProtectionType

            guard appliedProtection == .completeUntilFirstUserAuthentication else {
#if targetEnvironment(simulator)
                // See the doc comment above: the Simulator's host filesystem does not implement
                // Data Protection, so the class we just set will not read back correctly here.
                // Log instead of throwing so the app remains usable in the only environment
                // this repo can run in; this is a Simulator-only relaxation, not a general one.
                #if DEBUG
                print("RithamModelContainer: file protection not verified for \(url.lastPathComponent) (expected on Simulator)")
                #endif
                continue
#else
                throw RithamModelContainerError.protectionNotApplied(fileName: url.lastPathComponent)
#endif
            }
        }
    }
}

public enum RithamModelContainerError: Error, Equatable {
    /// Thrown when the store's file protection attribute does not read back as the class we
    /// just set — a silent failure here would otherwise only surface at a compliance review.
    case protectionNotApplied(fileName: String)
}
