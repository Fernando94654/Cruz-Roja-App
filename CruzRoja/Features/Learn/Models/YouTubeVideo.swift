import Foundation

struct YouTubeVideo: Hashable, Sendable {
    let id: String
    var url: URL { URL(string: "https://www.youtube.com/watch?v=\(id)")! }

    // Accepts only HTTPS YouTube links with a single valid 11-character video ID
    init?(_ rawValue: String) {
        guard let parts = URLComponents(string: rawValue),
              parts.scheme?.lowercased() == "https", parts.user == nil, parts.password == nil,
              parts.port == nil || parts.port == 443, let host = parts.host?.lowercased() else { return nil }
        let candidate: String?
        switch host {
        case "youtube.com", "www.youtube.com", "m.youtube.com":
            guard parts.path == "/watch" else { return nil }
            let ids = (parts.queryItems ?? []).filter { $0.name == "v" }
            guard ids.count == 1 else { return nil }
            candidate = ids.first?.value
        case "youtu.be":
            guard parts.path.split(separator: "/").count == 1 else { return nil }
            candidate = String(parts.path.dropFirst())
        default:
            return nil
        }
        guard let candidate, candidate.range(of: "^[A-Za-z0-9_-]{11}$", options: .regularExpression) != nil else { return nil }
        id = candidate
    }
}
