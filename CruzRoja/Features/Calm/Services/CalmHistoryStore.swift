import Foundation

// Guarda en el telefono como se sintio la persona al terminar cada ejercicio
@MainActor
protocol CalmHistoryStoring: AnyObject {
    func load() -> [CalmCheckIn]
    func save(_ checkIn: CalmCheckIn)
}

@MainActor
final class UserDefaultsCalmHistory: CalmHistoryStoring {
    // Solo se conservan las ultimas calificaciones
    static let limit = 20
    private let defaults: UserDefaults
    private let key = "calm.checkIns"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> [CalmCheckIn] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([CalmCheckIn].self, from: data)) ?? []
    }

    func save(_ checkIn: CalmCheckIn) {
        let all = Array((load() + [checkIn]).suffix(Self.limit))
        defaults.set(try? JSONEncoder().encode(all), forKey: key)
    }
}

// Historial en memoria, para pruebas y previews
@MainActor
final class InMemoryCalmHistory: CalmHistoryStoring {
    private(set) var checkIns: [CalmCheckIn]

    init(_ checkIns: [CalmCheckIn] = []) {
        self.checkIns = checkIns
    }

    func load() -> [CalmCheckIn] { checkIns }

    func save(_ checkIn: CalmCheckIn) {
        checkIns.append(checkIn)
    }
}
