#if os(iOS)
import SwiftUI
import SwiftData

@main
struct PiTermApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
        }
        .modelContainer(for: [
            SSHHost.self,
            SSHKey.self,
            HostGroup.self,
            CommandSnippet.self,
        ])
    }
}
#endif
