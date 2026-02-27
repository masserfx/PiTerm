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
    var isLoading = false

    private weak var sshSession: SSHSession?

    func attach(to session: SSHSession) {
        self.sshSession = session
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
        let safeName = repo.name
        let path = "~/projects/\(safeName)"
        let sessionName = "claude-\(safeName)"
        return "mkdir -p ~/projects && ([ -d \(path) ] && echo 'Repo already cloned, pulling...' && cd \(path) && git pull || git clone \(repo.url) \(path)) && tmux kill-session -t \(sessionName) 2>/dev/null; tmux new-session -d -s \(sessionName) -c \(path) 'claude' && tmux attach -t \(sessionName)\n"
    }

    /// Open project with Claude (already cloned)
    func openProject(name: String) -> String {
        let path = "~/projects/\(name)"
        let sessionName = "claude-\(name)"
        return "tmux kill-session -t \(sessionName) 2>/dev/null; cd \(path) && tmux new-session -d -s \(sessionName) -c \(path) 'claude' && tmux attach -t \(sessionName)\n"
    }
}
