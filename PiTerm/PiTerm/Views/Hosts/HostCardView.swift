#if os(iOS)
import SwiftUI

/// Visual card representing a single SSH host
struct HostCardView: View {
    let host: SSHHost
    let tailscaleActive: Bool
    let onConnect: () -> Void

    var body: some View {
        Button(action: onConnect) {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(host.isTailscale ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                        .frame(width: 44, height: 44)

                    Image(systemName: host.isTailscale ? "network" : "server.rack")
                        .font(.system(size: 20))
                        .foregroundStyle(host.isTailscale ? .blue : .gray)
                }

                // Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(host.name)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text("\(host.username)@\(host.hostname):\(host.port)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    if let lastConnected = host.lastConnected {
                        Text("Last: \(lastConnected, style: .relative) ago")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()

                // Status indicators
                VStack(spacing: 4) {
                    if host.isTailscale {
                        Image(systemName: tailscaleActive ? "checkmark.circle.fill" : "exclamationmark.triangle")
                            .foregroundStyle(tailscaleActive ? .green : .orange)
                            .font(.caption)
                    }

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.background)
                    .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
#endif
