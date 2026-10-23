import Foundation

enum EmergencyRoute: Hashable {
    case report
    case summary
    case firstAid
    case guide(FirstAidGuide)
    case lesson(Lesson)
}
