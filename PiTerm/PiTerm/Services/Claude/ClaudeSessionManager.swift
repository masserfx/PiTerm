import Foundation

/// Manages Claude CLI sessions running in tmux on the remote host
@Observable
final class ClaudeSessionManager {
    struct TmuxSession: Identifiable {
        let id: String
        let name: String
        let created: String
        let attached: Bool
        let isClaude: Bool
    }

    var sessions: [TmuxSession] = []
    var repos: [GitHubRepo] = []
    var clonedProjects: Set<String> = []
    var isLoading = false
    var isLoadingRepos = false

    private weak var sshSession: SSHSession?

    /// Buffer to capture SSH output for parsing
    private var outputBuffer = ""
    private var captureCompletion: ((String) -> Void)?
    private var captureMarker: String?

    func attach(to session: SSHSession) {
        self.sshSession = session
    }

    // MARK: - Command Execution with Output Capture

    /// Send a command and capture the output between markers
    func executeAndCapture(_ command: String) async -> String? {
        guard let ssh = sshSession else { return nil }

        let marker = "___PITERM_\(UUID().uuidString.prefix(8))___"
        outputBuffer = ""
        captureMarker = marker

        return await withCheckedContinuation { continuation in
            captureCompletion = { output in
                continuation.resume(returning: output)
            }

            let wrappedCommand = "echo '\(marker)_START'; \(command); echo '\(marker)_END'\n"
            Task {
                try? await ssh.send(Data(wrappedCommand.utf8))

                // Timeout after 10 seconds
                try? await Task.sleep(for: .seconds(10))
                if self.captureMarker != nil {
                    self.captureMarker = nil
                    self.captureCompletion = nil
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    /// Feed terminal output for parsing (call from data handler)
    func feedOutput(_ text: String) {
        guard let marker = captureMarker else { return }
        outputBuffer += text

        let startMarker = "\(marker)_START"
        let endMarker = "\(marker)_END"

        if let startRange = outputBuffer.range(of: startMarker),
           let endRange = outputBuffer.range(of: endMarker) {
            let captured = String(outputBuffer[startRange.upperBound..<endRange.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            captureMarker = nil
            let completion = captureCompletion
            captureCompletion = nil
            completion?(captured)
        }
    }

    // MARK: - Tmux Sessions

    func refreshSessions() async {
        guard let ssh = sshSession else { return }

        isLoading = true
        defer { isLoading = false }

        let command = "tmux list-sessions -F '#{session_name}|#{session_created_string}|#{session_attached}' 2>/dev/null\n"
        do {
            try await ssh.send(Data(command.utf8))
        } catch {
            sessions = []
        }
    }

    func parseSessions(from output: String) {
        let lines = output.components(separatedBy: "\n")
        sessions = lines.compactMap { line in
            let parts = line.components(separatedBy: "|")
            guard parts.count >= 3 else { return nil }

            let name = parts[0].trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { return nil }

            return TmuxSession(
                id: name,
                name: name,
                created: parts[1],
                attached: parts[2] == "1",
                isClaude: name.hasPrefix("claude")
            )
        }
    }

    // MARK: - GitHub Repos

    /// Fetch repos from GitHub via gh CLI on the remote host
    func fetchRepos() async {
        guard let ssh = sshSession else { return }

        isLoadingRepos = true
        defer { isLoadingRepos = false }

        // Send gh repo list command — output goes to terminal, we parse it via marker
        if let output = await executeAndCapture("gh repo list --json name,description,url --limit 30 2>/dev/null") {
            parseRepos(from: output)
        }

        // Check which projects are already cloned
        if let output = await executeAndCapture("ls ~/projects 2>/dev/null") {
            let dirs = output.components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            clonedProjects = Set(dirs)
        }
    }

    private func parseRepos(from json: String) {
        // Find the JSON array in the output
        guard let start = json.firstIndex(of: "["),
              let end = json.lastIndex(of: "]") else {
            return
        }
        let jsonStr = String(json[start...end])
        guard let data = jsonStr.data(using: .utf8) else { return }

        do {
            repos = try JSONDecoder().decode([GitHubRepo].self, from: data)
        } catch {
            print("[PiTerm] Failed to parse repos: \(error)")
        }
    }

    // MARK: - Commands

    func createClaudeSession(projectName: String? = nil) -> String {
        let sessionName = projectName.map { "claude-\($0)" } ?? "claude"
        return "tmux new-session -d -s \(sessionName) 'claude' && tmux attach -t \(sessionName)\n"
    }

    func attachToSession(name: String) -> String {
        "tmux attach -t \(name)\n"
    }

    /// Clone a repo and start Claude in it
    func cloneAndStartClaude(repo: GitHubRepo) -> String {
        let safeName = repo.name.replacingOccurrences(of: " ", with: "-")
        let path = "~/projects/\(safeName)"
        let sessionName = "claude-\(safeName)"
        return """
        mkdir -p ~/projects && \
        ([ -d \(path) ] && echo 'Repo already cloned, pulling latest...' && cd \(path) && git pull || gh repo clone \(repo.url) \(path)) && \
        tmux kill-session -t \(sessionName) 2>/dev/null; \
        tmux new-session -d -s \(sessionName) -c \(path) 'claude' && \
        tmux attach -t \(sessionName)\n
        """
    }

    /// Open project with Claude (already cloned)
    func openProject(name: String) -> String {
        let path = "~/projects/\(name)"
        let sessionName = "claude-\(name)"
        return """
        tmux kill-session -t \(sessionName) 2>/dev/null; \
        cd \(path) && tmux new-session -d -s \(sessionName) -c \(path) 'claude' && \
        tmux attach -t \(sessionName)\n
        """
    }
}
