import SwiftUI

struct GuideView: View {
    @State private var viewModel: GuideViewModel

    init(viewModel: GuideViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    private var step: GuideStep { viewModel.step }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            AmbulanceStatusBar(ambulance: viewModel.ambulance)

            VStack(alignment: .leading, spacing: 8) {
                Text("Paso \(viewModel.stepIndex + 1) de \(viewModel.guide.steps.count)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                ProgressView(value: Double(viewModel.stepIndex + 1), total: Double(viewModel.guide.steps.count))
                    .tint(Color.brandRed)
            }

            Spacer()

            HStack {
                Spacer()
                indicator
                Spacer()
            }

            Text(step.title)
                .font(.brand(28))
            Text(step.instruction)
                .font(.title3)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            HStack(spacing: 12) {
                Button {
                    withAnimation { viewModel.previous() }
                } label: {
                    Text("Anterior").frame(maxWidth: .infinity).frame(height: 44)
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isFirstStep)

                Button {
                    viewModel.repeatInstruction()
                } label: {
                    Image(systemName: "arrow.counterclockwise").frame(width: 44, height: 44)
                }
                .buttonStyle(.bordered)

                Button {
                    withAnimation { viewModel.next() }
                } label: {
                    Text("Siguiente").frame(maxWidth: .infinity).frame(height: 44)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isLastStep)
            }
            .tint(.black)

            if viewModel.isLastStep {
                RelatedLessonLink(guideID: viewModel.guide.id, lessons: viewModel.lessons, stopSpeech: viewModel.stop)
            }

            Text("Basado en protocolos de Cruz Roja")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
        }
        .padding()
        .navigationTitle(viewModel.guide.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button {
                viewModel.isMuted.toggle()
            } label: {
                Image(systemName: viewModel.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
            }
            .tint(.primary)
        }
        .task(id: viewModel.stepIndex) { await viewModel.runStep() }
        .task(id: viewModel.stepIndex) { await viewModel.runBeat() }
        .onChange(of: viewModel.ambulance.hasArrived) { viewModel.announceArrivalIfNeeded() }
        .onAppear { viewModel.start() }
        .onDisappear { viewModel.stop() }
        .sensoryFeedback(.impact(weight: .heavy), trigger: viewModel.beat)
    }

    private var indicator: some View {
        ZStack {
            Circle().fill(.gray.opacity(0.12))
            if let total = step.seconds, let left = viewModel.secondsLeft {
                Circle()
                    .trim(from: 0, to: Double(left) / Double(total))
                    .stroke(Color.brandRed, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: left)
                    .padding(4)
            }
            VStack(spacing: 6) {
                Image(systemName: step.icon)
                    .font(.system(size: 52))
                    .foregroundStyle(Color.brandRed)
                    .scaleEffect(step.rate != nil && viewModel.beat ? 1.15 : 1)
                    .animation(.easeOut(duration: 0.1), value: viewModel.beat)
                if let left = viewModel.secondsLeft {
                    Text(String(format: "%d:%02d", left / 60, left % 60))
                        .font(.title3.monospacedDigit().weight(.semibold))
                }
                if let rate = step.rate {
                    Text("\(rate) por minuto")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 190, height: 190)
    }
}

#Preview {
    let container = AppContainer.preview
    GuidesRefreshed(container: container) {
        NavigationStack { GuideView(viewModel: container.makeGuideViewModel(guide: container.guides[0])) }
    }
}
