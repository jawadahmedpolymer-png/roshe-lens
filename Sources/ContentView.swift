import SwiftUI
import Translation

extension Color {
    static let gold = Color(red: 0.83, green: 0.66, blue: 0.31)
    static let goldLight = Color(red: 0.95, green: 0.83, blue: 0.53)
    static let ink = Color(red: 0.04, green: 0.04, blue: 0.03)
    static let panel = Color(red: 0.09, green: 0.08, blue: 0.055)
}

struct ContentView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state
        NavigationStack {
            Group {
                if let image = state.image {
                    ResultView(image: image)
                } else {
                    HomeView()
                }
            }
            .background(Color.ink.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        Image("Logo").resizable().frame(width: 28, height: 28).clipShape(Circle())
                        Text("ROSHE LENS")
                            .font(.system(size: 17, weight: .bold, design: .serif))
                            .tracking(2)
                            .foregroundStyle(LinearGradient(colors: [.goldLight, .gold], startPoint: .top, endPoint: .bottom))
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Translate into", selection: $state.target) {
                            ForEach(TargetLanguage.all) { Text($0.name).tag($0.id) }
                        }
                    } label: {
                        Image(systemName: "globe").foregroundStyle(Color.gold)
                    }
                }
            }
            .toolbarBackground(Color.ink, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .translationTask(state.config) { session in
            await state.translate(using: session)
        }
        .tint(.gold)
    }
}

struct HomeView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Image("Logo").resizable().scaledToFit().frame(width: 140)
                    .clipShape(Circle())
                    .shadow(color: .gold.opacity(0.4), radius: 20)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)
                Text("Tap AssistiveTouch in any app to translate the screen.")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                VStack(alignment: .leading, spacing: 10) {
                    step("1", "In Shortcuts, make a shortcut with Take Screenshot, then Translate Screen (Roshe Lens).")
                    step("2", "Settings › Accessibility › Touch › AssistiveTouch › Single-Tap › choose that shortcut.")
                    step("3", "Open Taobao, Meituan or WeChat and tap the floating button.")
                }
                .padding(16)
                .background(Color.panel, in: RoundedRectangle(cornerRadius: 14))
                Text("Translation runs on your iPhone with Apple's translator. No account, no fees, no VPN.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
        }
    }

    private func step(_ n: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(n).font(.headline).foregroundStyle(Color.ink)
                .frame(width: 26, height: 26)
                .background(Color.gold, in: Circle())
            Text(text).foregroundStyle(.white.opacity(0.9))
        }
    }
}

struct ResultView: View {
    @Environment(AppState.self) private var state
    let image: UIImage

    var body: some View {
        @Bindable var state = state
        ScrollView {
            VStack(spacing: 12) {
                statusBar
                Picker("View", selection: $state.showOriginal) {
                    Text("Translated").tag(false)
                    Text("Original").tag(true)
                }
                .pickerStyle(.segmented)
                OverlayView(image: image, blocks: state.blocks, showOriginal: state.showOriginal) {
                    state.selected = $0
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
                lineList
            }
            .padding(14)
        }
        .sheet(item: $state.selected) { b in
            VStack(alignment: .leading, spacing: 10) {
                Text(b.original).font(.title2)
                Text(b.translated ?? "…").font(.title3.weight(.semibold)).foregroundStyle(Color.goldLight)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .presentationDetents([.height(180)])
        }
    }

    @ViewBuilder private var statusBar: some View {
        switch state.phase {
        case .reading:
            Label("Reading the screen…", systemImage: "text.viewfinder").statusStyle()
        case .translating:
            Label("Translating…", systemImage: "character.bubble").statusStyle()
        case .failed(let msg):
            Label(msg, systemImage: "exclamationmark.triangle").statusStyle()
        default:
            EmptyView()
        }
    }

    private var lineList: some View {
        VStack(spacing: 0) {
            ForEach(state.blocks) { b in
                VStack(alignment: .leading, spacing: 2) {
                    Text(b.original).foregroundStyle(.white.opacity(0.75))
                    Text(b.translated ?? "…").fontWeight(.semibold).foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8).padding(.horizontal, 12)
                Divider().overlay(Color.gold.opacity(0.2))
            }
        }
        .background(Color.panel, in: RoundedRectangle(cornerRadius: 12))
    }
}

extension View {
    func statusStyle() -> some View {
        self.font(.subheadline)
            .foregroundStyle(Color.goldLight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(Color.panel, in: RoundedRectangle(cornerRadius: 10))
    }
}

/// The screenshot with each line of Chinese covered by its translation.
struct OverlayView: View {
    let image: UIImage
    let blocks: [TextBlock]
    let showOriginal: Bool
    let onTap: (TextBlock) -> Void

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .overlay {
                GeometryReader { geo in
                    if !showOriginal {
                        ForEach(blocks) { b in
                            if let t = b.translated {
                                let r = CGRect(x: b.rect.minX * geo.size.width,
                                               y: b.rect.minY * geo.size.height,
                                               width: b.rect.width * geo.size.width,
                                               height: b.rect.height * geo.size.height)
                                    .insetBy(dx: -2, dy: -1.5)
                                Text(t)
                                    .font(.system(size: max(7, r.height * 0.78), weight: .semibold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.25)
                                    .foregroundStyle(Color(uiColor: b.foreground))
                                    .padding(.horizontal, 1)
                                    .frame(width: r.width, height: r.height, alignment: .leading)
                                    .background(Color(uiColor: b.background))
                                    .position(x: r.midX, y: r.midY)
                                    .onTapGesture { onTap(b) }
                            }
                        }
                    }
                }
            }
    }
}
