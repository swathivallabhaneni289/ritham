import Testing
import RithamCore
@testable import Ritham

@Suite("AgeValidationTests")
struct AgeValidationTests {

    @Test("boundary values 1 and 120 validate")
    func boundaryValuesValidate() {
        #expect((try? AgeValidator.validate("1").get()) == 1)
        #expect((try? AgeValidator.validate("120").get()) == 120)
    }

    @Test("0 and 121 fail -- just outside the 1-120 bound")
    func justOutOfBoundsFails() {
        #expect(AgeValidator.validate("0").isFailure)
        #expect(AgeValidator.validate("121").isFailure)
    }

    @Test("the validator has no opinion on the 13+ floor -- 8 and 12 validate exactly like 13 and 40 do")
    func validatorHasNoFloorOpinion() {
        for value in ["8", "12", "13", "40"] {
            #expect(AgeValidator.validate(value).isSuccess, "expected \(value) to validate")
        }
    }

    @Test(
        "malformed input shapes all fail",
        arguments: [
            "",      // empty
            " ",     // whitespace only
            "12.5",  // a decimal
            "-5",    // a negative number
            "abc",   // a non-numeric string
            " 40",   // leading whitespace
            "40 ",   // trailing whitespace
        ]
    )
    func malformedInputFails(_ text: String) {
        #expect(AgeValidator.validate(text).isFailure, "expected \"\(text)\" to fail validation")
    }

    @Test("a very long digit string fails rather than overflowing")
    func veryLongDigitStringFailsRatherThanOverflowing() {
        let veryLong = String(repeating: "9", count: 40)
        #expect(AgeValidator.validate(veryLong).isFailure)
    }

    @Test("every failure carries the locked error copy the view renders")
    func everyFailureCarriesLockedErrorCopy() {
        let failingInputs = ["", " ", "12.5", "-5", "abc", "0", "121"]
        for text in failingInputs {
            guard case .failure(let error) = AgeValidator.validate(text) else {
                Issue.record("expected \"\(text)\" to fail validation")
                continue
            }
            #expect(error.message == OnboardingCopy.Age.invalidAgeError)
        }
    }
}

private extension Result {
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }

    var isFailure: Bool {
        !isSuccess
    }
}
