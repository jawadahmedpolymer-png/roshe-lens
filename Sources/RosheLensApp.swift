import SwiftUI

@main
struct RosheLensApp: App {
    @State private var state = AppState.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(state)
                .preferredColorScheme(.dark)
        }
    }
}
