import Testing
@testable import RithamCore

@Suite("ScreeningAnswersTests")
struct ScreeningAnswersTests {

    @Test("YesNoUnsure.notSure and .yes are the cautious branch; .no is not")
    func cautiousBranch() {
        #expect(YesNoUnsure.notSure.isCautiousBranch)
        #expect(YesNoUnsure.yes.isCautiousBranch)
        #expect(!YesNoUnsure.no.isCautiousBranch)
    }

    private func scoff(yesCount: Int) -> SCOFFResponses {
        let answers = (0..<5).map { $0 < yesCount ? YesNo.yes : YesNo.no }
        return SCOFFResponses(
            ed1MakesSelfSickWhenFull: answers[0],
            ed2WorriesLostControlOverEating: answers[1],
            ed3RecentSignificantWeightLoss: answers[2],
            ed4BelievesSelfFatWhenToldTooThin: answers[3],
            ed5FoodDominatesLife: answers[4]
        )
    }

    @Test("zero yeses is not a positive screen")
    func zeroYesesNotPositive() {
        #expect(!scoff(yesCount: 0).isPositiveScreen)
    }

    @Test("exactly one yes is not a positive screen")
    func oneYesNotPositive() {
        #expect(!scoff(yesCount: 1).isPositiveScreen)
    }

    @Test("exactly two yeses is a positive screen")
    func twoYesesIsPositive() {
        #expect(scoff(yesCount: 2).isPositiveScreen)
    }

    @Test("five yeses is a positive screen")
    func fiveYesesIsPositive() {
        #expect(scoff(yesCount: 5).isPositiveScreen)
    }

    @Test("isTriggered is false for an empty checklist")
    func isTriggeredFalseForEmptyChecklist() {
        #expect(!SCOFFResponses.isTriggered(by: ChecklistSelection()))
    }

    @Test("isTriggered is false for a checklist of unrelated items")
    func isTriggeredFalseForUnrelatedItems() {
        var selection = ChecklistSelection()
        selection.toggle(.highBloodPressure)
        selection.toggle(.type2Diabetes)
        #expect(!SCOFFResponses.isTriggered(by: selection))
    }

    @Test("isTriggered is true once the eating-disorder-history item is present")
    func isTriggeredTrueForEatingDisorderHistory() {
        var selection = ChecklistSelection()
        selection.toggle(.eatingDisorderHistory)
        #expect(SCOFFResponses.isTriggered(by: selection))
    }

    @Test("toggling noneOfTheAbove into a populated selection leaves only noneOfTheAbove")
    func noneOfTheAboveClearsOtherSelections() {
        var selection = ChecklistSelection()
        selection.toggle(.highBloodPressure)
        selection.toggle(.osteoarthritis)
        selection.toggle(.noneOfTheAbove)
        #expect(selection.items == [.noneOfTheAbove])
    }

    @Test("toggling any other item into a noneOfTheAbove selection removes noneOfTheAbove")
    func otherItemRemovesNoneOfTheAbove() {
        var selection = ChecklistSelection()
        selection.toggle(.noneOfTheAbove)
        selection.toggle(.foodAllergies)
        #expect(selection.items == [.foodAllergies])
    }

    @Test("toggling an item twice removes it")
    func togglingTwiceRemovesItem() {
        var selection = ChecklistSelection()
        selection.toggle(.osteoarthritis)
        selection.toggle(.osteoarthritis)
        #expect(selection.items.isEmpty)
    }

    @Test("toggling noneOfTheAbove twice removes it")
    func togglingNoneOfTheAboveTwiceRemovesIt() {
        var selection = ChecklistSelection()
        selection.toggle(.noneOfTheAbove)
        selection.toggle(.noneOfTheAbove)
        #expect(selection.items.isEmpty)
    }

    @Test("every ChecklistItem maps to a category")
    func everyChecklistItemMapsToACategory() {
        for item in ChecklistItem.allCases {
            _ = item.category
        }
        #expect(ChecklistItem.noneOfTheAbove.category == .none)
        #expect(ChecklistItem.highBloodPressure.category == .cardiovascular)
    }
}
