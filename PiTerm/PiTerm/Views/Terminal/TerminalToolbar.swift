#if os(iOS)
import SwiftUI
import UIKit

/// Toolbar with Claude quick actions and terminal controls
struct TerminalToolbar: View {
    let onCommand: (String) -> Void
    let onDisconnect: () -> Void

    @State private var showCommands = false

    var body: some View {
        HStack(spacing: 12) {
            // Claude quick actions
            Menu {
                Section("Claude") {
                    ForEach(ClaudeCommands.sessionManagement, id: \.name) { cmd in
                        Button {
                            onCommand(cmd.command + "\n")
                        } label: {
                            Label(cmd.name, systemImage: cmd.icon)
                        }
                    }
                }
                Section("CLI") {
                    ForEach(ClaudeCommands.claudeCLI, id: \.name) { cmd in
                        Button {
                            onCommand(cmd.command + "\n")
                        } label: {
                            Label(cmd.name, systemImage: cmd.icon)
                        }
                    }
                }
                Section("Git") {
                    ForEach(ClaudeCommands.projectCommands, id: \.name) { cmd in
                        Button {
                            onCommand(cmd.command + "\n")
                        } label: {
                            Label(cmd.name, systemImage: cmd.icon)
                        }
                    }
                }
            } label: {
                Label("Claude", systemImage: "brain")
                    .font(.system(size: 14, weight: .medium))
            }

            Spacer()

            // Disconnect button
            Button(role: .destructive) {
                onDisconnect()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(UIColor.systemGray6))
    }
}
#endif
