import Testing
import RithamCore
@testable import Ritham

/// These tests exercise `Glossary` directly, as the plan specifies -- no rendering is needed to
/// prove the lookup and single-definition invariants `GlossaryTerm` depends on.
@Suite("GlossaryTermTests")
struct GlossaryTermTests {

    @Test("Every seeded term resolves via Glossary.entry(for:)")
    func everySeededTermResolves() {
        #expect(!Glossary.entries.isEmpty)
        for term in Glossary.entries.keys {
            #expect(Glossary.entry(for: term) != nil)
        }
    }

    @Test("Every seeded entry has a single, non-empty definition")
    func everyEntryHasANonEmptyDefinition() {
        for entry in Glossary.entries.values {
            #expect(!entry.definition.isEmpty)
        }
    }

    @Test("Glossary.entry(for:) returns nil for an unknown term")
    func unknownTermReturnsNil() {
        #expect(Glossary.entry(for: "Not a real glossary term") == nil)
    }

    @Test("Lookup is exact-match, not case-insensitive -- matches GlossaryTerm's own lookup")
    func lookupIsExactMatch() {
        // Glossary.entry(for:) is a direct dictionary lookup keyed by the term's exact string,
        // with no case-folding, and `GlossaryTerm` performs no case transformation before
        // calling it -- so the component and this assertion agree: lookup is exact, not
        // case-insensitive.
        #expect(Glossary.entry(for: "hrv") == nil)
        #expect(Glossary.entry(for: "HRV") != nil)
    }
}
