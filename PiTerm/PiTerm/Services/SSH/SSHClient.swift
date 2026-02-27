import Foundation
import NIOCore
import NIOPosix
import NIOSSH

/// SSH channel handler that bridges data between SwiftNIO and the terminal.
/// Sends PTY + shell requests in channelActive for correct sequencing.
final class SSHTerminalHandler: ChannelDuplexHandler {
    typealias InboundIn = SSHChannelData
    typealias InboundOut = ByteBuffer
    typealias OutboundIn = ByteBuffer
    typealias OutboundOut = SSHChannelData

    let onData: @Sendable (Data) -> Void
    let termWidth: Int
    let termHeight: Int

    init(
        onData: @escaping @Sendable (Data) -> Void,
        termWidth: Int = 80,
        termHeight: Int = 24
    ) {
        self.onData = onData
        self.termWidth = termWidth
        self.termHeight = termHeight
    }

    func channelActive(context: ChannelHandlerContext) {
        // Request PTY allocation first
        let ptyRequest = SSHChannelRequestEvent.PseudoTerminalRequest(
            wantReply: true,
            term: "xterm-256color",
            terminalCharacterWidth: termWidth,
            terminalRowHeight: termHeight,
            terminalPixelWidth: 0,
            terminalPixelHeight: 0,
            terminalModes: .init([:])
        )
        context.triggerUserOutboundEvent(ptyRequest, promise: nil)

        // Then request shell
        let shellRequest = SSHChannelRequestEvent.ShellRequest(wantReply: true)
        context.triggerUserOutboundEvent(shellRequest, promise: nil)
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let channelData = unwrapInboundIn(data)

        guard case .byteBuffer(let buffer) = channelData.data else { return }
        // Accept both stdout (.channel) and stderr (.stdErr)
        let bytes = Data(buffer.readableBytesView)
        if !bytes.isEmpty {
            onData(bytes)
        }
    }

    func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let buffer = unwrapOutboundIn(data)
        let channelData = SSHChannelData(type: .channel, data: .byteBuffer(buffer))
        context.write(wrapOutboundOut(channelData), promise: promise)
    }

    func userInboundEventTriggered(context: ChannelHandlerContext, event: Any) {
        // Forward events to the pipeline
        context.fireUserInboundEventTriggered(event)
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        print("[PiTerm] SSHTerminalHandler error: \(error)")
        context.fireErrorCaught(error)
    }
}

/// Logs any errors that occur in the SSH pipeline
final class SSHErrorHandler: ChannelInboundHandler {
    typealias InboundIn = Any

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        print("[PiTerm] SSH pipeline error: \(error)")
        context.close(promise: nil)
    }

    func channelInactive(context: ChannelHandlerContext) {
        print("[PiTerm] SSH channel became inactive")
        context.fireChannelInactive()
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
                    SSHErrorHandler(),
                ])
            }
            .channelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .channelOption(ChannelOptions.socket(IPPROTO_TCP, TCP_NODELAY), value: 1)
            .channelOption(ChannelOptions.socketOption(.so_keepalive), value: 1)
            .connectTimeout(.seconds(15))

        return try await bootstrap.connect(host: host, port: port).get()
    }

    func openShellChannel(
        on connection: Channel,
        initialTermSize: (width: Int, height: Int),
        onData: @escaping @Sendable (Data) -> Void
    ) async throws -> Channel {
        let childChannel: Channel = try await connection.eventLoop.flatSubmit {
            let promise = connection.eventLoop.makePromise(of: Channel.self)

            connection.pipeline.handler(type: NIOSSHHandler.self).whenSuccess { sshHandler in
                sshHandler.createChannel(promise) { childChannel, channelType in
                    guard channelType == .session else {
                        return connection.eventLoop.makeFailedFuture(SSHSessionError.invalidChannelType)
                    }

                    // Enable half-closure — required for correct SSH behavior
                    return childChannel.setOption(ChannelOptions.allowRemoteHalfClosure, value: true).flatMap {
                        childChannel.pipeline.addHandlers([
                            SSHTerminalHandler(
                                onData: onData,
                                termWidth: initialTermSize.width,
                                termHeight: initialTermSize.height
                            ),
                        ])
                    }
                }
            }

            connection.pipeline.handler(type: NIOSSHHandler.self).whenFailure { error in
                promise.fail(error)
            }

            return promise.futureResult
        }.get()

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
