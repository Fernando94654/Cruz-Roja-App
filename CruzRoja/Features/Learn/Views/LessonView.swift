import SwiftUI

struct LessonView: View {
    @State private var viewModel: LessonViewModel
    @State private var playerViewModel: LessonPlayerViewModel<YouTubePlayerController>
    @Environment(\.scenePhase) private var scenePhase
    let autoplay: Bool

    init(viewModel: LessonViewModel, autoplay: Bool = false) {
        _viewModel = State(initialValue: viewModel)
        _playerViewModel = State(initialValue: LessonPlayerViewModel(lesson: viewModel, makePlayer: YouTubePlayerController.init))
        self.autoplay = autoplay
    }

    private var lesson: Lesson { viewModel.lesson }

    var body: some View {
        let revision = playerViewModel.revision
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let video = lesson.video {
                    if playerViewModel.isVisible {
                        ZStack {
                            YouTubePlayer(video: video, controller: playerViewModel.player, autoplay: autoplay,
                                          onLoad: { playerViewModel.didLoad(revision: revision) },
                                          onFailure: { playerViewModel.didFail(revision: revision) })
                                .id(revision)
                                .allowsHitTesting(!playerViewModel.isLoading && !playerViewModel.isUnavailable)

                            if playerViewModel.isLoading || playerViewModel.isUnavailable {
                                LessonThumbnail(lesson: lesson)
                                    .allowsHitTesting(false)
                            }
                        }
                        .frame(height: 240)
                    }
                    if playerViewModel.isLoading { ProgressView("Cargando video…") }
                    if playerViewModel.isUnavailable {
                        Text("No se pudo cargar el reproductor. Puedes reintentar o abrir el video en YouTube.")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Button("Reintentar video") {
                            playerViewModel.retry()
                        }
                    }
                    Link("Abrir en YouTube", destination: video.url)
                        .simultaneousGesture(TapGesture().onEnded {
                            playerViewModel.openInYouTube()
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
                    playerViewModel.toggleSpeech()
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
            playerViewModel.appear()
        }
        .onDisappear {
            playerViewModel.disappear()
        }
        .onChange(of: scenePhase) {
            playerViewModel.scenePhaseChanged(isActive: scenePhase == .active)
        }
    }
}
