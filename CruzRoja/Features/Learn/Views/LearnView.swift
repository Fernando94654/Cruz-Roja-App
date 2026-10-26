import SwiftUI

struct LearnView: View {
    let container: AppContainer
    @State private var viewModel: LearnViewModel
    @State private var path: [Lesson] = []

    // Builds the lesson list view model from the app container
    init(container: AppContainer) {
        self.container = container
        _viewModel = State(initialValue: container.makeLearnViewModel())
    }

    // Lesson list with progress, plus loading, error and empty states
    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    ForEach(viewModel.lessons) { lesson in
                        NavigationLink(value: lesson) {
                            HStack(spacing: 14) {
                                LessonThumbnail(lesson: lesson, guides: viewModel.guides)
                                    .frame(width: 110, height: 66)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(lesson.title).font(.headline)
                                    Text(lesson.duration.map { "Video · \($0)" } ?? "Video educativo")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                                if viewModel.progress?.isCompleted(lesson) == true {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                        .accessibilityLabel("Completada")
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } header: {
                    if let progress = viewModel.progress, !viewModel.lessons.isEmpty {
                        Text("\(progress.completedCount(in: viewModel.lessons)) de \(viewModel.lessons.count) completadas")
                    }
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
    let lesson: Lesson
    var guides = FirstAidGuide.bundled

    // The related guide's icon, or a play icon
    private var icon: String {
        guard let guideID = lesson.guideID else { return "play.rectangle.fill" }
        return guides.first { $0.id == guideID }?.icon ?? "play.rectangle.fill"
    }

    // Red card with the guide icon and a play badge
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(LinearGradient(colors: [Color.brandRed, Color.brandRed.opacity(0.7)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))

                Image(systemName: icon)
                    .font(.system(size: min(geometry.size.height * 0.48, 76), weight: .medium))
                    .foregroundStyle(.white)

                Image(systemName: "play.fill")
                    .font(.system(size: min(geometry.size.height * 0.16, 22), weight: .bold))
                    .foregroundStyle(Color.brandRed)
                    .frame(width: min(geometry.size.height * 0.3, 42),
                           height: min(geometry.size.height * 0.3, 42))
                    .background(.white, in: Circle())
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(geometry.size.height * 0.08)
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    GuidesRefreshed(container: .preview) { LearnView(container: .preview) }
}
