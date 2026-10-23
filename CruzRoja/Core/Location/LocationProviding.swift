import Foundation

struct CurrentLocation: Sendable {
    let coordinate: Coordinate
    let address: String?
    let accuracyMeters: Int
}

@MainActor
protocol LocationProviding: AnyObject {
    // Nil when permission is denied or no fix arrives in time
    func current() async -> CurrentLocation?
}

// Fixed result for previews and tests
@MainActor
final class FixedLocationProvider: LocationProviding {
    var location: CurrentLocation?

    init(location: CurrentLocation? = nil) {
        self.location = location
    }

    func current() async -> CurrentLocation? { location }
}
