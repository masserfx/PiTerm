import Foundation
import NIOCore
import NIOSSH

enum SSHSessionError: Error, LocalizedError {
    case notConnected
    case alreadyConnected
    case connectionFailed(String)
    case authenticationFailed
    case channelCreationFailed
    case invalidChannelType

    var errorDescription: String? {
        switch self {
        case .notConnected: "Not connected to SSH server"
        case .alreadyConnected: "Already connected"
        case .connectionFailed(let msg): "Connection failed: \(msg)"
        case .authenticationFailed: "Authentication failed"
        case .channelCreationFailed: "Failed to create SSH channel"
        case .invalidChannelType: "Invalid channel type"
        }
    }
}

/// Actor managing a single SSH session lifecycle
actor SSHSession {
    enum State {
        case disconnected
        case connecting
        case connected
        case error(Error)
    }

    private(set) var state: State = .disconnected
    private let client = SSHClient()
    private var connection: Channel?
    private var shellChannel: Channel?
    private var onData: (@Sendable (Data) -> Void)?

    var isConnected: Bool {
        if case .connected = state { return true }
        return false
    }

    func connect(
        host: String,
        port: Int,
        username: String,
        password: String,
        termSize: (width: Int, height: Int),
        onData: @escaping @Sendable (Data) -> Void
    ) async throws {
        guard case .disconnected = state else {
            print("[PiTerm] SSHSession: already connected or connecting")
            throw SSHSessionError.alreadyConnected
        }

        self.onData = onData
        state = .connecting

        do {
            print("[PiTerm] SSHSession: TCP connecting to \(host):\(port)...")
            let authDelegate = PasswordAuthenticator(username: username, password: password)
            let conn = try await client.connect(host: host, port: port, authDelegate: authDelegate)
            self.connection = conn
            print("[PiTerm] SSHSession: TCP connected, opening shell channel...")

            let channel = try await withThrowingTaskGroup(of: Channel.self) { group in
                group.addTask {
                    try await self.client.openShellChannel(
                        on: conn,
                        initialTermSize: termSize,
                        onData: onData
                    )
                }
                group.addTask {
                    try await Task.sleep(for: .seconds(15))
                    throw SSHSessionError.connectionFailed("SSH handshake timed out after 15s")
                }
                let result = try await group.next()!
                group.cancelAll()
                return result
            }
            self.shellChannel = channel
            state = .connected
            print("[PiTerm] SSHSession: Shell channel open, fully connected!")
        } catch {
            state = .error(error)
            print("[PiTerm] SSHSession: Connection error: \(error)")
            throw error
        }
    }

    func connectWithKey(
        host: String,
        port: Int,
        username: String,
        privateKey: NIOSSHPrivateKey,
        termSize: (width: Int, height: Int),
        onData: @escaping @Sendable (Data) -> Void
    ) async throws {
        guard case .disconnected = state else {
            throw SSHSessionError.alreadyConnected
        }

        self.onData = onData
        state = .connecting

        do {
            let authDelegate = PublicKeyAuthenticator(username: username, privateKey: privateKey)
            let conn = try await client.connect(host: host, port: port, authDelegate: authDelegate)
            self.connection = conn

            let channel = try await client.openShellChannel(
                on: conn,
                initialTermSize: termSize,
                onData: onData
            )
            self.shellChannel = channel
            state = .connected
        } catch {
            state = .error(error)
            throw error
        }
    }

    func send(_ data: Data) async throws {
        guard let channel = shellChannel else {
            throw SSHSessionError.notConnected
        }

        var buffer = channel.allocator.buffer(capacity: data.count)
        buffer.writeBytes(data)
        try await channel.writeAndFlush(buffer)
    }

    func resize(width: Int, height: Int) async throws {
        guard let channel = shellChannel else {
            throw SSHSessionError.notConnected
        }
        try await client.sendWindowChange(on: channel, width: width, height: height)
    }

    func disconnect() async {
        do {
            try await shellChannel?.close()
        } catch { /* channel may already be closed */ }
        do {
            try await connection?.close()
        } catch { /* connection may already be closed */ }

        shellChannel = nil
        connection = nil
        state = .disconnected
    }

    func shutdown() async {
        await disconnect()
        try? await client.shutdown()
    }
}
