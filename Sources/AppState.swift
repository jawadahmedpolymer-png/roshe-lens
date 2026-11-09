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

    let history = HistoryStore()
    var image: UIImage?
    var blocks: [TextBlock] = []
    var phase: Phase = .idle
    var showOriginal = false
    var selected: TextBlock?
    var shareImage: UIImage?
    var config: TranslationSession.Configuration?
    private var savedToHistory = false
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
        show(img)
    }

    /// Screenshot or camera photo: read, translate, save to history.
    func show(_ raw: UIImage) {
        let img = raw.uprightAndSized(maxSide: 2400)
        image = img
        blocks = []
        selected = nil
        shareImage = nil
        showOriginal = false
        savedToHistory = false
        phase = .reading
        Task {
            let found = await OCR.recognize(img)
            self.blocks = found
            if found.isEmpty {
                self.phase = .failed("No Chinese text found here.")
            } else {
                self.startTranslation()
            }
        }
    }

    /// Re-open a past screen without translating again.
    func open(_ e: HistoryEntry) {
        guard let img = history.image(for: e) else { return }
        image = img
        blocks = e.blocks.map(\.block)
        selected = nil
        showOriginal = false
        savedToHistory = true
        phase = .done
        renderShareImage()
    }

    func close() {
        image = nil
        blocks = []
        shareImage = nil
        selected = nil
        phase = .idle
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
        guard !requests.isEmpty else { return }
        do {
            let responses = try await session.translations(from: requests)
            for r in responses {
                if let id = r.clientIdentifier,
                   let i = blocks.firstIndex(where: { $0.id.uuidString == id }) {
                    blocks[i].translated = r.targetText
                }
            }
            phase = .done
            renderShareImage()
            if !savedToHistory, let img = image {
                history.add(image: img, blocks: blocks)
                savedToHistory = true
            }
        } catch {
            phase = .failed("Translation didn't finish. Make sure Chinese and your language are downloaded in the Translate app, then try again.")
        }
    }

    /// Draws the translated screen into a picture for Save / Share.
    func renderShareImage() {
        guard let img = image else { return }
        let width = min(img.size.width, 1290)
        let height = width * img.size.height / img.size.width
        let view = OverlayView(image: img, blocks: blocks, showOriginal: false, onTap: { _ in })
            .frame(width: width, height: height)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        shareImage = renderer.uiImage
    }
}

extension UIImage {
    /// Camera photos come rotated and very large; make them upright and smaller.
    func uprightAndSized(maxSide: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        let factor = longest > maxSide ? maxSide / longest : 1
        if imageOrientation == .up && factor == 1 && scale == 1 { return self }
        let target = CGSize(width: (size.width * factor).rounded(), height: (size.height * factor).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
