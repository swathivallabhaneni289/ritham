import Testing
@testable import RithamCore

@Suite("OnboardingCopyTests")
struct OnboardingCopyTests {

    /// Every constant across every nested screen namespace in OnboardingCopy.
    private static let allConstants: [String] = [
        OnboardingCopy.Welcome.headline,
        OnboardingCopy.Welcome.subhead,
        OnboardingCopy.Welcome.cta,
        OnboardingCopy.Register.headline,
        OnboardingCopy.Register.optionPlain,
        OnboardingCopy.Register.optionTechnical,
        OnboardingCopy.Register.helper,
        OnboardingCopy.Register.cta,
        OnboardingCopy.Age.headline,
        OnboardingCopy.Age.helper,
        OnboardingCopy.Age.cta,
        OnboardingCopy.Age.invalidAgeError,
        OnboardingCopy.Diet.headline,
        OnboardingCopy.Diet.optionNone,
        OnboardingCopy.Diet.optionVegetarian,
        OnboardingCopy.Diet.optionVegan,
        OnboardingCopy.Diet.helper,
        OnboardingCopy.AgeGate.headline,
        OnboardingCopy.AgeGate.body,
        OnboardingCopy.AgeGate.cta,
        OnboardingCopy.Privacy.headline,
        OnboardingCopy.Privacy.bulletNothingShared,
        OnboardingCopy.Privacy.bulletAnswersPrivate,
        OnboardingCopy.Privacy.bulletYouChoose,
        OnboardingCopy.Privacy.cta,
        OnboardingCopy.Calibration.startHeadline,
        OnboardingCopy.Calibration.startBody,
        OnboardingCopy.Calibration.startCTA,
        OnboardingCopy.Calibration.completeHeadline,
        OnboardingCopy.Calibration.completeBody,
        OnboardingCopy.HealthProfile.emptyStateHeading,
        OnboardingCopy.HealthProfile.emptyStateBody,
        OnboardingCopy.HealthProfile.emptyStateCTA,
        OnboardingCopy.Errors.savingFailed,
    ]

    @Test("Age.helper preserves the CROSSGEN-05 promise")
    func ageHelperPreservesCrossgenPromise() {
        #expect(OnboardingCopy.Age.helper.contains("never to sort you into a different app"))
    }

    @Test("Diet.helper preserves the DIET-01 isolation promise")
    func dietHelperPreservesIsolationPromise() {
        #expect(OnboardingCopy.Diet.helper.contains("never your health screening"))
    }

    @Test("Privacy.bulletNothingShared preserves the CROSSGEN-03 nothing-shared-by-default claim")
    func privacyBulletPreservesNothingSharedClaim() {
        #expect(OnboardingCopy.Privacy.bulletNothingShared.contains("by default"))
    }

    @Test("AgeGate.headline preserves the canonical MINOR-01 blocking message")
    func ageGateHeadlinePreserves13Plus() {
        #expect(OnboardingCopy.AgeGate.headline.contains("13+"))
    }

    @Test("no constant names any parental-consent concept")
    func noConstantNamesParentalConsent() {
        for constant in Self.allConstants {
            let lowered = constant.lowercased()
            #expect(!lowered.contains("consent"), "constant contains 'consent': \"\(constant)\"")
            #expect(!lowered.contains("parental"), "constant contains 'parental': \"\(constant)\"")
            #expect(!lowered.contains("approv"), "constant contains 'approv': \"\(constant)\"")
        }
    }

    @Test("no constant uses the forbidden age-segmented mode label")
    func noConstantUsesSeniorMode() {
        for constant in Self.allConstants {
            #expect(!constant.lowercased().contains("senior mode"), "constant contains 'senior mode': \"\(constant)\"")
        }
    }

    @Test("every constant is non-empty")
    func everyConstantNonEmpty() {
        for constant in Self.allConstants {
            #expect(!constant.isEmpty)
        }
    }
}
