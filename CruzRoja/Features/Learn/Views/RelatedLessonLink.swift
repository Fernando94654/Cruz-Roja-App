import SwiftUI

/// Video loading is independent of the local text and voice guidance.
struct RelatedLessonLink: View {
    let guideID: String
    let lessons: LearnViewModel
    let stopSpeech: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let lesson = lessons.lessons.first(where: { $0.guideID == guideID }), lesson.video != nil {
                NavigationLink(value: EmergencyRoute.lesson(lesson)) {
                    Label("Ver video educativo", systemImage: "play.rectangle")
                }
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
