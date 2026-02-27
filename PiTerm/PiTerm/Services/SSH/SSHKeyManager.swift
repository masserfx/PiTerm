import Foundation
import CryptoKit
import NIOSSH

/// Manages SSH key generation, import and Keychain storage
enum SSHKeyManager {
    private static let keychainService = "com.piterm.sshkeys"

    /// Generate a new Ed25519 key pair, store private key in Keychain
    static func generateEd25519Key(name: String) throws -> (publicKey: NIOSSHPublicKey, keychainTag: String) {
        let privateKey = Curve25519.Signing.PrivateKey()
        let nioPrivateKey = NIOSSHPrivateKey(ed25519Key: privateKey)
        let nioPublicKey = nioPrivateKey.publicKey

        let tag = "piterm.ed25519.\(name).\(UUID().uuidString)"

        // Store raw private key bytes in Keychain
        try KeychainHelper.save(
            data: privateKey.rawRepresentation,
            service: keychainService,
            account: tag
        )

        return (nioPublicKey, tag)
    }

    /// Load a private key from Keychain by tag
    static func loadPrivateKey(tag: String, keyType: SSHKey.KeyType) throws -> NIOSSHPrivateKey {
        let data = try KeychainHelper.load(service: keychainService, account: tag)

        switch keyType {
        case .ed25519:
            let privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: data)
            return NIOSSHPrivateKey(ed25519Key: privateKey)
        case .rsa:
            // RSA key loading requires additional handling
            fatalError("RSA key import not yet implemented")
        }
    }

    /// Delete a private key from Keychain
    static func deleteKey(tag: String) throws {
        try KeychainHelper.delete(service: keychainService, account: tag)
    }

    /// Format public key as authorized_keys line
    static func authorizedKeysFormat(publicKey: NIOSSHPublicKey, comment: String) -> String {
        return "ssh-ed25519 \(publicKey) \(comment)"
    }
}
