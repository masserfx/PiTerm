#if os(iOS)
import SwiftUI

/// View for creating a GitHub issue that triggers Claude Code Action
struct CreateIssueView: View {
    let repos: [GitHubRepo]
    let gitHubUser: String
    let onCreated: (Int, String) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var selectedRepo: GitHubRepo?
    @State private var title = ""
    @State private var issueBody = ""
    @State private var triggerClaude = true
    @State private var isCreating = false
    @State private var errorMessage: String?

    private let github = GitHubService.shared

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Repository", selection: $selectedRepo) {
                        Text("Select repo...").tag(GitHubRepo?.none)
                        ForEach(repos) { repo in
                            Text(repo.name).tag(GitHubRepo?.some(repo))
                        }
                    }
                } header: {
                    Text("Repository")
                }

                Section {
                    TextField("Issue title", text: $title)
                        .autocorrectionDisabled()

                    ZStack(alignment: .topLeading) {
                        if issueBody.isEmpty {
                            Text("Describe what you want Claude to implement...")
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8)
                        }
                        TextEditor(text: $issueBody)
                            .frame(minHeight: 120)
                    }
                } header: {
                    Text("Issue")
                } footer: {
                    Text("Be specific: describe the feature, bug fix, or change you want.")
                }

                Section {
                    Toggle(isOn: $triggerClaude) {
                        HStack {
                            Image(systemName: "brain")
                                .foregroundStyle(.purple)
                            Text("Trigger Claude Code")
                        }
                    }
                } footer: {
                    Text(triggerClaude
                        ? "Adds 'claude' label — GitHub Action will pick this up and create a PR automatically."
                        : "Creates a regular issue without triggering Claude.")
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("New Issue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        createIssue()
                    } label: {
                        if isCreating {
                            ProgressView()
                        } else {
                            Text("Create")
                        }
                    }
                    .disabled(selectedRepo == nil || title.isEmpty || isCreating)
                }
            }
        }
    }

    private func createIssue() {
        guard let repo = selectedRepo else { return }
        guard github.isAuthenticated else {
            errorMessage = "GitHub token not set. Go to Settings to add it."
            return
        }

        isCreating = true
        errorMessage = nil

        Task {
            do {
                if triggerClaude {
                    await github.ensureClaudeLabel(owner: gitHubUser, repo: repo.name)
                }

                let result = try await github.createIssue(
                    owner: gitHubUser,
                    repo: repo.name,
                    title: title,
                    body: issueBody,
                    addClaudeLabel: triggerClaude
                )

                await MainActor.run {
                    isCreating = false
                    onCreated(result.number, result.htmlUrl)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isCreating = false
                }
            }
        }
    }
}
#endif
