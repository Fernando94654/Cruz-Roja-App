import Foundation

protocol GuidesServicing: Sendable {
    func fetchGuides() async throws -> [FirstAidGuide]
}

struct MockGuidesService: GuidesServicing {
    var guides = FirstAidGuide.bundled

    func fetchGuides() async throws -> [FirstAidGuide] {
        guides
    }
}

struct GuidesAPIService: GuidesServicing {
    var client = APIClient()

    func fetchGuides() async throws -> [FirstAidGuide] {
        guard let guides = try await client.get("guides", as: [FirstAidGuide].self) else {
            throw APIError.invalidResponse
        }
        return guides
    }
}
