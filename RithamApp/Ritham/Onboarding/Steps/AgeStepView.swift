import SwiftUI
import SwiftData
import RithamCore

// Q0's bounded numeric validation and MINOR-01's 13+ floor check. Per D-14 in
// 01-CONTEXT.md there is no tier or gate concept to resolve here -- only the raw age value and,
// downstream, a single boolean (OnboardingAnswers.isAgeEligible) the router reads. This view
// itself selects no destination: it hands the raw value to `flow.advance`, and
// OnboardingRouter.nextStep alone decides whether the next step is `.dietaryPattern` or the
// under-13 block screen. Adding a conditional here that picks the next screen would move a
// routing decision outside the router's own tested surface -- the one thing CROSSGEN-05 forbids
// most directly for this screen.
//
// The persist call below is gated on the value being thirteen or greater: an ineligible age is
// held only in `flow.answers.age` (in memory) long enough for the router to read it, and never
// reaches the durable profile store. The "nothing saved for the rejected attempt" promise is
// kept structurally, by the absence of a write, not by a later delete.
struct AgeStepView: View, OnboardingStepPresenting {
    static let step: OnboardingStep = .age

    static func makeView(flow: OnboardingFlow) -> AnyView {
        AnyView(AgeStepView(flow: flow))
    }

    let flow: OnboardingFlow
    @State private var ageText = ""
    @Environment(\.modelContext) private var modelContext

    private var validation: Result<Int, AgeValidationError> {
        AgeValidator.validate(ageText)
    }

    private var isValid: Bool {
        if case .success = validation { return true }
        return false
    }

    var body: some View {
        RithamScreen(surface: DecorativeSurface.flat, headline: OnboardingCopy.Age.headline) {
            VStack(alignment: .leading, spacing: RithamSpacing.sm) {
                TextField("", text: $ageText)
                    .keyboardType(.numberPad)
                    .font(RithamType.body)
                    .foregroundStyle(RithamColor.paper)
                    .padding(RithamSpacing.md)
                    .frame(minHeight: RithamSpacing.minimumTapTarget)
                    .background(
                        RoundedRectangle(cornerRadius: RithamSpacing.sm)
                            .stroke(RithamColor.paper, lineWidth: 1)
                    )
                    .accessibilityLabel(OnboardingCopy.Age.headline)
                    .onChange(of: ageText) { _, newValue in
                        // Reject non-digits at entry time, in addition to AgeValidator's own
                        // check -- belt-and-suspenders against a pasted value.
                        let digitsOnly = newValue.filter(\.isNumber)
                        if digitsOnly != newValue {
                            ageText = digitsOnly
                        }
                    }

                Text(OnboardingCopy.Age.helper)
                    .font(RithamType.label)
                    .foregroundStyle(RithamColor.paper)
                    .fixedSize(horizontal: false, vertical: true)

                if !ageText.isEmpty, case .failure = validation {
                    Text(OnboardingCopy.Age.invalidAgeError)
                        .font(RithamType.label)
                        .foregroundStyle(RithamColor.hot)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            PrimaryCTAButton(title: OnboardingCopy.Age.cta) {
                guard case .success(let age) = validation else { return }
                flow.answers.age = age
                if age >= 13 {
                    persistEligibleAge(age)
                }
                flow.advance(from: .age)
            }
            .disabled(!isValid)
        }
    }

    private func persistEligibleAge(_ age: Int) {
        let store = HealthDataStore(context: modelContext)
        try? store.updateProfile(UserProfileDraft(age: age, explanationRegister: flow.answers.register))
    }
}

/// Q0's numeric bound -- whole numbers from one to one hundred twenty -- checked entirely
/// independently of the 13+ floor. This validator has no opinion on the number thirteen: the
/// floor is a routing outcome the router alone resolves, never a malformed-input error this
/// type would surface.
enum AgeValidationError: Error, Equatable {
    case outOfRange

    /// The locked error copy every failure renders (01-UI-SPEC.md's Age (Q0) Error row).
    var message: String {
        OnboardingCopy.Age.invalidAgeError
    }
}

enum AgeValidator {
    /// No trimming: a value with leading or trailing whitespace must fail, not be silently
    /// tolerated. Every character must be a digit, and only a well-formed whole number from one
    /// to one hundred twenty succeeds.
    static func validate(_ text: String) -> Result<Int, AgeValidationError> {
        guard !text.isEmpty, text.allSatisfy(\.isNumber) else {
            return .failure(.outOfRange)
        }
        guard let value = Int(text), (1...120).contains(value) else {
            return .failure(.outOfRange)
        }
        return .success(value)
    }
}
