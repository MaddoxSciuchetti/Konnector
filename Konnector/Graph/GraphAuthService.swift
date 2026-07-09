import Foundation
import Security

enum GraphKeychainStore {
    private static let service = "com.konnector.app.graph-auth"
    private static let tokenAccount = "auth-token"

    static func saveToken(_ token: String) {
        let data = Data(token.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tokenAccount,
        ]
        SecItemDelete(query as CFDictionary)
        var attributes = query
        attributes[kSecValueData as String] = data
        SecItemAdd(attributes as CFDictionary, nil)
    }

    static func loadToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tokenAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func clearToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tokenAccount,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

struct GraphAuthCredentials: Codable, Sendable {
    let email: String
    let password: String
}

struct GraphAuthResponse: Codable, Sendable {
    let token: String
}

enum GraphAuthService {
    static func demoCredentials(forDemoMode: Bool) -> GraphAuthCredentials? {
        guard forDemoMode else { return nil }
        return GraphAuthCredentials(email: "demo@konnector.app", password: "demo-password")
    }

    static func ensureAuthenticated(
        baseURL: URL,
        demoMode: Bool
    ) async throws -> String {
        if let token = GraphKeychainStore.loadToken() {
            return token
        }

        guard let credentials = demoCredentials(forDemoMode: demoMode) else {
            throw GraphAPIError.authenticationRequired
        }

        let token = try await registerOrLogin(baseURL: baseURL, credentials: credentials)
        GraphKeychainStore.saveToken(token)
        return token
    }

    private static func registerOrLogin(
        baseURL: URL,
        credentials: GraphAuthCredentials
    ) async throws -> String {
        do {
            return try await login(baseURL: baseURL, credentials: credentials)
        } catch {
            return try await register(baseURL: baseURL, credentials: credentials)
        }
    }

    private static func login(
        baseURL: URL,
        credentials: GraphAuthCredentials
    ) async throws -> String {
        var request = URLRequest(url: baseURL.appending(path: "auth/login"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(credentials)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTP(response: response, data: data)
        return try JSONDecoder().decode(GraphAuthResponse.self, from: data).token
    }

    private static func register(
        baseURL: URL,
        credentials: GraphAuthCredentials
    ) async throws -> String {
        var request = URLRequest(url: baseURL.appending(path: "auth/register"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(credentials)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTP(response: response, data: data)
        return try JSONDecoder().decode(GraphAuthResponse.self, from: data).token
    }

    private static func validateHTTP(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw GraphAPIError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Request failed"
            throw GraphAPIError.serverError(message)
        }
    }
}

enum GraphAPIError: LocalizedError {
    case authenticationRequired
    case invalidResponse
    case serverError(String)
    case notFound

    var errorDescription: String? {
        switch self {
        case .authenticationRequired:
            "Graph sign-in is required before syncing contacts."
        case .invalidResponse:
            "The graph service returned an invalid response."
        case .serverError(let message):
            message
        case .notFound:
            "No graph data was found for this contact."
        }
    }
}
