import SwiftUI

struct LearnView: View {
    let container: AppContainer
    @State private var viewModel: LearnViewModel
    @State private var path: [Lesson] = []

    init(container: AppContainer) {
        self.container = container
        _viewModel = State(initialValue: container.makeLearnViewModel())
    }

    var body: some View {
        NavigationStack(path: $path) {
            List(viewModel.lessons) { lesson in
                NavigationLink(value: lesson) {
                    HStack(spacing: 14) {
                        LessonThumbnail()
                            .frame(width: 110, height: 66)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(lesson.title).font(.headline)
                            Text(lesson.duration.map { "Video · \($0)" } ?? "Video educativo")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .overlay {
                if viewModel.isLoading && viewModel.lessons.isEmpty {
                    ProgressView("Cargando lecciones…")
                } else if let error = viewModel.errorMessage {
                    ContentUnavailableView {
                        Label("No se pudieron cargar las lecciones", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Reintentar") { Task { await viewModel.load() } }
                    }
                } else if viewModel.hasLoaded && viewModel.lessons.isEmpty {
                    ContentUnavailableView("Aún no hay lecciones", systemImage: "play.rectangle",
                                           description: Text("Desliza hacia abajo para actualizar."))
                }
            }
            .refreshable { await viewModel.load() }
            .navigationTitle("Aprende")
            .navigationDestination(for: Lesson.self) { lesson in
                LessonView(viewModel: container.makeLessonViewModel(lesson: lesson))
            }
            .task {
                await viewModel.load()
                if DemoMode.isActive("lesson"), path.isEmpty, let first = viewModel.lessons.first { path = [first] }
            }
        }
    }
}

struct LessonThumbnail: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(.gray.opacity(0.25))
            .overlay {
                Image(systemName: "play.fill")
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(.black.opacity(0.35), in: Circle())
            }
    }
}

#Preview {
    LearnView(container: .preview)
}
