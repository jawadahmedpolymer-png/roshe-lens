import UIKit
import Observation

/// A translated line as stored on disk.
struct SavedBlock: Codable {
    let original: String
    let translated: String?
    let rect: [Double]   // x, y, w, h (0...1, top-left origin)
    let bg: [Double]     // r, g, b (0...1)
    let fg: [Double]

    init(_ b: TextBlock) {
        original = b.original
        translated = b.translated
        rect = [b.rect.minX, b.rect.minY, b.rect.width, b.rect.height].map(Double.init)
        bg = SavedBlock.rgb(b.background)
        fg = SavedBlock.rgb(b.foreground)
    }

    static func rgb(_ c: UIColor) -> [Double] {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        return [r, g, b].map(Double.init)
    }

    var block: TextBlock {
        func ui(_ v: [Double]) -> UIColor {
            UIColor(red: v[safe: 0], green: v[safe: 1], blue: v[safe: 2], alpha: 1)
        }
        return TextBlock(original: original,
                         rect: CGRect(x: rect[safe: 0], y: rect[safe: 1], width: rect[safe: 2], height: rect[safe: 3]),
                         background: ui(bg), foreground: ui(fg), translated: translated)
    }
}

extension Array where Element == Double {
    subscript(safe i: Int) -> CGFloat { i < count ? CGFloat(self[i]) : 0 }
}

struct HistoryEntry: Codable, Identifiable {
    let id: UUID
    let date: Date
    let imageFile: String
    let blocks: [SavedBlock]

    var preview: String {
        blocks.compactMap(\.translated).prefix(3).joined(separator: " · ")
    }
}

/// Past translated screens, kept in the app's own storage on the phone.
@MainActor
@Observable
final class HistoryStore {
    private(set) var entries: [HistoryEntry] = []
    private let dir: URL
    private let limit = 30

    init() {
        dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("History", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if let d = try? Data(contentsOf: indexURL),
           let e = try? JSONDecoder().decode([HistoryEntry].self, from: d) {
            entries = e
        }
        trim()
    }

    private func trim() {
        guard entries.count > limit else { return }
        while entries.count > limit {
            let old = entries.removeLast()
            try? FileManager.default.removeItem(at: dir.appendingPathComponent(old.imageFile))
        }
        persist()
    }

    private var indexURL: URL { dir.appendingPathComponent("index.json") }

    private func persist() {
        if let d = try? JSONEncoder().encode(entries) { try? d.write(to: indexURL, options: .atomic) }
    }

    func add(image: UIImage, blocks: [TextBlock]) {
        let id = UUID()
        let name = id.uuidString + ".jpg"
        guard let jpg = image.jpegData(compressionQuality: 0.8) else { return }
        try? jpg.write(to: dir.appendingPathComponent(name))
        entries.insert(HistoryEntry(id: id, date: .now, imageFile: name, blocks: blocks.map(SavedBlock.init)), at: 0)
        trim()
        persist()
    }

    func image(for e: HistoryEntry) -> UIImage? {
        UIImage(contentsOfFile: dir.appendingPathComponent(e.imageFile).path)
    }

    func delete(_ e: HistoryEntry) {
        entries.removeAll { $0.id == e.id }
        try? FileManager.default.removeItem(at: dir.appendingPathComponent(e.imageFile))
        persist()
    }

    func deleteAll() {
        for e in entries { try? FileManager.default.removeItem(at: dir.appendingPathComponent(e.imageFile)) }
        entries = []
        persist()
    }
}
