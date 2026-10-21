import MapKit
import SwiftUI

struct FamilyView: View {
    let container: AppContainer
    @State private var viewModel: FamilyViewModel
    @State private var reportViewModel: EmergencyReportViewModel
    @State private var path: [EmergencyRoute] = []

    private static let mapCenter = Coordinate(latitude: 25.658, longitude: -100.295)

    init(container: AppContainer) {
        self.container = container
        _viewModel = State(initialValue: container.makeFamilyViewModel())
        _reportViewModel = State(initialValue: container.makeEmergencyReportViewModel())
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if let alert = viewModel.activeAlert {
                    Section { alertCard(alert) }
                }

                Section("Mi círculo") {
                    ForEach(viewModel.members) { member in
                        HStack(spacing: 12) {
                            Text(String(member.name.prefix(1)))
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(width: 38, height: 38)
                                .background(member.hasAlert ? Color.brandRed : Color.gray, in: Circle())
                            Text(member.name)
                            Spacer()
                            Text(member.status)
                                .font(.subheadline)
                                .foregroundStyle(member.hasAlert ? Color.brandRed : .secondary)
                        }
                    }
                }

                Section("Ubicación compartida") {
                    Map(initialPosition: .region(MKCoordinateRegion(
                        center: CLLocationCoordinate2D(Self.mapCenter),
                        span: MKCoordinateSpan(latitudeDelta: 0.045, longitudeDelta: 0.045)))) {
                        ForEach(viewModel.members) { member in
                            Marker(member.name, coordinate: CLLocationCoordinate2D(member.coordinate))
                                .tint(member.hasAlert ? Color.brandRed : .gray)
                        }
                    }
                    .frame(height: 220)
                    .listRowInsets(EdgeInsets())
                }
            }
            .navigationTitle("Familia")
            .task { await viewModel.load() }
            .emergencyDestinations(report: reportViewModel, container: container)
        }
    }

    private func alertCard(_ alert: FamilyAlert) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "heart.fill")
                    .foregroundStyle(Color.brandRed)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(alert.title)
                        .font(.headline)
                    Text(alert.detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            HStack {
                Button(viewModel.hasSentWellbeingCheck ? "Enviado" : "¿Estás bien?") {
                    Task { await viewModel.sendWellbeingCheck() }
                }
                .buttonStyle(.bordered)
                .tint(.primary)
                .disabled(viewModel.hasSentWellbeingCheck)

                Button("Reportar por ella") {
                    reportViewModel = container.makeEmergencyReportViewModel(report: viewModel.reportForActiveAlert())
                    path = [.report]
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.brandRed)
            }
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    FamilyView(container: .preview)
}
