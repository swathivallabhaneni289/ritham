import Testing
@testable import RithamCore

/// Proves the toolchain-adaptive Swift Testing harness executes tests on this machine
/// (no Xcode installed). Later plans' red tests are only trustworthy once this is green.
@Suite("HarnessTests")
struct HarnessTests {
    @Test("schemaVersion equals 1")
    func schemaVersionIsOne() {
        #expect(RithamCore.schemaVersion == 1)
    }
}
