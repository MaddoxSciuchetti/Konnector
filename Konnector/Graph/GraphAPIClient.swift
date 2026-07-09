import Foundation

struct GraphAPIClient: Sendable {
    let baseURL: URL

    func syncContacts(
        token: String,
        batch: GraphSyncBatch
    ) async throws {
        var request = URLRequest(url: baseURL.appending(path: "sync/contacts"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(batch)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTP(response: response, data: data)
    }

    func fetchNetwork(
        token: String,
        sourceIdentifier: String
    ) async throws -> GraphNetworkResponse {
        var components = URLComponents(
            url: baseURL.appending(path: "graph/contacts/\(sourceIdentifier)/network"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [URLQueryItem(name: "depth", value: "2")]
        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTP(response: response, data: data)
        return try JSONDecoder().decode(GraphNetworkResponse.self, from: data)
    }

    func fetchCommonalities(
        token: String,
        sourceIdentifierA: String,
        sourceIdentifierB: String
    ) async throws -> GraphCommonalitiesResponse {
        var components = URLComponents(
            url: baseURL.appending(path: "graph/contacts/common"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "a", value: sourceIdentifierA),
            URLQueryItem(name: "b", value: sourceIdentifierB),
        ]
        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTP(response: response, data: data)
        return try JSONDecoder().decode(GraphCommonalitiesResponse.self, from: data)
    }

    func search(
        token: String,
        query: String
    ) async throws -> GraphSearchResponse {
        var components = URLComponents(
            url: baseURL.appending(path: "graph/search"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [URLQueryItem(name: "q", value: query)]
        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTP(response: response, data: data)
        return try JSONDecoder().decode(GraphSearchResponse.self, from: data)
    }

    private func validateHTTP(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw GraphAPIError.invalidResponse
        }
        if http.statusCode == 404 {
            throw GraphAPIError.notFound
        }
        guard (200...299).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Request failed"
            throw GraphAPIError.serverError(message)
        }
    }
}
