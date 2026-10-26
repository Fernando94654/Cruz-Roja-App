import Foundation

/// Screens reachable from the emergency flow.
enum EmergencyRoute: Hashable {
    case report
    case summary
    case firstAid
    case guide(FirstAidGuide)
    case lesson(Lesson, autoplay: Bool)
}
