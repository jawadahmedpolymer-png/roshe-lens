import AppIntents
import UniformTypeIdentifiers

/// The Shortcuts action: "Translate Screen". AssistiveTouch runs a shortcut
/// that takes a screenshot and passes it here.
struct TranslateScreenIntent: AppIntent {
    static var title: LocalizedStringResource = "Translate Screen"
    static var description = IntentDescription("Translates the Chinese on a screenshot and shows it over the screen.")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Screenshot",
               supportedContentTypes: [.image],
               inputConnectionBehavior: .connectToPreviousIntentResult)
    var screenshot: IntentFile

    @MainActor
    func perform() async throws -> some IntentResult {
        AppState.shared.load(screenshot.data)
        return .result()
    }
}
