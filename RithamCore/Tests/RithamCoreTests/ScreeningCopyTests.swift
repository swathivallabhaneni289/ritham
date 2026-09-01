import Foundation
import Testing
@testable import RithamCore

@Suite("ScreeningCopyTests")
struct ScreeningCopyTests {

    @Test("opening disclaimer contains the emergency carve-out and no country-specific number")
    func openingDisclaimerContainsEmergencyCarveOut() {
        #expect(ScreeningCopy.openingDisclaimer.contains("local emergency number"))
        #expect(!ScreeningCopy.openingDisclaimer.contains("911"))
    }

    @Test("urgent clearance interstitial contains the emergency carve-out and no country-specific number")
    func urgentClearanceInterstitialContainsEmergencyCarveOut() {
        #expect(ScreeningCopy.urgentClearanceInterstitial.contains("local emergency number"))
        #expect(!ScreeningCopy.urgentClearanceInterstitial.contains("911"))
    }

    @Test("the standalone emergency line contains the emergency carve-out and no country-specific number")
    func emergencyLineContainsEmergencyCarveOut() {
        #expect(ScreeningCopy.emergencyLine.contains("local emergency number"))
        #expect(!ScreeningCopy.emergencyLine.contains("911"))
    }

    @Test("gate section framing does not name the branded screening instrument")
    func gateSectionFramingDoesNotNamePARQ() {
        #expect(!ScreeningCopy.gateSectionFraming.contains("PAR-Q"))
    }

    @Test("compactDisclaimerTag lists all matched conditions (D-12)")
    func compactDisclaimerTagListsAllConditions() {
        let tag = ScreeningCopy.compactDisclaimerTag(conditions: ["Hypertension", "Osteoarthritis"])
        #expect(tag.contains("Hypertension"))
        #expect(tag.contains("Osteoarthritis"))
    }

    @Test("expandedDisclaimer contains the condition and the not-a-diagnosis line")
    func expandedDisclaimerContainsConditionAndDisclaimer() {
        let text = ScreeningCopy.expandedDisclaimer(conditions: ["Hypertension"])
        #expect(text.contains("Hypertension"))
        #expect(text.contains("not a diagnosis"))
    }

    @Test("all named string constants are non-empty and trimmed")
    func allConstantsNonEmptyAndTrimmed() {
        let constants: [String] = [
            ScreeningCopy.openingDisclaimerHeadline,
            ScreeningCopy.openingDisclaimer,
            ScreeningCopy.routineClearanceInterstitial,
            ScreeningCopy.routineClearanceCTA,
            ScreeningCopy.urgentClearanceInterstitial,
            ScreeningCopy.urgentClearanceCTA,
            ScreeningCopy.requiredBlockingMessage,
            ScreeningCopy.standingFooterDisclaimer,
            ScreeningCopy.gateSectionHeadline,
            ScreeningCopy.gateSectionFraming,
            ScreeningCopy.gatePassAffirmation,
            ScreeningCopy.conditionChecklistIntro,
            ScreeningCopy.scoffIntro,
            ScreeningCopy.pregnancyRationale,
            ScreeningCopy.eatingDisorderRationale,
        ]

        for constant in constants {
            #expect(!constant.isEmpty)
            let trimmed = constant.trimmingCharacters(in: .whitespacesAndNewlines)
            #expect(constant == trimmed, "constant has leading/trailing whitespace: \"\(constant)\"")
        }
    }
}
