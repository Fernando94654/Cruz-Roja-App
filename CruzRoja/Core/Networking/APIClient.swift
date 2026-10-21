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

    func put<Body: Encodable, Response: Decodable>(_ path: String, body: Body, as type: Response.Type = Response.self) async throws -> Response {
        var request = URLRequest(url: baseURL.appending(path: path), timeoutInterval: APIConfig.timeout)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await send(request)
        try verify(response, data)
        return try decode(data)
    }

    private func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
            return (data, http)
        } catch is URLError {
            throw APIError.offline
        }
    }

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

    private func decode<Response: Decodable>(_ data: Data) throws -> Response {
        do {
            return try JSONDecoder().decode(Response.self, from: data)
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
}
