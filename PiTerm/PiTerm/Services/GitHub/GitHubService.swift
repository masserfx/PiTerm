import Foundation

/// Service for GitHub API operations (issues, repos)
@Observable
final class GitHubService {
    static let shared = GitHubService()

    private let keychainService = "com.piterm.github"
    private let keychainAccount = "token"

    var isAuthenticated: Bool { token != nil }
    private var token: String?

    init() {
        loadToken()
    }

    // MARK: - Token Management

    func loadToken() {
        if let data = try? KeychainHelper.load(service: keychainService, account: keychainAccount),
           let t = String(data: data, encoding: .utf8), !t.isEmpty {
            token = t
        }
    }

    func saveToken(_ newToken: String) {
        try? KeychainHelper.save(data: Data(newToken.utf8), service: keychainService, account: keychainAccount)
        token = newToken
    }

    func clearToken() {
        try? KeychainHelper.delete(service: keychainService, account: keychainAccount)
        token = nil
    }

    // MARK: - Repos

    func fetchRepos(user: String) async throws -> [GitHubRepo] {
        let url = URL(string: "https://api.github.com/users/\(user)/repos?per_page=100&sort=updated&direction=desc")!
        let (data, _) = try await request(url: url)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let apiRepos = try decoder.decode([GitHubAPIRepo].self, from: data)
        return apiRepos.map {
            GitHubRepo(name: $0.name, description: $0.description ?? "", url: $0.cloneUrl)
        }
    }

    // MARK: - Issues

    struct Issue: Codable, Identifiable {
        let id: Int
        let number: Int
        let title: String
        let body: String?
        let state: String
        let labels: [Label]
        let htmlUrl: String
        let createdAt: String

        struct Label: Codable {
            let name: String
            let color: String?
        }
    }

    func fetchIssues(owner: String, repo: String) async throws -> [Issue] {
        let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/issues?state=open&per_page=30&sort=updated")!
        let (data, _) = try await request(url: url)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode([Issue].self, from: data)
    }

    struct CreateIssueRequest: Encodable {
        let title: String
        let body: String
        let labels: [String]
    }

    struct CreateIssueResponse: Decodable {
        let number: Int
        let htmlUrl: String
    }

    func createIssue(owner: String, repo: String, title: String, body: String, addClaudeLabel: Bool) async throws -> CreateIssueResponse {
        let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/issues")!
        var labels = [String]()
        if addClaudeLabel { labels.append("claude") }

        let requestBody = CreateIssueRequest(title: title, body: body, labels: labels)
        let encoder = JSONEncoder()
        let bodyData = try encoder.encode(requestBody)

        let (data, _) = try await request(url: url, method: "POST", body: bodyData)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(CreateIssueResponse.self, from: data)
    }

    // MARK: - Ensure 'claude' label exists

    func ensureClaudeLabel(owner: String, repo: String) async {
        let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/labels")!
        struct LabelRequest: Encodable {
            let name: String
            let color: String
            let description: String
        }
        let body = LabelRequest(name: "claude", color: "7c3aed", description: "Trigger Claude Code Action")
        guard let bodyData = try? JSONEncoder().encode(body) else { return }
        _ = try? await request(url: url, method: "POST", body: bodyData)
    }

    // MARK: - HTTP

    private func request(url: URL, method: String = "GET", body: Data? = nil) async throws -> (Data, HTTPURLResponse) {
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        req.timeoutInterval = 15

        if let token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            req.httpBody = body
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        if http.statusCode >= 400 {
            let errorBody = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "GitHub", code: http.statusCode, userInfo: [
                NSLocalizedDescriptionKey: "GitHub API error \(http.statusCode): \(errorBody)"
            ])
        }
        return (data, http)
    }
}

private struct GitHubAPIRepo: Decodable {
    let name: String
    let description: String?
    let cloneUrl: String
}
