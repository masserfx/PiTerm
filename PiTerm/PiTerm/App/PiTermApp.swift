#if os(iOS)
import SwiftUI
import SwiftData

@main
struct PiTermApp: App {
    @State private var appState = AppState()

    let modelContainer: ModelContainer

    init() {
        let schema = Schema([SSHHost.self, SSHKey.self, HostGroup.self, CommandSnippet.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: false)
        do {
            modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }

        seedDefaultHosts(container: modelContainer)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
        }
        .modelContainer(modelContainer)
    }

    private func seedDefaultHosts(container: ModelContainer) {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<SSHHost>()
        let existingCount = (try? context.fetchCount(descriptor)) ?? 0
        guard existingCount == 0 else { return }

        let rpiTailscale = SSHHost(
            name: "Raspberry Pi (Tailscale)",
            hostname: "100.101.196.71",
            port: 22,
            username: "hassio",
            authMethod: .password,
            isTailscale: true,
            groupName: "Tailscale"
        )

        let rpiLAN = SSHHost(
            name: "Raspberry Pi (LAN)",
            hostname: "192.168.0.169",
            port: 22,
            username: "hassio",
            authMethod: .password,
            isTailscale: false,
            groupName: "Local"
        )

        context.insert(rpiTailscale)
        context.insert(rpiLAN)
        try? context.save()

        // Pre-store password for quick connect
        let password = Data("5164".utf8)
        try? KeychainHelper.save(data: password, service: "com.piterm.passwords", account: "hassio@192.168.0.169:22")
        try? KeychainHelper.save(data: password, service: "com.piterm.passwords", account: "hassio@100.101.196.71:22")
    }
}
#endif
