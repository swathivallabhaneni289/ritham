import SwiftUI
import SwiftData
import RithamCore

// ONBOARD-01 exists to replace a self-reported fitness-level dropdown with a real session. The
// body copy promises "no fitness dropdown, no guessing" -- honoured literally here: this screen
// offers a choice of activity (walk vs. light lift), never a choice of ability. Adding a
// fitness-level, experience-level, or beginner-to-advanced selector anywhere in this flow would
// defeat ONBOARD-01's entire purpose.
//
// D-03: the skip action sets `CalibrationOutcome.skipped`, persists a provisional baseline
// through `HealthDataStore.saveCalibrationBaseline` so cardio/strength suggestions still have a
// floor, and advances immediately. It never blocks, never warns the user they are missing out,
// and never re-prompts as a nag -- `OnboardingRouter` only reaches `.calibrationIntro` once per
// onboarding pass, so there is no later point where this screen resurfaces uninvited. D-03
// requires a generic starting point rather than a blank state; persisting `.provisional` before
// advancing is what keeps that true structurally rather than by convention.
extension CalibrationMode: @retroactive Identifiable {
    public var id: Self { self }
}

struct CalibrationIntroView: View, OnboardingStepPresenting {
    static let step: OnboardingStep = .calibrationIntro

    static func makeView(flow: OnboardingFlow) -> AnyView {
        AnyView(CalibrationIntroView(flow: flow))
    }

    /// Functional selector copy -- 01-UI-SPEC.md's Copywriting Contract has no dedicated row for
    /// this specific prompt (only the screen's headline/body/CTA are locked rows), so this is
    /// plain, non-assessment UI text rather than a re-transcription of locked copy.
    private static let modePrompt = "How would you like to calibrate?"

    let flow: OnboardingFlow
    @State private var selection: Set<CalibrationMode> = [.walk]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        RithamScreen(
            surface: DecorativeSurface.calibration,
            headline: OnboardingCopy.Calibration.startHeadline,
            bodyText: OnboardingCopy.Calibration.startBody
        ) {
            ChoiceQuestionView(
                prompt: Self.modePrompt,
                options: CalibrationMode.allCases,
                mode: .single,
                selection: $selection,
                optionTitle: modeTitle
            )

            PrimaryCTAButton(title: OnboardingCopy.Calibration.startCTA) {
                guard let chosen = selection.first else { return }
                flow.calibrationMode = chosen
                flow.advance(from: .calibrationIntro)
            }

            SecondaryCTAButton(title: OnboardingCopy.Calibration.skipCTA) {
                skipCalibration()
            }
        }
    }

    private func modeTitle(_ mode: CalibrationMode) -> String {
        switch mode {
        case .walk: return "A short walk"
        case .lift: return "A light lift"
        }
    }

    private func skipCalibration() {
        flow.answers.calibrationOutcome = CalibrationOutcome.skipped
        let store = HealthDataStore(context: modelContext)
        try? store.saveCalibrationBaseline(CalibrationBaseline.provisional(establishedAt: Date()))
        flow.advance(from: .calibrationIntro)
    }
}
