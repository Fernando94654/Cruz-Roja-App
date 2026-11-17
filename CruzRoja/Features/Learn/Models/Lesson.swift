import Foundation

struct Lesson: Identifiable, Hashable, Sendable, Decodable {
    let id: UUID
    let title: String
    let guideID: String?
    let videoURL: String?
    let summary: String?
    let publisher: String?
    let durationSeconds: Int?
    let position: Int
    let steps: [String]

    // Duration as m:ss, or nil when unknown
    var duration: String? {
        guard let seconds = durationSeconds, seconds > 0 else { return nil }
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    // The video only when the link is a valid YouTube URL
    var video: YouTubeVideo? { videoURL.flatMap(YouTubeVideo.init) }

    enum CodingKeys: String, CodingKey {
        case id, title, position, publisher, steps
        case guideID = "guide_id", videoURL = "video_url", summary = "description", durationSeconds = "duration_seconds"
    }
}
