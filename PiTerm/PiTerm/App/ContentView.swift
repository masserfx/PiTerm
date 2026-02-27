#if os(iOS)
import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState

        TabView(selection: $state.selectedTab) {
            Tab("Hosts", systemImage: "server.rack", value: .hosts) {
                NavigationStack {
                    HostListView()
                }
            }

            Tab("Terminal", systemImage: "terminal", value: .terminal) {
                NavigationStack {
                    TerminalContainerView()
                }
            }

            Tab("Claude", systemImage: "brain", value: .claude) {
                NavigationStack {
                    ClaudeDashboardView()
                }
            }

            Tab("Settings", systemImage: "gear", value: .settings) {
                NavigationStack {
                    SettingsView()
                }
            }
        }
    }
}
#endif
