import SwiftUI

struct LessonView: View {
    @State private var viewModel: LessonViewModel
    @State private var player = YouTubePlayerController()
    @State private var isVisible = false
    @State private var playerRevision = 0
    @Environment(\.scenePhase) private var scenePhase

    init(viewModel: LessonViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    private var lesson: Lesson { viewModel.lesson }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let video = lesson.video {
                    if isVisible {
                        YouTubePlayer(video: video, controller: player)
                            .id(playerRevision)
                            .frame(height: 240)
                            .task(id: playerRevision) {
                                await player.monitorPlayback(onPlayback: viewModel.stop)
                            }
                            .task(id: playerRevision) {
                                try? await Task.sleep(for: .seconds(20))
                                guard !Task.isCancelled, player.isLoading else { return }
                                player.isLoading = false
                                player.isUnavailable = true
                            }
                    }
                    if player.isLoading { ProgressView("Cargando video…") }
                    if player.isUnavailable {
                        Text("No se pudo cargar el reproductor. Puedes reintentar o abrir el video en YouTube.")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Button("Reintentar video") {
                            player.stop()
                            player = YouTubePlayerController()
                            playerRevision += 1
                        }
                    }
                    Link("Abrir en YouTube", destination: video.url)
                        .simultaneousGesture(TapGesture().onEnded {
                            viewModel.stop()
                            player.pause()
                        })
                } else {
                    Label("Video no disponible", systemImage: "video.slash")
                        .foregroundStyle(.secondary)
                }

                Text(lesson.title).font(.brand(28))
                if let summary = lesson.summary {
                    Text(summary).foregroundStyle(.secondary)
                }

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
                    player.pause()
                    viewModel.toggleSpeech()
                } label: {
                    Label(viewModel.isSpeaking ? "Detener" : "Escuchar lección",
                          systemImage: viewModel.isSpeaking ? "stop.fill" : "speaker.wave.2.fill")
                }
                .buttonStyle(.bordered)
                .tint(.primary)

                Divider()

                if let publisher = lesson.publisher {
                    Label("Video publicado por \(publisher)", systemImage: "play.rectangle")
                        .font(.subheadline)
                }
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.stop()
            player = YouTubePlayerController()
            isVisible = true
        }
        .onDisappear {
            viewModel.stop()
            player.stop()
            isVisible = false
        }
        .onChange(of: scenePhase) {
            if scenePhase != .active {
                player.pause()
                viewModel.stop()
            }
        }
    }
}
