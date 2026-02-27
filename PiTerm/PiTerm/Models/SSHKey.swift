import Foundation
import SwiftData

@Model
final class SSHKey {
    var name: String
    var keyType: KeyType
    var publicKeyData: Data
    var fingerprint: String
    var createdAt: Date

    /// Private key is stored in Keychain, referenced by this tag
    var keychainTag: String

    init(
        name: String,
        keyType: KeyType,
        publicKeyData: Data,
        fingerprint: String,
        keychainTag: String
    ) {
        self.name = name
        self.keyType = keyType
        self.publicKeyData = publicKeyData
        self.fingerprint = fingerprint
        self.keychainTag = keychainTag
        self.createdAt = Date()
    }

    enum KeyType: String, Codable, CaseIterable {
        case ed25519
        case rsa
    }
}
