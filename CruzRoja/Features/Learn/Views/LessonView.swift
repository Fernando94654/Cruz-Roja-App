import SwiftUI

struct LessonView: View {
    @State private var viewModel: LessonViewModel

    init(viewModel: LessonViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    private var lesson: Lesson { viewModel.lesson }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Placeholder player until lesson videos exist
                LessonThumbnail()
                    .aspectRatio(16/9, contentMode: .fit)

                VStack(spacing: 4) {
                    Slider(value: $viewModel.playback)
                        .tint(Color.brandRed)
                    HStack {
                        Text("0:00")
                        Spacer()
                        Text(lesson.duration)
                    }
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                }

                Text(lesson.title).font(.brand(28))
                Text(lesson.summary)
                    .foregroundStyle(.secondary)

                ForEach(Array(lesson.steps.enumerated()), id: \.offset) { i, step in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(i + 1)")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(width: 28, height: 28)
                            .background(Color.brandRed, in: Circle())
                        Text(step)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                Button {
                    viewModel.toggleSpeech()
                } label: {
                    Label(viewModel.isSpeaking ? "Detener" : "Escuchar lección",
                          systemImage: viewModel.isSpeaking ? "stop.fill" : "speaker.wave.2.fill")
                }
                .buttonStyle(.bordered)
                .tint(.primary)

                Divider()

                Label("Lección certificada por instructores de Cruz Roja", systemImage: "checkmark.seal")
                    .font(.subheadline)
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { viewModel.stop() }
    }
}

#Preview {
    NavigationStack { LessonView(viewModel: AppContainer.preview.makeLessonViewModel(lesson: Lesson.samples[0])) }
}
