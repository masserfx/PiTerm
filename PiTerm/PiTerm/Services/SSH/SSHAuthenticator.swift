import Foundation
import NIOCore
import NIOSSH

/// Password-based SSH authentication delegate
final class PasswordAuthenticator: NIOSSHClientUserAuthenticationDelegate {
    private let username: String
    private let password: String
    private var attempted = false

    init(username: String, password: String) {
        self.username = username
        self.password = password
    }

    func nextAuthenticationType(
        availableMethods: NIOSSHAvailableUserAuthenticationMethods,
        nextChallengePromise: EventLoopPromise<NIOSSHUserAuthenticationOffer?>
    ) {
        guard !attempted else {
            nextChallengePromise.succeed(nil)
            return
        }
        attempted = true

        guard availableMethods.contains(.password) else {
            nextChallengePromise.succeed(nil)
            return
        }

        nextChallengePromise.succeed(.init(
            username: username,
            serviceName: "",
            offer: .password(.init(password: password))
        ))
    }
}

/// Public key SSH authentication delegate
final class PublicKeyAuthenticator: NIOSSHClientUserAuthenticationDelegate {
    private let username: String
    private let privateKey: NIOSSHPrivateKey
    private var attempted = false

    init(username: String, privateKey: NIOSSHPrivateKey) {
        self.username = username
        self.privateKey = privateKey
    }

    func nextAuthenticationType(
        availableMethods: NIOSSHAvailableUserAuthenticationMethods,
        nextChallengePromise: EventLoopPromise<NIOSSHUserAuthenticationOffer?>
    ) {
        guard !attempted else {
            nextChallengePromise.succeed(nil)
            return
        }
        attempted = true

        guard availableMethods.contains(.publicKey) else {
            nextChallengePromise.succeed(nil)
            return
        }

        nextChallengePromise.succeed(.init(
            username: username,
            serviceName: "",
            offer: .privateKey(.init(privateKey: privateKey))
        ))
    }
}

/// Accept all host keys (for initial MVP — in production, implement known_hosts)
final class AcceptAllHostKeysDelegate: NIOSSHClientServerAuthenticationDelegate {
    func validateHostKey(
        hostKey: NIOSSHPublicKey,
        validationCompletePromise: EventLoopPromise<Void>
    ) {
        // TODO: Implement known_hosts verification for production
        validationCompletePromise.succeed(())
    }
}
