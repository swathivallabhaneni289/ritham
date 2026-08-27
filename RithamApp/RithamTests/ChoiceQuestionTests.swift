import Testing
@testable import Ritham

/// A minimal Hashable-only test option type -- `ChoiceSelectionReducer` requires nothing more
/// than `Hashable`, so these tests exercise it directly without any view or `Identifiable`
/// machinery.
private enum TestOption: Hashable {
    case alpha
    case beta
    case gamma
    case exclusive
}

@Suite("ChoiceQuestionTests")
struct ChoiceQuestionTests {

    // MARK: - Single mode

    @Test("Single mode replaces the current selection")
    func singleModeReplaces() {
        let starting: Set<TestOption> = [.beta]
        let next = ChoiceSelectionReducer.toggling(TestOption.alpha, in: starting, mode: .single)
        #expect(next == [.alpha])
    }

    // MARK: - Multiple mode, no exclusive option

    @Test("Multiple mode accumulates selections")
    func multipleModeAccumulates() {
        let starting: Set<TestOption> = [.alpha]
        let next = ChoiceSelectionReducer.toggling(TestOption.beta, in: starting, mode: .multiple(exclusiveOption: nil))
        #expect(next == [.alpha, .beta])
    }

    @Test("Deselecting in multiple mode removes only that option")
    func multipleModeDeselectsOnlyThatOption() {
        let starting: Set<TestOption> = [.alpha, .beta]
        let next = ChoiceSelectionReducer.toggling(TestOption.alpha, in: starting, mode: .multiple(exclusiveOption: nil))
        #expect(next == [.beta])
    }

    // MARK: - Multiple mode with an exclusive option (§1.3 None-of-the-above)

    @Test("Selecting the exclusive option clears every other selection")
    func selectingExclusiveClearsOthers() {
        let starting: Set<TestOption> = [.alpha, .beta]
        let next = ChoiceSelectionReducer.toggling(
            TestOption.exclusive,
            in: starting,
            mode: .multiple(exclusiveOption: AnyHashable(TestOption.exclusive))
        )
        #expect(next == [.exclusive])
    }

    @Test("Selecting a non-exclusive option while the exclusive one is selected removes the exclusive one")
    func selectingNonExclusiveRemovesExclusive() {
        let starting: Set<TestOption> = [.exclusive]
        let next = ChoiceSelectionReducer.toggling(
            TestOption.alpha,
            in: starting,
            mode: .multiple(exclusiveOption: AnyHashable(TestOption.exclusive))
        )
        #expect(next == [.alpha])
    }

    @Test("Toggling the already-selected exclusive option deselects it, leaving an empty selection")
    func deselectingExclusiveEmptiesSelection() {
        let starting: Set<TestOption> = [.exclusive]
        let next = ChoiceSelectionReducer.toggling(
            TestOption.exclusive,
            in: starting,
            mode: .multiple(exclusiveOption: AnyHashable(TestOption.exclusive))
        )
        #expect(next.isEmpty)
    }

    @Test("The reducer never produces a state holding both the exclusive option and another option")
    func exclusiveAndOtherNeverCoexist() {
        let mode = ChoiceMode.multiple(exclusiveOption: AnyHashable(TestOption.exclusive))
        var selection: Set<TestOption> = []

        // Walk a sequence of toggles that would produce a contradictory state if the invariant
        // were broken: select two non-exclusive options, then the exclusive one, then a
        // non-exclusive one again, checking the invariant after every step.
        let sequence: [TestOption] = [.alpha, .beta, .exclusive, .gamma, .exclusive, .alpha]
        for option in sequence {
            selection = ChoiceSelectionReducer.toggling(option, in: selection, mode: mode)
            let holdsExclusive = selection.contains(.exclusive)
            let holdsAnyOther = selection.contains(where: { $0 != .exclusive })
            #expect(!(holdsExclusive && holdsAnyOther))
        }
    }
}
