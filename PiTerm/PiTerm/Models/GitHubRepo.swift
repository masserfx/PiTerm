import Foundation

/// Represents a GitHub repository for display and cloning
struct GitHubRepo: Identifiable, Codable, Hashable {
    var id: String { name }
    let name: String
    let description: String
    let url: String

    var displayName: String {
        name.replacingOccurrences(of: "-", with: " ").capitalized
    }

    var clonePath: String {
        "~/projects/\(name)"
    }
}
