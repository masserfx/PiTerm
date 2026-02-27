#if os(iOS)
import SwiftUI

/// Dashboard showing Claude tmux sessions and GitHub repos for cloning
struct ClaudeDashboardView: View {
    @Environment(AppState.self) private var appState
    @State private var sessionManager = ClaudeSessionManager()
    @State private var searchText = ""

    var body: some View {
        Group {
            if !appState.isConnected {
                notConnectedView
            } else {
                mainContent
            }
        }
        .navigationTitle("Claude")
        .toolbar {
            if appState.isConnected {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await refreshAll() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .task {
            if let session = appState.activeSession {
                sessionManager.attach(to: session)
                await refreshAll()
            }
        }
        .onChange(of: appState.isConnected) { _, connected in
            if connected, let session = appState.activeSession {
                sessionManager.attach(to: session)
                Task { await refreshAll() }
            }
        }
    }

    private var notConnectedView: some View {
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
    }

    private var mainContent: some View {
        List {
            // Active tmux sessions
            if !sessionManager.sessions.isEmpty {
                sessionsSection
            }

            // Cloned projects ready to use
            if !clonedProjects.isEmpty {
                clonedProjectsSection
            }

            // GitHub repos available to clone
            reposSection

            // Quick Actions
            quickActionsSection
        }
        .searchable(text: $searchText, prompt: "Search repos...")
        .refreshable {
            await refreshAll()
        }
    }

    // MARK: - Sessions Section

    private var sessionsSection: some View {
        Section {
            ForEach(sessionManager.sessions) { session in
                sessionRow(session)
            }
        } header: {
            Label("Active Sessions", systemImage: "terminal")
        }
    }

    private func sessionRow(_ session: ClaudeSessionManager.TmuxSession) -> some View {
        Button {
            sendCommand(sessionManager.attachToSession(name: session.name))
            appState.selectedTab = .terminal
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(session.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
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
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.green.opacity(0.2))
                        .foregroundStyle(.green)
                        .clipShape(Capsule())
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Cloned Projects Section

    private var clonedProjects: [String] {
        let cloned = Array(sessionManager.clonedProjects).sorted()
        if searchText.isEmpty { return cloned }
        return cloned.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    private var clonedProjectsSection: some View {
        Section {
            ForEach(clonedProjects, id: \.self) { name in
                Button {
                    sendCommand(sessionManager.openProject(name: name))
                    appState.selectedTab = .terminal
                } label: {
                    HStack {
                        Image(systemName: "folder.fill")
                            .foregroundStyle(.blue)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(name)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text("~/projects/\(name)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("Open")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                }
            }
        } header: {
            Label("Projects on RPi", systemImage: "folder")
        }
    }

    // MARK: - Repos Section

    private var filteredRepos: [GitHubRepo] {
        let available = sessionManager.repos.filter { !sessionManager.clonedProjects.contains($0.name) }
        if searchText.isEmpty { return available }
        return available.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.description.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var reposSection: some View {
        Section {
            if sessionManager.isLoadingRepos {
                HStack {
                    ProgressView()
                    Text("Loading repos...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else if filteredRepos.isEmpty {
                if searchText.isEmpty {
                    Text("No repos found")
                        .foregroundStyle(.secondary)
                } else {
                    Text("No matching repos")
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(filteredRepos) { repo in
                    repoRow(repo)
                }
            }
        } header: {
            Label("GitHub Repos", systemImage: "cloud")
        } footer: {
            if !sessionManager.repos.isEmpty {
                Text("\(sessionManager.repos.count) repos available")
            }
        }
    }

    private func repoRow(_ repo: GitHubRepo) -> some View {
        Button {
            sendCommand(sessionManager.cloneAndStartClaude(repo: repo))
            appState.selectedTab = .terminal
        } label: {
            HStack {
                Image(systemName: "arrow.down.circle")
                    .foregroundStyle(.orange)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(repo.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    if !repo.description.isEmpty {
                        Text(repo.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                Spacer()
                Text("Clone")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        Section {
            ForEach(ClaudeCommands.claudeCLI, id: \.name) { cmd in
                Button {
                    sendCommand(cmd.command + "\n")
                    appState.selectedTab = .terminal
                } label: {
                    Label(cmd.name, systemImage: cmd.icon)
                }
            }
        } header: {
            Label("Quick Actions", systemImage: "bolt")
        }
    }

    // MARK: - Helpers

    private func refreshAll() async {
        if let session = appState.activeSession {
            sessionManager.attach(to: session)
        }
        await sessionManager.refreshSessions()
        await sessionManager.fetchRepos()
    }

    private func sendCommand(_ command: String) {
        guard let session = appState.activeSession else { return }
        Task {
            try? await session.send(Data(command.utf8))
        }
    }
}
#endif
