#if os(iOS)
import SwiftUI

/// Dashboard showing Claude sessions, GitHub repos and issues
struct ClaudeDashboardView: View {
    @Environment(AppState.self) private var appState
    @State private var sessionManager = ClaudeSessionManager()
    @State private var searchText = ""
    @State private var showCreateIssue = false
    @State private var repos: [GitHubRepo] = []
    @State private var issues: [GitHubService.Issue] = []
    @State private var isLoadingRepos = false
    @State private var isLoadingIssues = false
    @State private var createdIssueURL: String?
    @State private var selectedRepoForIssues: String = "PiTerm"

    private let github = GitHubService.shared
    private let gitHubUser = "masserfx"

    var body: some View {
        Group {
            if !github.isAuthenticated {
                tokenRequiredView
            } else {
                mainContent
            }
        }
        .navigationTitle("Claude")
        .toolbar {
            if github.isAuthenticated {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showCreateIssue = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .automatic) {
                    Button {
                        Task { await refreshAll() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .sheet(isPresented: $showCreateIssue) {
            CreateIssueView(repos: repos, gitHubUser: gitHubUser) { number, url in
                createdIssueURL = url
                Task { await loadIssues() }
            }
        }
        .alert("Issue Created", isPresented: .init(
            get: { createdIssueURL != nil },
            set: { if !$0 { createdIssueURL = nil } }
        )) {
            Button("OK") { createdIssueURL = nil }
        } message: {
            Text("Issue created. Claude will pick it up shortly.")
        }
        .task {
            if github.isAuthenticated {
                await refreshAll()
            }
            if let session = appState.activeSession {
                sessionManager.attach(to: session)
                await sessionManager.refreshSessions()
            }
        }
        .onChange(of: appState.isConnected) { _, connected in
            if connected, let session = appState.activeSession {
                sessionManager.attach(to: session)
                Task { await sessionManager.refreshSessions() }
            }
        }
    }

    private var tokenRequiredView: some View {
        ContentUnavailableView {
            Label("GitHub Token Required", systemImage: "key")
        } description: {
            Text("Add your GitHub personal access token in Settings to create issues and trigger Claude.")
        } actions: {
            Button("Go to Settings") {
                appState.selectedTab = .settings
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var mainContent: some View {
        List {
            // Active tmux sessions (if SSH connected)
            if appState.isConnected && !sessionManager.sessions.isEmpty {
                sessionsSection
            }

            // Open issues with Claude label
            issuesSection

            // GitHub repos
            reposSection

            // Quick actions (if SSH connected)
            if appState.isConnected {
                quickActionsSection
            }
        }
        .searchable(text: $searchText, prompt: "Search repos & issues...")
        .refreshable {
            await refreshAll()
        }
    }

    // MARK: - Issues Section

    private var filteredIssues: [GitHubService.Issue] {
        if searchText.isEmpty { return issues }
        return issues.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            ($0.body ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    private var issuesSection: some View {
        Section {
            if isLoadingIssues {
                HStack {
                    ProgressView()
                    Text("Loading issues...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else if filteredIssues.isEmpty {
                Button {
                    showCreateIssue = true
                } label: {
                    Label("Create your first issue for Claude", systemImage: "plus.circle")
                        .foregroundStyle(.purple)
                }
            } else {
                ForEach(filteredIssues) { issue in
                    issueRow(issue)
                }
            }
        } header: {
            HStack {
                Label("Issues — \(selectedRepoForIssues)", systemImage: "exclamationmark.circle")
                Spacer()
                Menu {
                    ForEach(repos) { repo in
                        Button(repo.name) {
                            selectedRepoForIssues = repo.name
                            Task { await loadIssues() }
                        }
                    }
                } label: {
                    Image(systemName: "chevron.down.circle")
                        .font(.caption)
                }
            }
        }
    }

    private func issueRow(_ issue: GitHubService.Issue) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "circle.fill")
                    .font(.system(size: 6))
                    .foregroundStyle(.green)
                Text("#\(issue.number)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(issue.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
            }

            HStack(spacing: 4) {
                ForEach(issue.labels, id: \.name) { label in
                    Text(label.name)
                        .font(.caption2)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(label.name == "claude" ? Color.purple.opacity(0.2) : Color.gray.opacity(0.15))
                        .foregroundStyle(label.name == "claude" ? .purple : .secondary)
                        .clipShape(Capsule())
                }
            }

            if let body = issue.body, !body.isEmpty {
                Text(body)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Sessions Section

    private var sessionsSection: some View {
        Section {
            ForEach(sessionManager.sessions) { session in
                Button {
                    sendSSH(sessionManager.attachToSession(name: session.name))
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
        } header: {
            Label("Active Sessions", systemImage: "terminal")
        }
    }

    // MARK: - Repos Section

    private var filteredRepos: [GitHubRepo] {
        if searchText.isEmpty { return repos }
        return repos.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.description.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var reposSection: some View {
        Section {
            if isLoadingRepos {
                HStack {
                    ProgressView()
                    Text("Loading repos...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else if filteredRepos.isEmpty {
                Text("No repos found")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(filteredRepos) { repo in
                    repoRow(repo)
                }
            }
        } header: {
            Label("GitHub Repos", systemImage: "cloud")
        } footer: {
            if !repos.isEmpty {
                Text("\(repos.count) repos")
            }
        }
    }

    private func repoRow(_ repo: GitHubRepo) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(repo.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                if !repo.description.isEmpty {
                    Text(repo.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            if appState.isConnected {
                Button {
                    sendSSH(sessionManager.cloneAndStartClaude(repo: repo))
                    appState.selectedTab = .terminal
                } label: {
                    Text("Clone")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        Section {
            ForEach(ClaudeCommands.claudeCLI, id: \.name) { cmd in
                Button {
                    sendSSH(cmd.command + "\n")
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
        async let r: () = loadRepos()
        async let i: () = loadIssues()
        _ = await (r, i)
    }

    private func loadRepos() async {
        isLoadingRepos = true
        defer { isLoadingRepos = false }
        repos = (try? await github.fetchRepos(user: gitHubUser)) ?? []
    }

    private func loadIssues() async {
        isLoadingIssues = true
        defer { isLoadingIssues = false }
        issues = (try? await github.fetchIssues(owner: gitHubUser, repo: selectedRepoForIssues)) ?? []
    }

    private func sendSSH(_ command: String) {
        guard let session = appState.activeSession else { return }
        Task {
            try? await session.send(Data(command.utf8))
        }
    }
}
#endif
