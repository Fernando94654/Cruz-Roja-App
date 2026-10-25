import Foundation

protocol GuidesServicing: Sendable {
    // Returns the emergency guides
    func fetchGuides() async throws -> [FirstAidGuide]
}

struct MockGuidesService: GuidesServicing {
    var guides = FirstAidGuide.bundled

    // Returns the bundled guides for previews and tests
    func fetchGuides() async throws -> [FirstAidGuide] {
        guides
    }
}

struct GuidesAPIService: GuidesServicing {
    var client = APIClient()

    // Loads GET /guides
    func fetchGuides() async throws -> [FirstAidGuide] {
        guard let guides = try await client.get("guides", as: [FirstAidGuide].self) else {
            throw APIError.invalidResponse
        }
        return guides
    }
}
