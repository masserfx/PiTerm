#if os(iOS)
import SwiftUI

/// Dashboard showing Claude tmux sessions on the connected host
struct ClaudeDashboardView: View {
    @Environment(AppState.self) private var appState
    @State private var sessionManager = ClaudeSessionManager()

    var body: some View {
        Group {
            if !appState.isConnected {
                ContentUnavailableView {
                    Label("Not Connected", systemImage: "wifi.slash")
                } description: {
                    Text("Connect to a host to manage Claude sessions")
                } actions: {
                    Button("Go to Hosts") {
                        appState.selectedTab = .hosts
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                sessionList
            }
        }
        .navigationTitle("Claude Sessions")
        .toolbar {
            if appState.isConnected {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        newClaudeSession()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .automatic) {
                    Button {
                        Task { await sessionManager.refreshSessions() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .task {
            if let session = appState.activeSession {
                sessionManager.attach(to: session)
                await sessionManager.refreshSessions()
            }
        }
    }

    private var sessionList: some View {
        List {
            Section("Active Sessions") {
                if sessionManager.sessions.isEmpty {
                    ContentUnavailableView {
                        Label("No Sessions", systemImage: "terminal")
                    } description: {
                        Text("No tmux sessions found. Create a new Claude session.")
                    }
                } else {
                    ForEach(sessionManager.sessions) { session in
                        sessionRow(session)
                    }
                }
            }

            Section("Quick Actions") {
                ForEach(ClaudeCommands.sessionManagement, id: \.name) { cmd in
                    Button {
                        sendCommand(cmd.command + "\n")
                        appState.selectedTab = .terminal
                    } label: {
                        Label(cmd.name, systemImage: cmd.icon)
                    }
                }
            }
        }
    }

    private func sessionRow(_ session: ClaudeSessionManager.TmuxSession) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(session.name)
                        .font(.headline)
                    if session.isClaude {
                        Image(systemName: "brain")
                            .font(.caption)
                            .foregroundStyle(.purple)
                    }
                }
                Text(session.created)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if session.attached {
                Text("Attached")
                    .font(.caption)
                    .foregroundStyle(.green)
            }

            Button("Attach") {
                sendCommand(sessionManager.attachToSession(name: session.name))
                appState.selectedTab = .terminal
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private func newClaudeSession() {
        let command = sessionManager.createClaudeSession()
        sendCommand(command)
        appState.selectedTab = .terminal
    }

    private func sendCommand(_ command: String) {
        guard let session = appState.activeSession else { return }
        Task {
            try? await session.send(Data(command.utf8))
        }
    }
}
#endif
