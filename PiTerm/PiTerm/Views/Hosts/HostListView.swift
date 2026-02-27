#if os(iOS)
import SwiftUI
import SwiftData

/// Main host list with cards and quick connect
struct HostListView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SSHHost.lastConnected, order: .reverse) private var hosts: [SSHHost]

    @State private var showAddHost = false
    @State private var isConnecting = false
    @State private var connectingHost: SSHHost?
    @State private var errorMessage: String?
    @State private var passwordPrompt: SSHHost?
    @State private var enteredPassword = ""
    @State private var tailscaleService = TailscaleService()
    @State private var didAttemptAutoConnect = false

    var body: some View {
        Group {
            if hosts.isEmpty {
                emptyState
            } else {
                hostList
            }
        }
        .navigationTitle("Hosts")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddHost = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddHost) {
            NavigationStack {
                HostEditView()
            }
        }
        .sheet(item: $passwordPrompt) { host in
            NavigationStack {
                passwordPromptView(for: host)
            }
        }
        .alert("Connection Error", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .task {
            // Auto-connect to LAN host on first launch if not already connected
            guard !appState.isConnected, !isConnecting, !didAttemptAutoConnect else { return }
            didAttemptAutoConnect = true
            try? await Task.sleep(for: .seconds(1))
            guard !appState.isConnected, !isConnecting else { return }
            if let lanHost = hosts.first(where: { $0.hostname == "192.168.0.169" }) {
                print("[PiTerm] Auto-connecting to LAN host...")
                connectToHost(lanHost)
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Hosts", systemImage: "server.rack")
        } description: {
            Text("Add an SSH host to get started.\nUse the Raspberry Pi template for quick setup.")
        } actions: {
            Button {
                showAddHost = true
            } label: {
                Text("Add Host")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var hostList: some View {
        ScrollView {
            if !tailscaleService.isVPNActive {
                tailscaleBanner
            }

            LazyVStack(spacing: 8) {
                ForEach(hosts) { host in
                    HostCardView(
                        host: host,
                        tailscaleActive: tailscaleService.isVPNActive
                    ) {
                        connectToHost(host)
                    }
                    .contextMenu {
                        Button {
                            connectToHost(host)
                        } label: {
                            Label("Connect", systemImage: "arrow.right.circle")
                        }
                        Button(role: .destructive) {
                            modelContext.delete(host)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private var tailscaleBanner: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text("Tailscale VPN is not connected")
                .font(.caption)
            Spacer()
        }
        .padding(10)
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private func passwordPromptView(for host: SSHHost) -> some View {
        Form {
            Section("Enter password for \(host.username)@\(host.hostname)") {
                SecureField("Password", text: $enteredPassword)
                    .textContentType(.password)
            }
        }
        .navigationTitle("Authentication")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    passwordPrompt = nil
                    enteredPassword = ""
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Connect") {
                    let host = host
                    let password = enteredPassword
                    passwordPrompt = nil
                    enteredPassword = ""
                    performConnect(host: host, password: password)
                }
                .disabled(enteredPassword.isEmpty)
            }
        }
    }

    private func connectToHost(_ host: SSHHost) {
        let keychainAccount = "\(host.username)@\(host.hostname):\(host.port)"
        print("[PiTerm] connectToHost: \(host.hostname), keychain account: \(keychainAccount)")
        if let passwordData = try? KeychainHelper.load(service: "com.piterm.passwords", account: keychainAccount),
           let password = String(data: passwordData, encoding: .utf8) {
            print("[PiTerm] Password found in Keychain, connecting...")
            performConnect(host: host, password: password)
        } else {
            print("[PiTerm] No password in Keychain, showing prompt")
            passwordPrompt = host
        }
    }

    private func performConnect(host: SSHHost, password: String) {
        isConnecting = true
        connectingHost = host
        print("[PiTerm] performConnect to \(host.hostname):\(host.port) as \(host.username)")

        Task {
            do {
                let session = SSHSession()
                let termSize = (width: 80, height: 24)

                print("[PiTerm] Calling session.connect...")
                try await session.connect(
                    host: host.hostname,
                    port: host.port,
                    username: host.username,
                    password: password,
                    termSize: termSize,
                    onData: { data in
                        Task { @MainActor in
                            NotificationCenter.default.post(
                                name: .terminalDataReceived,
                                object: nil,
                                userInfo: ["data": data]
                            )
                        }
                    }
                )

                print("[PiTerm] SSH connected successfully!")
                await MainActor.run {
                    host.lastConnected = Date()
                    appState.activeSession = session
                    appState.activeHost = host
                    appState.isConnected = true
                    appState.selectedTab = .terminal
                    isConnecting = false
                }
            } catch {
                print("[PiTerm] SSH connection error: \(error)")
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isConnecting = false
                    connectingHost = nil
                }
            }
        }
    }
}

extension Notification.Name {
    static let terminalDataReceived = Notification.Name("terminalDataReceived")
}
#endif
