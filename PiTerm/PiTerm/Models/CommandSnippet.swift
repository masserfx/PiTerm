import Foundation
import SwiftData

@Model
final class CommandSnippet {
    var name: String
    var command: String
    var category: String
    var sortOrder: Int

    init(name: String, command: String, category: String = "General", sortOrder: Int = 0) {
        self.name = name
        self.command = command
        self.category = category
        self.sortOrder = sortOrder
    }

    static var claudeDefaults: [CommandSnippet] {
        [
            CommandSnippet(name: "New Claude Session", command: "tmux new-session -d -s claude 'claude' && tmux attach -t claude", category: "Claude"),
            CommandSnippet(name: "Attach Claude", command: "tmux attach -t claude", category: "Claude"),
            CommandSnippet(name: "List Sessions", command: "tmux list-sessions", category: "Claude"),
            CommandSnippet(name: "Claude Continue", command: "claude --continue", category: "Claude"),
            CommandSnippet(name: "Claude Status", command: "claude --version", category: "Claude"),
        ]
    }
}
