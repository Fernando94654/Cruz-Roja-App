import Foundation

enum APIError: LocalizedError, Equatable {
    case offline
    case invalidResponse
    case invalidData(String)
    case server(status: Int, message: String?)

    var errorDescription: String? {
        switch self {
        case .offline:
            return "No se pudo conectar con el servidor. Revisa tu conexión e intenta de nuevo."
        case .invalidResponse:
            return "El servidor respondió algo inesperado."
        case .invalidData(let message):
            return "Revisa los datos: \(message)"
        case .server(let status, let message):
            return message ?? "Error del servidor (\(status))."
        }
    }
}

struct APIClient: Sendable {
    var baseURL: URL = APIConfig.baseURL
    var session: URLSession = .shared

    // Returns nil when the resource doesn't exist (404)
    func get<Response: Decodable>(_ path: String, as type: Response.Type = Response.self) async throws -> Response? {
        let request = URLRequest(url: baseURL.appending(path: path), timeoutInterval: APIConfig.timeout)
        let (data, response) = try await send(request)
        if response.statusCode == 404 { return nil }
        try verify(response, data)
        return try decode(data)
    }

    // Sends a JSON body with PUT and decodes the response
    func put<Body: Encodable, Response: Decodable>(_ path: String, body: Body, as type: Response.Type = Response.self) async throws -> Response {
        try await send("PUT", path, body: body)
    }

    // Sends a JSON body with POST and decodes the response
    func post<Body: Encodable, Response: Decodable>(_ path: String, body: Body, as type: Response.Type = Response.self) async throws -> Response {
        try await send("POST", path, body: body)
    }

    // POST without a body
    func post<Response: Decodable>(_ path: String, as type: Response.Type = Response.self) async throws -> Response {
        try await send("POST", path, body: Optional<String>.none)
    }

    // DELETE that returns a JSON body
    func delete<Response: Decodable>(_ path: String, as type: Response.Type = Response.self) async throws -> Response {
        try await send("DELETE", path, body: Optional<String>.none)
    }

    // Builds the request with its method and JSON body, then checks and decodes the answer
    private func send<Body: Encodable, Response: Decodable>(_ method: String, _ path: String, body: Body?) async throws -> Response {
        var request = URLRequest(url: baseURL.appending(path: path), timeoutInterval: APIConfig.timeout)
        request.httpMethod = method
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)
        }
        let (data, response) = try await send(request)
        try verify(response, data)
        return try decode(data)
    }

    // Adds the sign-in token and turns network failures into APIError.offline
    private func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        var request = request
        if let token = AuthToken.current {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
            return (data, http)
        } catch is URLError {
            throw APIError.offline
        }
    }

    // Accepts 2xx; 422 becomes a validation message, anything else a server error
    private func verify(_ response: HTTPURLResponse, _ data: Data) throws {
        switch response.statusCode {
        case 200..<300:
            return
        case 422:
            throw APIError.invalidData(Self.message(from: data) ?? "algún campo no es válido.")
        default:
            throw APIError.server(status: response.statusCode, message: Self.message(from: data))
        }
    }

    // Decodes the JSON with ISO 8601 dates; bad JSON becomes invalidResponse
    private func decode<Response: Decodable>(_ data: Data) throws -> Response {
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw APIError.invalidResponse
        }
    }

    // FastAPI puts errors in "detail", either as text or as a list of validation errors
    static func message(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if let text = json["detail"] as? String {
            return text
        }
        if let list = json["detail"] as? [[String: Any]], let message = list.first?["msg"] as? String {
            return message.replacingOccurrences(of: "Value error, ", with: "")
        }
        return nil
    }

    // DELETE without a response body (204)
    func delete(_ path: String) async throws {
        var request = URLRequest(url: baseURL.appending(path: path), timeoutInterval: APIConfig.timeout)
        request.httpMethod = "DELETE"
        let (data, response) = try await send(request)
        try verify(response, data)
    }
}
