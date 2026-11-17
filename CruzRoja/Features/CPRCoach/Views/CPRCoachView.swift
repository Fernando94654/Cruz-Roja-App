import AVFoundation
import SwiftUI

/// Live CPR coach: camera with the rescuer's skeleton, compression counter, rate gauge and spoken corrections.
struct CPRCoachView: View {
    @State var viewModel: CPRCoachViewModel
    @State private var started = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let session = viewModel.provider.captureSession {
                CameraPreview(session: session).ignoresSafeArea()
            }
            SkeletonOverlay(joints: viewModel.joints, imageSize: viewModel.imageSize, armsStraight: viewModel.armsStraight)
                .ignoresSafeArea()

            if started {
                hud
            } else {
                instructions
            }
        }
        .navigationTitle("Coach de RCP")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .onDisappear { viewModel.finish() }
        .sheet(item: Binding(get: { viewModel.summary.map(SummaryItem.init) }, set: { if $0 == nil { viewModel.summary = nil } })) { item in
            CPRSummarySheet(summary: item.summary)
        }
        .alert("Coach de RCP", isPresented: Binding(get: { viewModel.errorMessage != nil }, set: { if !$0 { viewModel.errorMessage = nil } })) {
            Button("Aceptar", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var instructions: some View {
        VStack(spacing: 16) {
            Spacer()
            VStack(alignment: .leading, spacing: 10) {
                Label("Coloca el teléfono de lado, a 1.5 m y a la altura de tu pecho.", systemImage: "iphone.gen3")
                Label("Arrodíllate junto a la persona con los brazos rectos.", systemImage: "figure.stand")
                Label("Empuja fuerte y rápido en el centro del pecho.", systemImage: "hand.raised.fill")
            }
            .font(.callout)
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))

            Text("Es una guía de práctica; no sustituye la capacitación de Cruz Roja.")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)

            Button {
                started = true
                Task { await viewModel.start() }
            } label: {
                Text("Iniciar")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.brandRed)
            .controlSize(.large)
        }
        .padding()
    }

    private var hud: some View {
        VStack {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("COMPRESIONES").font(.caption.bold())
                    Text("\(viewModel.count)")
                        .font(.system(size: 56, weight: .heavy, design: .rounded))
                        .contentTransition(.numericText())
                        .animation(.snappy, value: viewModel.count)
                    Text(timeText(viewModel.elapsed)).font(.caption.monospacedDigit())
                }
                Spacer()
                VStack(spacing: 4) {
                    RateGauge(rate: viewModel.rate, config: viewModel.config)
                        .frame(width: 140, height: 90)
                    armsLabel
                }
            }
            .foregroundStyle(.white)
            .padding()
            .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal)

            Spacer()

            if let message = viewModel.message {
                Text(message)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.black.opacity(0.65), in: Capsule())
                    .transition(.opacity)
            }

            Button(role: .destructive) {
                viewModel.finish()
            } label: {
                Text("Terminar").font(.headline).frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.brandRed)
            .controlSize(.large)
            .padding()
            .disabled(!viewModel.isRunning)
        }
        .animation(.easeInOut, value: viewModel.message)
    }

    private var armsLabel: some View {
        let (text, color): (String, Color) = switch viewModel.armsStraight {
        case true?: ("Brazos rectos", .green)
        case false?: ("Estira los brazos", .red)
        case nil: ("Colócate de lado", .orange)
        }
        return Text(text).font(.caption.bold()).foregroundStyle(color)
    }

    private func timeText(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    // Identifiable wrapper for the summary sheet
    private struct SummaryItem: Identifiable {
        let summary: CPRSessionSummary
        var id: Int { summary.compressions }
    }
}

/// Semicircle speedometer: red below 100, green 100-120, red above.
struct RateGauge: View {
    let rate: Double?
    let config: CPRConfig
    private let range = 60.0...160.0

