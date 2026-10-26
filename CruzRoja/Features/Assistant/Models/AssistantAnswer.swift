import Foundation

struct AssistantAnswer: Identifiable, Hashable, Sendable {
    let id = UUID()
    let text: String
    let guide: FirstAidGuide?
}

enum ChatMessage: Identifiable, Hashable, Sendable {
    case user(UUID, String)
    case assistant(AssistantAnswer)

    // Lets SwiftUI tell the messages apart
    var id: UUID {
        switch self {
        case .user(let id, _): id
        case .assistant(let answer): answer.id
        }
    }
}
