import Foundation
import PPCore

/// Everything VEYA says to its backend, in one place.
///
/// **Hand-written rather than the Supabase SDK**, for the reason in
/// `docs/decisions/0001`: PostgREST is HTTP and JSON, this app needs six tables
/// and a token exchange, and a dependency nobody here can run is a risk that
/// buys very little. It also keeps `AGENTS.md`'s "Apple's own frameworks first"
/// true — this is `URLSession` and `Codable` and nothing else.
struct Backend: Sendable {
    let configuration: BackendConfiguration
    private let session: URLSession

    /// Postgres columns are snake_case and Swift properties are camelCase, so
    /// the conversion happens once here rather than as `CodingKeys` on every
    /// record — which is a dozen chances to mistype a column name.
    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }()

    init(configuration: BackendConfiguration, session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session
    }

    // MARK: - Signing in

    /// Trade Apple's identity token for a Supabase session.
    ///
    /// This is the whole of signing in. Apple has already proved who somebody
    /// is; the backend only has to agree.
    func signIn(appleIdentityToken: String) async throws -> AuthSession {
        var request = URLRequest(url: configuration.url.appending(path: "auth/v1/token"))
        request.url?.append(queryItems: [URLQueryItem(name: "grant_type", value: "id_token")])
        request.httpMethod = "POST"
        request.setValue(configuration.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try Self.encoder.encode(
            AppleGrant(provider: "apple", idToken: appleIdentityToken)
        )
        return try await send(request, decoding: AuthSession.self)
    }

    // MARK: - Reading and writing rows

    func rows<T: Decodable>(
        from table: String,
        query: [URLQueryItem] = [],
        as type: T.Type = T.self,
        token: String
    ) async throws -> [T] {
        var request = URLRequest(url: configuration.url.appending(path: "rest/v1/\(table)"))
        request.url?.append(queryItems: [URLQueryItem(name: "select", value: "*")] + query)
        authorize(&request, token: token)
        return try await send(request, decoding: [T].self)
    }

    @discardableResult
    func insert<Body: Encodable, T: Decodable>(
        _ body: Body,
        into table: String,
        as type: T.Type = T.self,
        token: String
    ) async throws -> [T] {
        var request = URLRequest(url: configuration.url.appending(path: "rest/v1/\(table)"))
        request.httpMethod = "POST"
        authorize(&request, token: token)
        // Ask for the row back, so the caller has the id the database made
        // rather than guessing at one.
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        request.httpBody = try Self.encoder.encode(body)
        return try await send(request, decoding: [T].self)
    }

    func update<Body: Encodable>(
        _ body: Body,
        in table: String,
        matching query: [URLQueryItem],
        token: String
    ) async throws {
        var request = URLRequest(url: configuration.url.appending(path: "rest/v1/\(table)"))
        request.url?.append(queryItems: query)
        request.httpMethod = "PATCH"
        authorize(&request, token: token)
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        request.httpBody = try Self.encoder.encode(body)
        _ = try await sendIgnoringBody(request)
    }

    func delete(from table: String, matching query: [URLQueryItem], token: String) async throws {
        var request = URLRequest(url: configuration.url.appending(path: "rest/v1/\(table)"))
        request.url?.append(queryItems: query)
        request.httpMethod = "DELETE"
        authorize(&request, token: token)
        _ = try await sendIgnoringBody(request)
    }

    // MARK: - The plumbing

    private func authorize(_ request: inout URLRequest, token: String) {
        request.setValue(configuration.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    }

    private func send<T: Decodable>(_ request: URLRequest, decoding: T.Type) async throws -> T {
        let data = try await sendIgnoringBody(request)
        do {
            return try Self.decoder.decode(T.self, from: data)
        } catch {
            throw BackendFailure(
                userMessage: "VEYA got an answer it didn't understand.",
                logMessage: "Decoding \(T.self) failed: \(error)"
            )
        }
    }

    private func sendIgnoringBody(_ request: URLRequest) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            // Offline is the ordinary case on a trip, not an exception, so it
            // gets a sentence a person can act on rather than an error code.
            throw BackendFailure(
                userMessage: "No connection. Everything already downloaded is still here.",
                logMessage: "Request to \(request.url?.path() ?? "?") failed: \(error)"
            )
        }

        guard let http = response as? HTTPURLResponse else {
            throw BackendFailure(userMessage: "Something went wrong.", logMessage: "Not an HTTP response")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw BackendFailure(
                userMessage: http.statusCode == 401
                    ? "Please sign in again."
                    : "Something went wrong. Nothing was changed.",
                logMessage: "HTTP \(http.statusCode) from \(request.url?.path() ?? "?"): \(String(data: data, encoding: .utf8) ?? "")"
            )
        }
        return data
    }
}

/// Why something the backend was asked to do did not happen.
struct BackendFailure: PPError {
    let userMessage: String
    let logMessage: String
}

private struct AppleGrant: Encodable {
    let provider: String
    let idToken: String
}

/// What comes back from signing in.
struct AuthSession: Codable, Sendable {
    let accessToken: String
    let refreshToken: String
    let user: AuthUser
}

struct AuthUser: Codable, Sendable {
    let id: String
}
