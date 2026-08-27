// Registers the three calibration screens with StepRegistry. NOT invoked from the app entry
// point -- plan 01-18 owns the single bootstrap file that calls every registrar, so four wave-7
// plans do not all append to one shared function. Tests in this plan call `registerAll()`
// directly in their own setup.
@MainActor
enum CalibrationRegistration {
    static func registerAll() {
        StepRegistry.register(CalibrationIntroView.self)
        StepRegistry.register(CalibrationSessionView.self)
        StepRegistry.register(CalibrationCompleteView.self)
    }
}