    var body: some View {
        VStack(spacing: 0) {
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height - 6)
                let radius = min(size.width / 2, size.height) - 10
                let zones: [(Double, Double, Color)] = [
                    (range.lowerBound, config.targetMinRate, .red),
                    (config.targetMinRate, config.targetMaxRate, .green),
                    (config.targetMaxRate, range.upperBound, .red),
                ]
                for (lo, hi, color) in zones {
                    var arc = Path()
                    arc.addArc(center: center, radius: radius, startAngle: angle(lo), endAngle: angle(hi), clockwise: false)
                    context.stroke(arc, with: .color(color), style: StrokeStyle(lineWidth: 12, lineCap: .butt))
                }
                if let rate {
                    let a = angle(rate).radians
                    var needle = Path()
                    needle.move(to: center)
                    needle.addLine(to: CGPoint(x: center.x + (radius - 4) * cos(a), y: center.y + (radius - 4) * sin(a)))
                    context.stroke(needle, with: .color(.white), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                }
                context.fill(Path(ellipseIn: CGRect(x: center.x - 6, y: center.y - 6, width: 12, height: 12)), with: .color(.white))
            }
            Text(rate.map { "\(Int($0.rounded())) por min" } ?? "-- por min")
                .font(.caption.bold().monospacedDigit())
                .foregroundStyle(rateColor)
        }
        .animation(.easeOut(duration: 0.3), value: rate)
    }

    private var rateColor: Color {
        guard let rate else { return .orange }
        return (config.targetMinRate...config.targetMaxRate).contains(rate) ? .green : .red
    }

    // 180° is the left end of the arc and 360° the right end
    private func angle(_ value: Double) -> Angle {
        let clamped = min(max(value, range.lowerBound), range.upperBound)
        return .degrees(180 + 180 * (clamped - range.lowerBound) / (range.upperBound - range.lowerBound))
    }
}

/// Arms and torso drawn over the camera; the measured arm turns red when it bends.
struct SkeletonOverlay: View {
    let joints: BodyJoints?
    let imageSize: CGSize
    let armsStraight: Bool?

    var body: some View {
        Canvas { context, size in
            guard let joints, imageSize.width > 0, imageSize.height > 0 else { return }
            // Same aspect-fit rectangle the preview layer uses
            let rect = AVMakeRect(aspectRatio: imageSize, insideRect: CGRect(origin: .zero, size: size))
            func map(_ p: CGPoint) -> CGPoint {
                CGPoint(x: rect.minX + p.x / imageSize.width * rect.width, y: rect.minY + p.y / imageSize.height * rect.height)
            }
            let best = joints.bestArm
            let other = best == joints.left ? joints.right : joints.left
            for (arm, color) in [(other, Color.white.opacity(0.6)), (best, armsStraight == false ? Color.red : .green)] {
                var path = Path()
                path.move(to: map(arm.hip))
                path.addLine(to: map(arm.shoulder))
                path.addLine(to: map(arm.elbow))
                path.addLine(to: map(arm.wrist))
                context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                for p in [arm.hip, arm.shoulder, arm.elbow, arm.wrist] {
                    let c = map(p)
                    context.fill(Path(ellipseIn: CGRect(x: c.x - 7, y: c.y - 7, width: 14, height: 14)), with: .color(.white))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// End-of-session totals.
struct CPRSummarySheet: View {
    let summary: CPRSessionSummary
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                LabeledContent("Compresiones", value: "\(summary.compressions)")
                LabeledContent("Ritmo promedio", value: summary.averageRate.map { "\($0) por min" } ?? "—")
                LabeledContent("Tiempo en ritmo correcto", value: "\(summary.timeInRangePercent)%")
                LabeledContent("Tiempo con brazos rectos", value: "\(summary.straightArmsPercent)%")
                LabeledContent("Duración", value: "\(Int(summary.duration)) s")
            }
            .navigationTitle("Resumen de RCP")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

/// Live camera preview with the same aspect fit as the skeleton overlay.
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspect
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}

#Preview {
    NavigationStack {
        CPRCoachView(viewModel: CPRCoachViewModel(provider: MockBodyPoseProvider(), speech: SilentSpeech()))
    }
}
