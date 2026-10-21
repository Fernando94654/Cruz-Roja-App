import MapKit
import SwiftUI

struct EmergencyView: View {
    let container: AppContainer
    @State private var path: [EmergencyRoute]
    @State private var reportViewModel: EmergencyReportViewModel
    @State private var showsCountdown = DemoMode.isActive("countdown")
    @State private var isPressing = false
    @State private var showsConfirmation = DemoMode.isActive("confirm")

    init(container: AppContainer) {
        self.container = container
        _path = State(initialValue: Self.demoPath)
        var report = EmergencyReport()
        if DemoMode.isActive("report", "vitals", "summary", "sent", "firstaid", "guide") { report.applyDictationSample() }
        _reportViewModel = State(initialValue: container.makeEmergencyReportViewModel(report: report, isSent: DemoMode.isActive("sent")))
    }

    private static var demoPath: [EmergencyRoute] {
        switch DemoMode.current {
        case "report", "vitals": [.report]
        case "summary", "sent": [.report, .summary]
        case "firstaid": [.report, .summary, .firstAid]
        case "guide": [.report, .summary, .firstAid, .guide(FirstAidGuide.catalog[0])]
        default: []
        }
    }

    private var location: EmergencyLocation { reportViewModel.location }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Ubicación exacta, ±\(location.accuracyMeters) m", systemImage: "location.fill")
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.gray.opacity(0.12), in: Capsule())

                        Map(initialPosition: .region(MKCoordinateRegion(
                            center: CLLocationCoordinate2D(location.coordinate),
                            span: MKCoordinateSpan(latitudeDelta: 0.006, longitudeDelta: 0.006)))) {
                            Marker("Tú", coordinate: CLLocationCoordinate2D(location.coordinate))
                                .tint(.black)
                        }
                        .frame(height: 170)
                        .clipShape(RoundedRectangle(cornerRadius: 14))

                        Text(location.address)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 24)

                    reportButton

                    Label("Antes de enviar te pediremos confirmar y tendrás 5 segundos para cancelar.", systemImage: "hand.raised")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationTitle("Emergencia")
            .emergencyDestinations(report: reportViewModel, container: container)
        }
        .alert("¿Reportar una emergencia?", isPresented: $showsConfirmation) {
            Button("Cancelar", role: .cancel) {}
            Button("Sí, reportar", role: .destructive) { showsCountdown = true }
        } message: {
            Text("Se enviará tu ubicación exacta a Cruz Roja.")
        }
        .fullScreenCover(isPresented: $showsCountdown) {
            CountdownView {
                showsCountdown = false
                path = [.report]
            }
        }
    }

    // Must be held down to avoid accidental reports
    private var reportButton: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
            Text("Reportar emergencia")
                .font(.brand(24))
            Text(isPressing ? "Sigue presionando…" : "Mantén presionado 3 segundos")
                .font(.subheadline)
                .opacity(0.85)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 200)
        .background(alignment: .leading) {
            ZStack(alignment: .leading) {
                Color.brandRed
                GeometryReader { geo in
                    Color.black.opacity(0.25)
                        .frame(width: isPressing ? geo.size.width : 0)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .scaleEffect(isPressing ? 0.97 : 1)
        .onLongPressGesture(minimumDuration: 3, maximumDistance: 40) {
            isPressing = false
            showsConfirmation = true
        } onPressingChanged: { pressing in
            withAnimation(pressing ? .linear(duration: 3) : .easeOut(duration: 0.2)) {
                isPressing = pressing
            }
        }
        .sensoryFeedback(.warning, trigger: showsConfirmation)
    }
}

struct CountdownView: View {
    var onFinish: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var seconds = 5

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            Text("Enviando reporte en")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("\(seconds)")
                .font(.brand(110))
                .foregroundStyle(.white)
                .frame(width: 210, height: 210)
                .background(Color.brandRed, in: Circle())
                .contentTransition(.numericText())
            Text("Se compartirá tu ubicación con Cruz Roja")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                dismiss()
            } label: {
                Text("Cancelar")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
            }
            .buttonStyle(.bordered)
            .tint(.primary)
            Text("¿Fue un error? Cancela antes de que termine.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .task {
            if DemoMode.isActive("countdown") { seconds = 3; return } // fixed for the screenshot
            while seconds > 0 {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                withAnimation { seconds -= 1 }
            }
            onFinish()
        }
    }
}

#Preview {
    EmergencyView(container: .preview)
}
