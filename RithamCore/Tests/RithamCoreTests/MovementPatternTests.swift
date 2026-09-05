import Testing
@testable import RithamCore

@Suite("MovementPatternTests")
struct MovementPatternTests {

    @Test("MovementPattern.allCases contains exactly push, pull, squat, hinge and carry")
    func allCasesAreExact() {
        #expect(Set(MovementPattern.allCases) == [.push, .pull, .squat, .hinge, .carry])
    }

    @Test("every ExerciseCatalog entry resolves to a non-empty pattern set")
    func everyCatalogEntryHasNonEmptyPatterns() {
        for exercise in ExerciseCatalog.all {
            #expect(!exercise.patterns.isEmpty)
        }
    }

    @Test("a back squat resolves to a set containing squat")
    func backSquatContainsSquat() {
        #expect(ExerciseCatalog.patterns(for: "backSquat").contains(.squat))
    }

    @Test("a thruster resolves to a set containing both squat and push")
    func thrusterContainsSquatAndPush() {
        let patterns = ExerciseCatalog.patterns(for: "thruster")
        #expect(patterns.contains(.squat))
        #expect(patterns.contains(.push))
    }

    @Test("an unknown exercise identifier resolves to an empty set")
    func unknownIdentifierResolvesToEmptySet() {
        #expect(ExerciseCatalog.patterns(for: "notARealExercise") == [])
        #expect(ExerciseCatalog.definition(for: "notARealExercise") == nil)
    }

    @Test("every seeded exercise identifier is unique")
    func everyIdentifierIsUnique() {
        let identifiers = ExerciseCatalog.all.map(\.identifier)
        #expect(Set(identifiers).count == identifiers.count)
    }

    @Test("at least one catalog entry has two or more patterns")
    func atLeastOneMultiPatternEntry() {
        #expect(ExerciseCatalog.all.contains { $0.patterns.count >= 2 })
    }

    @Test("the catalog seeds at least 25 exercises")
    func catalogHasAtLeast25Exercises() {
        #expect(ExerciseCatalog.all.count >= 25)
    }
}
