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
    @State private var issueFilter: IssueFilter = .open
    @State private var pollTimer: Timer?
    @State private var apiError: String?

    enum IssueFilter: String, CaseIterable {
        case open = "Open"
        case closed = "Closed"
        case all = "All"

        var apiState: String {
            switch self {
            case .open: return "open"
            case .closed: return "closed"
            case .all: return "all"
            }
        }
    }

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
            github.loadToken()
            if github.isAuthenticated {
                await refreshAll()
            }
            if let session = appState.activeSession {
                sessionManager.attach(to: session)
                await sessionManager.refreshSessions()
            }
            startPolling()
        }
        .onDisappear {
            stopPolling()
        }
        .onChange(of: appState.isConnected) { _, connected in
            if connected, let session = appState.activeSession {
                sessionManager.attach(to: session)
                Task { await sessionManager.refreshSessions() }
            }
        }
        .onChange(of: issueFilter) { _, _ in
            Task { await loadIssues() }
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
            // API error (debug)
            if let apiError {
                Section {
                    Text(apiError)
                        .font(.caption)
                        .foregroundStyle(.red)
                } header: {
                    Label("API Error", systemImage: "exclamationmark.triangle")
                }
            }

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
            // Filter picker
            Picker("Filter", selection: $issueFilter) {
                ForEach(IssueFilter.allCases, id: \.self) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))

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
                statusIcon(for: issue.workflowStatus)
                Text("#\(issue.number)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(issue.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
            }

            HStack(spacing: 4) {
                // Workflow status badge
                statusBadge(for: issue.workflowStatus)

                ForEach(issue.labels, id: \.name) { label in
                    Text(label.name)
                        .font(.caption2)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(label.name == "claude" ? Color.purple.opacity(0.2) : Color.gray.opacity(0.15))
                        .foregroundStyle(label.name == "claude" ? .purple : .secondary)
                        .clipShape(Capsule())
                }

                // PR link
                if let prUrl = issue.pullRequest?.htmlUrl {
                    Link(destination: URL(string: prUrl)!) {
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.triangle.pull")
                                .font(.caption2)
                            Text("PR")
                                .font(.caption2)
                        }
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.blue.opacity(0.15))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())
                    }
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

    @ViewBuilder
    private func statusIcon(for status: GitHubService.WorkflowStatus) -> some View {
        switch status {
        case .open:
            Image(systemName: "circle")
                .font(.system(size: 10))
                .foregroundStyle(.green)
        case .claudeWorking:
            Image(systemName: "brain")
                .font(.system(size: 10))
                .foregroundStyle(.purple)
                .symbolEffect(.pulse)
        case .prReady:
            Image(systemName: "arrow.triangle.pull")
                .font(.system(size: 10))
                .foregroundStyle(.blue)
        case .merged:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 10))
                .foregroundStyle(.purple)
        case .closed:
            Image(systemName: "circle.slash")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func statusBadge(for status: GitHubService.WorkflowStatus) -> some View {
        let (text, bg, fg): (String, Color, Color) = switch status {
        case .open: ("Open", .green.opacity(0.15), .green)
        case .claudeWorking: ("Claude working", .purple.opacity(0.15), .purple)
        case .prReady: ("PR Ready", .blue.opacity(0.15), .blue)
        case .merged: ("Merged", .purple.opacity(0.15), .purple)
        case .closed: ("Closed", .gray.opacity(0.15), .secondary)
        }
        Text(text)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(bg)
            .foregroundStyle(fg)
            .clipShape(Capsule())
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
        do {
            repos = try await github.fetchRepos(user: gitHubUser)
            apiError = nil
        } catch {
            repos = []
            apiError = "Repos: \(error.localizedDescription)"
        }
    }

    private func loadIssues() async {
        isLoadingIssues = true
        defer { isLoadingIssues = false }
        do {
            issues = try await github.fetchIssues(owner: gitHubUser, repo: selectedRepoForIssues, state: issueFilter.apiState)
        } catch {
            issues = []
            apiError = "Issues: \(error.localizedDescription)"
        }
    }

    private func startPolling() {
        stopPolling()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            Task { @MainActor in
                // Only auto-refresh if there are active Claude issues
                let hasActiveWork = issues.contains { $0.workflowStatus == .claudeWorking }
                if hasActiveWork {
                    await loadIssues()
                }
            }
        }
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func sendSSH(_ command: String) {
        guard let session = appState.activeSession else { return }
        Task {
            try? await session.send(Data(command.utf8))
        }
    }
}
#endif
