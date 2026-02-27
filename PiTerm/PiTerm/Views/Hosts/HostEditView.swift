#if os(iOS)
import SwiftUI
import SwiftData

/// Form for adding or editing an SSH host
struct HostEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let existingHost: SSHHost?

    @State private var name: String
    @State private var hostname: String
    @State private var port: Int
    @State private var username: String
    @State private var authMethod: SSHHost.AuthMethod
    @State private var password: String = ""
    @State private var isTailscale: Bool

    init(host: SSHHost? = nil) {
        self.existingHost = host
        _name = State(initialValue: host?.name ?? "")
        _hostname = State(initialValue: host?.hostname ?? "")
        _port = State(initialValue: host?.port ?? 22)
        _username = State(initialValue: host?.username ?? "pi")
        _authMethod = State(initialValue: host?.authMethod ?? .password)
        _isTailscale = State(initialValue: host?.isTailscale ?? false)
    }

    var body: some View {
        Form {
            Section("Connection") {
                TextField("Name", text: $name)
                    .textContentType(.name)

                TextField("Hostname", text: $hostname)
                    .textContentType(.URL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                HStack {
                    Text("Port")
                    Spacer()
                    TextField("22", value: $port, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }

                TextField("Username", text: $username)
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            Section("Authentication") {
                Picker("Method", selection: $authMethod) {
                    Text("Password").tag(SSHHost.AuthMethod.password)
                    Text("Public Key").tag(SSHHost.AuthMethod.publicKey)
                }

                if authMethod == .password {
                    SecureField("Password", text: $password)
                        .textContentType(.password)
                }
            }

            Section {
                Toggle("Tailscale Host", isOn: $isTailscale)
            } footer: {
                if isTailscale {
                    Text("This host is accessible via Tailscale VPN. Make sure the Tailscale app is connected.")
                }
            }

            if existingHost == nil {
                Section {
                    Button {
                        applyRaspberryPiTemplate()
                    } label: {
                        Label("Use Raspberry Pi Template", systemImage: "cpu")
                    }
                }
            }
        }
        .navigationTitle(existingHost == nil ? "Add Host" : "Edit Host")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(name.isEmpty || hostname.isEmpty || username.isEmpty)
            }
        }
    }

    private func save() {
        if let existing = existingHost {
            existing.name = name
            existing.hostname = hostname
            existing.port = port
            existing.username = username
            existing.authMethod = authMethod
            existing.isTailscale = isTailscale
        } else {
            let host = SSHHost(
                name: name,
                hostname: hostname,
                port: port,
                username: username,
                authMethod: authMethod,
                isTailscale: isTailscale
            )
            modelContext.insert(host)
        }

        if authMethod == .password, !password.isEmpty {
            let keychainAccount = "\(username)@\(hostname):\(port)"
            try? KeychainHelper.save(
                data: Data(password.utf8),
                service: "com.piterm.passwords",
                account: keychainAccount
            )
        }

        dismiss()
    }

    private func applyRaspberryPiTemplate() {
        name = "Raspberry Pi"
        hostname = "raspberrypi.ts.net"
        port = 22
        username = "pi"
        authMethod = .password
        isTailscale = true
    }
}
#endif
