import SwiftUI
import AuthenticationServices
import RithamCore

/// The opt-in account entry screen (ACCOUNT-01). Reachable only by choosing a social feature from
/// the dashboard (`HomeHubView`'s social section, plan 04.1-05 Task 3), never during onboarding and
/// never on the path to core tracking (T-04.1-28) -- `OnboardingRouter` never advances into this
/// step (`OnboardingStep.swift`'s own header comment).
///
/// `.boundedHeaderOnly`: this screen explains and offers, it does not collect or confirm health or
/// consent data, the same treatment `PrivacyExplainerStepView` already uses for the identical
/// reason (`04.1-UI-SPEC.md`'s Layout & Screen Contract).
struct SignInWithAppleView: View, OnboardingStepPresenting {
    static let step: OnboardingStep = .signInWithApple

    static func makeView(flow: OnboardingFlow) -> AnyView {
        AnyView(SignInWithAppleView(flow: flow))
    }

    let flow: OnboardingFlow

    @State private var model = SocialIdentityModel()

    var body: some View {
        RithamScreen(
            surface: DecorativeSurface.boundedHeaderOnly,
            headline: SocialCopy.SignInWithApple.headline,
            bodyText: SocialCopy.SignInWithApple.body
        ) {
            VStack(alignment: .leading, spacing: RithamSpacing.md) {
                // Apple's own component, per App Store Review Guideline 4.8 -- its label and logo
                // are not customizable and must never be recreated from RithamColor/RithamType
                // tokens. `.white` matches Apple's own guidance for a button on a dark background
                // (04.1-UI-SPEC.md, Sign in with Apple entry point). Only the corner radius is a
                // parameter Apple's HIG permits customizing.
                SignInWithAppleButton(.signIn) { request in
                    model.configureRequest(request)
                } onCompletion: { result in
                    handle(result)
                }
                .signInWithAppleButtonStyle(.white)
                .frame(minHeight: RithamSpacing.minimumTapTarget)
                .clipShape(RoundedRectangle(cornerRadius: RithamSpacing.sm))

                if case .failed = model.state {
                    Text(OnboardingCopy.Errors.savingFailed)
                        .font(RithamType.label)
                        .foregroundStyle(RithamColor.hot)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .onAppear {
            Task { await model.refresh() }
        }
    }

    private func handle(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            Task {
                await model.signIn(authorization: authorization)
                // Returns to the dashboard the moment a session exists, so the "the dashboard
                // section shows your name" behavior Task 4's manual check verifies is real rather
                // than left stranded on this screen (Rule 2: the plan's own must_haves truth "a
                // signed-in session survives app relaunch" implies the dashboard is the surface
                // that shows it).
                if case .signedIn = model.state {
                    flow.goBack()
                }
            }
        case .failure(let authorizationError):
            // A user tapping Cancel on Apple's own sheet is a normal, expected dismissal, never a
            // failure state to surface -- only a genuine authorization error reaches `markFailed`.
            let isUserCancellation = (authorizationError as? ASAuthorizationError)?.code == .canceled
            if !isUserCancellation {
                model.markFailed()
            }
        }
    }
}

/// Registers `SignInWithAppleView` under `.signInWithApple`. `SocialStepRegistration` calls this
/// today; later social plans add their own registrar call alongside it, matching
/// `Phase2StepRegistration`'s precedent.
@MainActor
enum SocialIdentityRegistration {
    static func registerAll() {
        StepRegistry.register(SignInWithAppleView.self)
    }
}
