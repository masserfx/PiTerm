import Foundation

/// Pre-built Claude CLI commands for quick actions
enum ClaudeCommands {
    struct Command {
        let name: String
        let icon: String
        let command: String
    }

    static let sessionManagement: [Command] = [
        Command(
            name: "New Session",
            icon: "plus.circle",
            command: "tmux new-session -d -s claude 'claude' && tmux attach -t claude"
        ),
        Command(
            name: "Attach Session",
            icon: "arrow.right.circle",
            command: "tmux attach -t claude"
        ),
        Command(
            name: "List Sessions",
            icon: "list.bullet",
            command: "tmux list-sessions"
        ),
        Command(
            name: "Kill Session",
            icon: "xmark.circle",
            command: "tmux kill-session -t claude"
        ),
    ]

    static let claudeCLI: [Command] = [
        Command(
            name: "Continue",
            icon: "play.circle",
            command: "claude --continue"
        ),
        Command(
            name: "Resume",
            icon: "arrow.counterclockwise",
            command: "claude --resume"
        ),
        Command(
            name: "Version",
            icon: "info.circle",
            command: "claude --version"
        ),
    ]

    static let projectCommands: [Command] = [
        Command(
            name: "Git Status",
            icon: "arrow.triangle.branch",
            command: "git status"
        ),
        Command(
            name: "Git Log",
            icon: "clock",
            command: "git log --oneline -10"
        ),
    ]

    /// Create a tmux session for a specific project
    static func newProjectSession(name: String, path: String) -> String {
        "tmux new-session -d -s claude-\(name) -c \(path) 'claude' && tmux attach -t claude-\(name)"
    }

    /// Attach to a named tmux session
    static func attachSession(name: String) -> String {
        "tmux attach -t \(name)"
    }
}
