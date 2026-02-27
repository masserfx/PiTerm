#if os(iOS)
import SwiftUI

/// Main terminal view combining SwiftTerm, extra keys bar and toolbar
struct TerminalContainerView: View {
    @Environment(AppState.self) private var appState

    @State private var terminalRef: TerminalViewReference?
    @State private var isConnecting = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            if appState.isConnected {
                // Terminal toolbar with Claude actions
                TerminalToolbar(
                    onCommand: { command in
                        sendCommand(command)
                    },
                    onDisconnect: {
                        disconnect()
                    }
                )

                // Terminal view
                TerminalRepresentable(
                    onData: { data in
                        sendData(data)
                    },
                    onSizeChanged: { cols, rows in
                        resizeTerminal(cols: cols, rows: rows)
                    },
                    terminalView: $terminalRef
                )

                // Extra keys bar
                ExtraKeysBar { key in
                    handleExtraKey(key)
                }
            } else {
                // Not connected placeholder
                ContentUnavailableView {
                    Label("No Connection", systemImage: "terminal")
                } description: {
                    if isConnecting {
                        ProgressView("Connecting...")
                    } else if let error = errorMessage {
                        Text(error)
                            .foregroundStyle(.red)
                    } else {
                        Text("Select a host to connect")
                    }
                } actions: {
                    if !isConnecting {
                        Button("Go to Hosts") {
                            appState.selectedTab = .hosts
                        }
                    }
                }
            }
        }
        .navigationTitle(appState.activeHost?.name ?? "Terminal")
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(NotificationCenter.default.publisher(for: .terminalDataReceived)) { notification in
            if let data = notification.userInfo?["data"] as? Data {
                terminalRef?.feed(data: data)
            }
        }
    }

    private func sendData(_ data: Data) {
        guard let session = appState.activeSession else { return }
        Task {
            try? await session.send(data)
        }
    }

    private func sendCommand(_ command: String) {
        sendData(Data(command.utf8))
    }

    private func handleExtraKey(_ key: ExtraKeysBar.ExtraKey) {
        guard !key.isModifier else { return }
        sendData(key.data)
    }

    private func resizeTerminal(cols: Int, rows: Int) {
        guard let session = appState.activeSession else { return }
        Task {
            try? await session.resize(width: cols, height: rows)
        }
    }

    private func disconnect() {
        guard let session = appState.activeSession else { return }
        Task {
            await session.disconnect()
            await MainActor.run {
                appState.isConnected = false
                appState.activeSession = nil
                appState.activeHost = nil
            }
        }
    }
}
#endif
