import SwiftUI
import AVFoundation

// MARK: - Camera

/// The iPhone camera, for menus, signs and product labels.
struct CameraPicker: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let p = UIImagePickerController()
        p.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        p.delegate = context.coordinator
        return p
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let img = info[.originalImage] as? UIImage { parent.onImage(img) }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Tap a line: hear it, pinyin, copy

final class Speaker {
    static let shared = Speaker()
    private let synth = AVSpeechSynthesizer()

    func say(_ text: String) {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
        synth.stopSpeaking(at: .immediate)
        let u = AVSpeechUtterance(string: text)
        u.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        u.rate = 0.42
        synth.speak(u)
    }
}

func pinyin(_ text: String) -> String {
    let m = NSMutableString(string: text)
    CFStringTransform(m, nil, kCFStringTransformToLatin, false)
    return m as String
}

struct DetailSheet: View {
    let block: TextBlock
    @State private var copied: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(block.original)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.white)
                .textSelection(.enabled)
            Text(pinyin(block.original))
                .font(.title3)
                .foregroundStyle(Color.goldLight)
            Text(block.translated ?? "…")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white.opacity(0.9))
                .textSelection(.enabled)
            HStack(spacing: 10) {
                pill("Listen", "speaker.wave.2.fill") { Speaker.shared.say(block.original) }
                pill(copied == "zh" ? "Copied" : "Copy Chinese", "doc.on.doc") {
                    UIPasteboard.general.string = block.original
                    copied = "zh"
                }
                pill(copied == "en" ? "Copied" : "Copy English", "doc.on.doc") {
                    UIPasteboard.general.string = block.translated ?? ""
                    copied = "en"
                }
            }
            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.ink)
        .presentationDetents([.medium])
        .presentationBackground(Color.ink)
    }

    private func pill(_ title: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.vertical, 10).padding(.horizontal, 12)
                .frame(maxWidth: .infinity)
                .background(Color.panel, in: Capsule())
                .overlay(Capsule().stroke(Color.gold.opacity(0.5)))
                .foregroundStyle(Color.goldLight)
        }
    }
}

// MARK: - History

struct HistoryView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if state.history.entries.isEmpty {
                    ContentUnavailableView("No translations yet",
                                           systemImage: "clock.arrow.circlepath",
                                           description: Text("Every screen you translate is kept here."))
                } else {
                    List {
                        ForEach(state.history.entries) { e in
                            Button {
                                state.open(e)
                                dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    Thumb(entry: e)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(e.date.formatted(date: .abbreviated, time: .shortened))
                                            .font(.caption).foregroundStyle(Color.gold)
                                        Text(e.preview.isEmpty ? "Translated screen" : e.preview)
                                            .font(.subheadline).foregroundStyle(.white)
                                            .lineLimit(2)
                                    }
                                }
                            }
                            .listRowBackground(Color.panel)
                        }
                        .onDelete { idx in idx.map { state.history.entries[$0] }.forEach(state.history.delete) }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Color.ink)
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Close") { dismiss() } }
                if !state.history.entries.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button("Delete all", role: .destructive) { state.history.deleteAll() }
                        } label: { Image(systemName: "ellipsis.circle") }
                    }
                }
            }
        }
    }
}

private struct Thumb: View {
    @Environment(AppState.self) private var state
    let entry: HistoryEntry
    var body: some View {
        Group {
            if let img = state.history.image(for: entry) {
                Image(uiImage: img).resizable().scaledToFill()
            } else {
                Color.panel
            }
        }
        .frame(width: 52, height: 72)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Setup guide

struct SetupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    section("1 · Make the shortcut", [
                        "Tap Open Shortcuts below, then +.",
                        "Add Take Screenshot.",
                        "Add Translate Screen (Roshe Lens).",
                        "Name it Roshe Translate and tap Done."
                    ])
                    Button { openURL(URL(string: "shortcuts://")!) } label: {
                        Label("Open Shortcuts", systemImage: "square.2.layers.3d")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(LinearGradient(colors: [.goldLight, .gold], startPoint: .top, endPoint: .bottom),
                                        in: RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(Color.ink)
                    }
                    section("2 · AssistiveTouch", [
                        "Settings › Accessibility › Touch › AssistiveTouch: turn on.",
                        "Single-Tap › Shortcuts › Roshe Translate."
                    ])
                    section("3 · Action button (iPhone 15 Pro and later)", [
                        "Settings › Action Button › swipe to Shortcut.",
                        "Choose Roshe Translate. Press the side button in any app."
                    ])
                    section("4 · Control Center", [
                        "Swipe down from the top right, tap +, then Add a Control.",
                        "Search Shortcuts, choose Run Shortcut › Roshe Translate.",
                        "If it captures Control Center itself, use AssistiveTouch or the Action button instead."
                    ])
                    section("5 · Back Tap (any iPhone)", [
                        "Settings › Accessibility › Touch › Back Tap › Double Tap.",
                        "Choose Roshe Translate. Double-tap the back of your phone."
                    ])
                }
                .padding(20)
            }
            .background(Color.ink)
            .navigationTitle("Set up quick translate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }

    private func section(_ title: String, _ lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline).foregroundStyle(Color.goldLight)
            ForEach(lines, id: \.self) { l in
                Text(l).foregroundStyle(.white.opacity(0.88))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.panel, in: RoundedRectangle(cornerRadius: 14))
    }
}
