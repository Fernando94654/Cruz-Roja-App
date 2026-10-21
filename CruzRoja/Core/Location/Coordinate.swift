import Foundation

struct Coordinate: Codable, Hashable, Sendable {
    let latitude: Double
    let longitude: Double

    static let monterrey = Coordinate(latitude: 25.6516, longitude: -100.2895)
}
