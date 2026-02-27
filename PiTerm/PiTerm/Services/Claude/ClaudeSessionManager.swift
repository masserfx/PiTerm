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

    /// List all tmux sessions on the remote host
    func refreshSessions() async {
        guard let ssh = sshSession else { return }

        isLoading = true
        defer { isLoading = false }

        // Send tmux list-sessions command and parse output
        let command = "tmux list-sessions -F '#{session_name}|#{session_created_string}|#{session_attached}' 2>/dev/null\n"
        do {
            try await ssh.send(Data(command.utf8))
        } catch {
            sessions = []
        }
    }

    /// Parse tmux list-sessions output
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

    /// Create a new Claude session in tmux
    func createClaudeSession(projectName: String? = nil) -> String {
        let sessionName = projectName.map { "claude-\($0)" } ?? "claude"
        return "tmux new-session -d -s \(sessionName) 'claude' && tmux attach -t \(sessionName)\n"
    }

    /// Attach to an existing tmux session
    func attachToSession(name: String) -> String {
        "tmux attach -t \(name)\n"
    }
}
