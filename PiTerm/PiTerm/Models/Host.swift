import Foundation
import SwiftData

@Model
final class SSHHost {
    var name: String
    var hostname: String
    var port: Int
    var username: String
    var authMethod: AuthMethod
    var isTailscale: Bool
    var groupName: String?
    var lastConnected: Date?
    var createdAt: Date

    @Transient
    var isOnline: Bool = false

    init(
        name: String,
        hostname: String,
        port: Int = 22,
        username: String = "pi",
        authMethod: AuthMethod = .password,
        isTailscale: Bool = false,
        groupName: String? = nil
    ) {
        self.name = name
        self.hostname = hostname
        self.port = port
        self.username = username
        self.authMethod = authMethod
        self.isTailscale = isTailscale
        self.groupName = groupName
        self.createdAt = Date()
    }

    enum AuthMethod: String, Codable, CaseIterable {
        case password
        case publicKey
    }
}
