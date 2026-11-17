import SwiftUI

/// Video loading is independent of the local text and voice guidance.
struct RelatedLessonLink: View {
    let guideID: String
    let lessons: LearnViewModel
    let stopSpeech: () -> Void

    // Link to the video, a loading state, or a retry when lessons failed
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let lesson = lessons.lessons.first(where: { $0.guideID == guideID }), lesson.video != nil {
                NavigationLink(value: EmergencyRoute.lesson(lesson, autoplay: true)) {
                    VStack(alignment: .leading, spacing: 10) {
                        LessonThumbnail(lesson: lesson, guides: lessons.guides)
                            .frame(height: 130)
                        HStack(spacing: 8) {
                            Image(systemName: "play.circle.fill")
                                .font(.title2)
                                .foregroundStyle(Color.brandRed)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Reproducir video")
                                    .font(.subheadline.weight(.semibold))
                                Text(lesson.title)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .simultaneousGesture(TapGesture().onEnded { stopSpeech() })
            } else if lessons.isLoading || (!lessons.hasLoaded && lessons.errorMessage == nil) {
                ProgressView("Buscando video educativo…")
            } else if lessons.errorMessage != nil {
                Text("El video educativo no está disponible. Puedes continuar con la guía.")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Reintentar video educativo") {
                    Task { await lessons.load() }
                }
            }
        }
        .task {
            if !lessons.hasLoaded && lessons.errorMessage == nil { await lessons.load() }
        }
    }
}
