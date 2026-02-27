import SwiftUI

@Observable
final class AppState {
    var selectedTab: Tab = .hosts
    var isConnected = false
    var activeHost: SSHHost?
    var activeSession: SSHSession?
    var tailscaleActive = false

    enum Tab: Hashable {
        case hosts
        case terminal
        case claude
        case settings
    }
}
