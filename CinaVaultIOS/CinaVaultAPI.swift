import Foundation

private final class SecureRedirectDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}

enum CinaVaultAPIError: LocalizedError {
    case invalidEndpoint
    case insecureURL
    case embeddedCredentials
    case invalidResponse
    case server(status: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidEndpoint:
            "Enter a valid CinaVault HTTPS relay URL."
        case .insecureURL:
            "CinaVault iOS only accepts encrypted HTTPS URLs."
        case .embeddedCredentials:
            "Credentials must not be embedded in the server URL."
        case .invalidResponse:
            "The CinaVault server returned an invalid response."
        case let .server(status, message):
            "CinaVault server returned HTTP \(status): \(message)"
        }
    }
}

actor CinaVaultAPI {
    private struct SessionResponse: Decodable {
        let email: String
        let sessionToken: String
        let expiresAt: String
        let permissions: [String]
    }

    private struct PasswordBody: Encodable {
        let email: String
        let password: String
    }

    private struct AccessKeyBody: Encodable {
        let accessKey: String
    }

    private struct ControlActionBody: Encodable {
        let actionId: String
    }

    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let urlSession: URLSession

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 60
        configuration.waitsForConnectivity = true

        decoder = JSONDecoder()
        encoder = JSONEncoder()
        urlSession = URLSession(
            configuration: configuration,
            delegate: SecureRedirectDelegate(),
            delegateQueue: nil
        )
    }

    func loginWithPassword(endpoint: String, email: String, password: String) async throws -> RemoteSession {
        let baseURL = try normalizeEndpoint(endpoint)
        let response: SessionResponse = try await request(
            baseURL: baseURL,
            path: "/api/auth/password",
            method: "POST",
            token: nil,
            body: PasswordBody(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
        )
        return RemoteSession(
            endpoint: baseURL,
            token: response.sessionToken,
            email: response.email,
            expiresAt: response.expiresAt,
            permissions: response.permissions
        )
    }

    func loginWithAccessKey(endpoint: String, accessKey: String) async throws -> RemoteSession {
        let baseURL = try normalizeEndpoint(endpoint)
        let response: SessionResponse = try await request(
            baseURL: baseURL,
            path: "/api/auth/access-key",
            method: "POST",
            token: nil,
            body: AccessKeyBody(accessKey: accessKey.trimmingCharacters(in: .whitespacesAndNewlines))
        )
        return RemoteSession(
            endpoint: baseURL,
            token: response.sessionToken,
            email: response.email,
            expiresAt: response.expiresAt,
            permissions: response.permissions
        )
    }

    func loadServerInfo(session: RemoteSession) async throws -> ServerInfo {
        try await request(
            baseURL: session.endpoint,
            path: "/api/server/info",
            method: "GET",
            token: session.token,
            body: Optional<String>.none
        )
    }

    func loadLibrary(session: RemoteSession) async throws -> [MediaItem] {
        try await request(
            baseURL: session.endpoint,
            path: "/api/library",
            method: "GET",
            token: session.token,
            body: Optional<String>.none
        )
    }

    func loadControlSnapshot(session: RemoteSession) async throws -> ControlSnapshot {
        try await request(
            baseURL: session.endpoint,
            path: "/api/control/snapshot",
            method: "GET",
            token: session.token,
            body: Optional<String>.none
        )
    }

    func runControlAction(session: RemoteSession, actionID: String) async throws -> String {
        struct ActionResponse: Decodable { let message: String }
        let response: ActionResponse = try await request(
            baseURL: session.endpoint,
            path: "/api/control/action",
            method: "POST",
            token: session.token,
            body: ControlActionBody(actionId: actionID)
        )
        return response.message
    }

    func createCastGrant(session: RemoteSession, mediaKey: String) async throws -> CastGrant {
        try await request(
            baseURL: session.endpoint,
            path: "/api/cast/grant/\(mediaKey)",
            method: "POST",
            token: session.token,
            body: Optional<String>.none
        )
    }

    func loadArtwork(session: RemoteSession, path: String) async throws -> Data {
        let url = try resolve(baseURL: session.endpoint, path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.setValue("Bearer \(session.token)", forHTTPHeaderField: "Authorization")
        request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
        let (data, response) = try await urlSession.data(for: request)
        try validate(response: response, data: data)
        return data
    }

    func absoluteURL(session: RemoteSession, path: String) throws -> URL {
        try resolve(baseURL: session.endpoint, path: path)
    }

    private func request<Response: Decodable, Body: Encodable>(
        baseURL: URL,
        path: String,
        method: String,
        token: String?,
        body: Body?
    ) async throws -> Response {
        let url = try resolve(baseURL: baseURL, path: path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
        if let token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.httpBody = try encoder.encode(body)
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await urlSession.data(for: request)
        try validate(response: response, data: data)
        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw CinaVaultAPIError.invalidResponse
        }
    }

    private func normalizeEndpoint(_ endpoint: String) throws -> URL {
        let trimmed = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: trimmed),
              components.scheme?.lowercased() == "https",
              components.host?.isEmpty == false else {
            throw CinaVaultAPIError.invalidEndpoint
        }
        guard components.user == nil, components.password == nil else {
            throw CinaVaultAPIError.embeddedCredentials
        }
        components.path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = components.url else { throw CinaVaultAPIError.invalidEndpoint }
        return url
    }

    private func resolve(baseURL: URL, path: String) throws -> URL {
        if let absolute = URL(string: path), absolute.scheme != nil {
            guard absolute.scheme?.lowercased() == "https" else {
                throw CinaVaultAPIError.insecureURL
            }
            guard absolute.user == nil, absolute.password == nil else {
                throw CinaVaultAPIError.embeddedCredentials
            }
            return absolute
        }
        guard baseURL.scheme?.lowercased() == "https" else {
            throw CinaVaultAPIError.insecureURL
        }
        let normalizedPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        guard let url = URL(string: normalizedPath, relativeTo: baseURL.appendingPathComponent("/"))?.absoluteURL,
              url.scheme?.lowercased() == "https" else {
            throw CinaVaultAPIError.invalidEndpoint
        }
        return url
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw CinaVaultAPIError.invalidResponse
        }
        guard (200 ... 299).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            throw CinaVaultAPIError.server(status: http.statusCode, message: message)
        }
    }
}
