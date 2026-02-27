#if os(iOS)
import SwiftUI
import UIKit

/// App settings view
struct SettingsView: View {
    @Environment(AppState.self) private var appState

    @AppStorage("terminalFontSize") private var fontSize: Double = 12
    @AppStorage("hapticFeedback") private var hapticFeedback = true
    @AppStorage("autoReconnect") private var autoReconnect = true

    var body: some View {
        Form {
            Section("Terminal") {
                HStack {
                    Text("Font Size")
                    Spacer()
                    Text("\(Int(fontSize))")
                        .foregroundStyle(.secondary)
                }
                Slider(value: $fontSize, in: 8...24, step: 1)
            }

            Section("Connection") {
                Toggle("Auto-Reconnect", isOn: $autoReconnect)
                Toggle("Haptic Feedback", isOn: $hapticFeedback)
            }

            Section("Tailscale") {
                HStack {
                    Text("VPN Status")
                    Spacer()
                    Text(appState.tailscaleActive ? "Connected" : "Not Connected")
                        .foregroundStyle(appState.tailscaleActive ? .green : .red)
                }
            }

            Section("SSH Keys") {
                NavigationLink("Manage Keys") {
                    SSHKeyManagementView()
                }
            }

            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("License")
                    Spacer()
                    Text("MIT")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Settings")
    }
}

/// SSH Key management sub-view
struct SSHKeyManagementView: View {
    @State private var isGenerating = false
    @State private var keyName = ""
    @State private var generatedPublicKey: String?
    @State private var showAlert = false
    @State private var alertMessage = ""

    var body: some View {
        Form {
            Section("Generate New Key") {
                TextField("Key Name", text: $keyName)
                    .autocorrectionDisabled()

                Button {
                    generateKey()
                } label: {
                    if isGenerating {
                        ProgressView()
                    } else {
                        Label("Generate Ed25519 Key", systemImage: "key")
                    }
                }
                .disabled(keyName.isEmpty || isGenerating)
            }

            if let publicKey = generatedPublicKey {
                Section("Public Key") {
                    Text(publicKey)
                        .font(.system(size: 10, design: .monospaced))
                        .textSelection(.enabled)

                    Button {
                        UIPasteboard.general.string = publicKey
                    } label: {
                        Label("Copy to Clipboard", systemImage: "doc.on.doc")
                    }

                    Text("Add this key to ~/.ssh/authorized_keys on your server")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("SSH Keys")
        .alert("Key Generation", isPresented: $showAlert) {
            Button("OK") {}
        } message: {
            Text(alertMessage)
        }
    }

    private func generateKey() {
        isGenerating = true
        Task {
            do {
                let result = try SSHKeyManager.generateEd25519Key(name: keyName)
                let pubKeyString = SSHKeyManager.authorizedKeysFormat(
                    publicKey: result.publicKey,
                    comment: "piterm-\(keyName)"
                )
                await MainActor.run {
                    generatedPublicKey = pubKeyString
                    isGenerating = false
                }
            } catch {
                await MainActor.run {
                    alertMessage = "Failed to generate key: \(error.localizedDescription)"
                    showAlert = true
                    isGenerating = false
                }
            }
        }
    }
}
#endif
