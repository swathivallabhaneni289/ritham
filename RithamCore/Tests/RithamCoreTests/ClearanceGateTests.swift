import Testing
@testable import RithamCore

@Suite("ClearanceGateTests")
struct ClearanceGateTests {

    @Test("gates order none < recommended < requiredBlocking")
    func gateOrdering() {
        #expect(ClearanceGate.none < ClearanceGate.recommended)
        #expect(ClearanceGate.recommended < ClearanceGate.requiredBlocking)
        #expect(ClearanceGate.none < ClearanceGate.requiredBlocking)
    }

    @Test("mostRestrictive of a mixed list returns requiredBlocking")
    func mostRestrictiveMixedList() {
        let gates: [ClearanceGate] = [.none, .requiredBlocking, .recommended]
        #expect(ClearanceGate.mostRestrictive(gates) == .requiredBlocking)
    }

    @Test("mostRestrictive never returns a lower value than the most restrictive input")
    func mostRestrictiveNeverLower() {
        let allBlocking: [ClearanceGate] = [.requiredBlocking, .requiredBlocking]
        #expect(ClearanceGate.mostRestrictive(allBlocking) == .requiredBlocking)
    }

    @Test("mostRestrictive of none and recommended returns recommended")
    func mostRestrictiveNoneAndRecommended() {
        #expect(ClearanceGate.mostRestrictive([.none, .recommended]) == .recommended)
    }

    @Test("mostRestrictive of an empty list returns none")
    func mostRestrictiveEmpty() {
        #expect(ClearanceGate.mostRestrictive([]) == .none)
    }

    @Test("DomainGates subscripting returns the per-domain value")
    func domainGatesSubscript() {
        let gates = DomainGates(workout: .recommended, nutrition: .requiredBlocking)
        #expect(gates[.workout] == .recommended)
        #expect(gates[.nutrition] == .requiredBlocking)
    }

    @Test("every ConditionTag has a non-empty displayName")
    func everyConditionTagHasNonEmptyDisplayName() {
        for tag in ConditionTag.allCases {
            #expect(!tag.displayName.isEmpty)
        }
    }

    @Test("every ConditionTag displayName is unique")
    func conditionTagDisplayNamesAreUnique() {
        let names = ConditionTag.allCases.map(\.displayName)
        #expect(Set(names).count == names.count)
    }

    @Test("ageDerivedTags returns the 65+ tag for 65 and 120")
    func ageDerivedTagsAt65AndAbove() {
        #expect(ConditionTag.ageDerivedTags(forAge: 65) == [.age65PlusOrDeconditioned])
        #expect(ConditionTag.ageDerivedTags(forAge: 120) == [.age65PlusOrDeconditioned])
    }

    @Test("ageDerivedTags returns an empty set for 64, 13, and 0")
    func ageDerivedTagsBelow65() {
        #expect(ConditionTag.ageDerivedTags(forAge: 64) == [])
        #expect(ConditionTag.ageDerivedTags(forAge: 13) == [])
        #expect(ConditionTag.ageDerivedTags(forAge: 0) == [])
    }
}
