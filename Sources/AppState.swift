import SwiftUI
import Observation
import Translation

/// One line of Chinese found on the screenshot.
struct TextBlock: Identifiable {
    let id = UUID()
    let original: String
    /// Position on the image, 0...1, origin at the top-left.
    let rect: CGRect
    let background: UIColor
    let foreground: UIColor
    var translated: String?
}

/// Languages Apple's on-device translator offers that are useful here.
struct TargetLanguage: Identifiable, Hashable {
    let id: String
    let name: String
    static let all: [TargetLanguage] = [
        .init(id: "en", name: "English"),
        .init(id: "ar", name: "Arabic"),
        .init(id: "hi", name: "Hindi"),
        .init(id: "fr", name: "French"),
        .init(id: "es", name: "Spanish"),
        .init(id: "de", name: "German"),
        .init(id: "ru", name: "Russian"),
        .init(id: "tr", name: "Turkish"),
        .init(id: "id", name: "Indonesian")
    ]
}

@MainActor
@Observable
final class AppState {
    static let shared = AppState()

    enum Phase: Equatable {
        case idle, reading, translating, done
        case failed(String)
    }

    var image: UIImage?
    var blocks: [TextBlock] = []
    var phase: Phase = .idle
    var showOriginal = false
    var selected: TextBlock?
    var config: TranslationSession.Configuration?
    var target: String = UserDefaults.standard.string(forKey: "target") ?? "en" {
        didSet {
            UserDefaults.standard.set(target, forKey: "target")
            if !blocks.isEmpty { startTranslation() }
        }
    }

    /// Called by the Shortcut action with the screenshot.
    func load(_ data: Data) {
        guard let img = UIImage(data: data) else {
            phase = .failed("Couldn't open the screenshot.")
            return
        }
        image = img
        blocks = []
        selected = nil
        showOriginal = false
        phase = .reading
        Task {
            let found = await OCR.recognize(img)
            self.blocks = found
            if found.isEmpty {
                self.phase = .failed("No Chinese text found on this screen.")
            } else {
                self.startTranslation()
            }
        }
    }

    func startTranslation() {
        phase = .translating
        let source = Locale.Language(identifier: "zh-Hans")
        let dest = Locale.Language(identifier: target)
        if config?.target == dest {
            config?.invalidate()
        } else {
            config = TranslationSession.Configuration(source: source, target: dest)
        }
    }

    func translate(using session: TranslationSession) async {
        let requests = blocks.map {
            TranslationSession.Request(sourceText: $0.original, clientIdentifier: $0.id.uuidString)
        }
        do {
            let responses = try await session.translations(from: requests)
            for r in responses {
                if let id = r.clientIdentifier,
                   let i = blocks.firstIndex(where: { $0.id.uuidString == id }) {
                    blocks[i].translated = r.targetText
                }
            }
            phase = .done
        } catch {
            phase = .failed("Translation didn't finish. Make sure Chinese and your language are downloaded in the Translate app, then try again.")
        }
    }
}
