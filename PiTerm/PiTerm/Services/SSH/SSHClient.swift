import Foundation
import NIOCore
import NIOPosix
import NIOSSH

/// SSH channel handler that bridges data between SwiftNIO and the terminal
final class SSHTerminalHandler: ChannelDuplexHandler {
    typealias InboundIn = SSHChannelData
    typealias InboundOut = ByteBuffer
    typealias OutboundIn = ByteBuffer
    typealias OutboundOut = SSHChannelData

    let onData: @Sendable (Data) -> Void

    init(onData: @escaping @Sendable (Data) -> Void) {
        self.onData = onData
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let channelData = unwrapInboundIn(data)

        guard case .byteBuffer(let buffer) = channelData.data else { return }
        guard case .channel = channelData.type else { return }

        let bytes = Data(buffer.readableBytesView)
        onData(bytes)
    }

    func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let buffer = unwrapOutboundIn(data)
        let channelData = SSHChannelData(type: .channel, data: .byteBuffer(buffer))
        context.write(wrapOutboundOut(channelData), promise: promise)
    }

    func userInboundEventTriggered(context: ChannelHandlerContext, event: Any) {
        context.fireUserInboundEventTriggered(event)
    }
}

/// Low-level SSH client using SwiftNIO SSH
final class SSHClient: Sendable {
    private let group: MultiThreadedEventLoopGroup

    init() {
        self.group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    }

    func connect(
        host: String,
        port: Int,
        authDelegate: NIOSSHClientUserAuthenticationDelegate
    ) async throws -> Channel {
        let bootstrap = ClientBootstrap(group: group)
            .channelInitializer { channel in
                channel.pipeline.addHandlers([
                    NIOSSHHandler(
                        role: .client(.init(
                            userAuthDelegate: authDelegate,
                            serverAuthDelegate: AcceptAllHostKeysDelegate()
                        )),
                        allocator: channel.allocator,
                        inboundChildChannelInitializer: nil
                    ),
                ])
            }
            .channelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .connectTimeout(.seconds(10))

        return try await bootstrap.connect(host: host, port: port).get()
    }

    func openShellChannel(
        on connection: Channel,
        initialTermSize: (width: Int, height: Int),
        onData: @escaping @Sendable (Data) -> Void
    ) async throws -> Channel {
        let childChannel = try await connection.pipeline.handler(type: NIOSSHHandler.self).flatMap { sshHandler in
            let promise = connection.eventLoop.makePromise(of: Channel.self)
            sshHandler.createChannel(promise) { childChannel, channelType in
                guard channelType == .session else {
                    return connection.eventLoop.makeFailedFuture(SSHSessionError.invalidChannelType)
                }
                return childChannel.pipeline.addHandlers([
                    SSHTerminalHandler(onData: onData),
                ])
            }
            return promise.futureResult
        }.get()

        // Request PTY
        let ptyRequest = SSHChannelRequestEvent.PseudoTerminalRequest(
            wantReply: true,
            term: "xterm-256color",
            terminalCharacterWidth: initialTermSize.width,
            terminalRowHeight: initialTermSize.height,
            terminalPixelWidth: 0,
            terminalPixelHeight: 0,
            terminalModes: .init([:])
        )
        try await childChannel.triggerUserOutboundEvent(ptyRequest).get()

        // Request shell
        let shellRequest = SSHChannelRequestEvent.ShellRequest(wantReply: true)
        try await childChannel.triggerUserOutboundEvent(shellRequest).get()

        return childChannel
    }

    func sendWindowChange(
        on channel: Channel,
        width: Int,
        height: Int
    ) async throws {
        let event = SSHChannelRequestEvent.WindowChangeRequest(
            terminalCharacterWidth: width,
            terminalRowHeight: height,
            terminalPixelWidth: 0,
            terminalPixelHeight: 0
        )
        try await channel.triggerUserOutboundEvent(event).get()
    }

    func shutdown() async throws {
        try await group.shutdownGracefully()
    }
}
