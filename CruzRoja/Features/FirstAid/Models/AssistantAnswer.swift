import Foundation

struct SourceExcerpt: Identifiable, Hashable, Sendable {
    let id = UUID()
    let document: String
    let page: Int
    let excerpt: String
}

struct AssistantAnswer: Identifiable, Hashable, Sendable {
    let id = UUID()
    let text: String
    let guide: FirstAidGuide?
    let sources: [SourceExcerpt]
}

enum ChatMessage: Identifiable, Hashable, Sendable {
    case user(UUID, String)
    case assistant(AssistantAnswer)

    var id: UUID {
        switch self {
        case .user(let id, _): id
        case .assistant(let answer): answer.id
        }
    }
}
