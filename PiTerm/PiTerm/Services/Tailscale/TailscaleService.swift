import Foundation
import Network

/// Detects Tailscale VPN status and resolves .ts.net hostnames
@Observable
final class TailscaleService {
    var isVPNActive = false
    var tailscaleIP: String?

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "TailscaleMonitor")

    init() {
        startMonitoring()
    }

    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.checkTailscaleStatus(path: path)
            }
        }
        monitor.start(queue: queue)
    }

    @MainActor
    private func checkTailscaleStatus(path: NWPath) {
        // Tailscale creates a utun interface
        let hasTailscale = path.availableInterfaces.contains { iface in
            iface.type == .other && iface.name.hasPrefix("utun")
        }
        isVPNActive = hasTailscale && path.status == .satisfied
    }

    /// Check if a hostname is a Tailscale hostname
    static func isTailscaleHost(_ hostname: String) -> Bool {
        hostname.hasSuffix(".ts.net") ||
        hostname.range(of: #"^100\.(6[4-9]|[7-9]\d|1[01]\d|12[0-7])\."#, options: .regularExpression) != nil
    }

    /// Resolve a Tailscale hostname to IP
    func resolveHost(_ hostname: String) async -> String? {
        await withCheckedContinuation { continuation in
            let host = NWEndpoint.Host(hostname)
            let params = NWParameters.tcp
            let connection = NWConnection(host: host, port: 22, using: params)

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    if let endpoint = connection.currentPath?.remoteEndpoint,
                       case .hostPort(let host, _) = endpoint {
                        continuation.resume(returning: "\(host)")
                    } else {
                        continuation.resume(returning: nil)
                    }
                    connection.cancel()
                case .failed, .cancelled:
                    continuation.resume(returning: nil)
                default:
                    break
                }
            }

            connection.start(queue: self.queue)

            // Timeout after 5 seconds
            self.queue.asyncAfter(deadline: .now() + 5) {
                connection.cancel()
            }
        }
    }

    deinit {
        monitor.cancel()
    }
}
