import MapKit
import SwiftUI

struct FamilyMemberView: View {
    let viewModel: FamilyViewModel
    let memberID: UUID
    let onReport: (FamilyMember) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var confirmsRemove = false

    var body: some View {
        if let member = viewModel.member(id: memberID) {
            content(member)
        } else {
            ContentUnavailableView("Ya no está en tu familia", systemImage: "person.slash")
        }
    }

    private func content(_ member: FamilyMember) -> some View {
        List {
            Section {
                VStack(spacing: 6) {
                    MemberAvatar(member: member, size: 72)
                    Text(member.name)
                        .font(.title2.bold())
                    if let relationship = member.relationship {
                        Text(relationship)
                            .foregroundStyle(.secondary)
                    }
                    StatusLabel(status: member.status)
                        .font(.subheadline)
                        .padding(.top, 2)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }

            Section {
                MemberActions(member: member, viewModel: viewModel, onReport: onReport)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }

            Section {
                if let coordinate = member.sharedCoordinate {
                    Map(initialPosition: .region(MKCoordinateRegion(
                        center: CLLocationCoordinate2D(coordinate),
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)))) {
                        Marker(member.firstName, systemImage: "person.fill",
                               coordinate: CLLocationCoordinate2D(coordinate))
                            .tint(member.status.color)
                    }
                    .frame(height: 200)
                    .listRowInsets(EdgeInsets())
                } else {
                    Label("\(member.firstName) no comparte su ubicación", systemImage: "location.slash")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Ubicación")
            } footer: {
                Text([viewModel.distance(to: member),
                      "actualizado \(member.updatedAt.formatted(.relative(presentation: .named)))"]
                    .compactMap { $0 }.joined(separator: " · ").capitalizedFirst)
            }

            Section {
                Button {
                    Task { await viewModel.askIfOK(member) }
                } label: {
                    Label(member.status == .waiting ? "Esperando su respuesta…" : "Preguntar si está bien",
                          systemImage: "questionmark.bubble")
                }
                .disabled(member.status == .waiting)
            } footer: {
                Text("Te avisamos aquí en cuanto conteste.")
            }

            if let phone = member.formattedPhone {
                Section {
                    LabeledContent("Celular", value: phone)
                        .textSelection(.enabled)
                }
            }

            Section {
                Button("Quitar de mi familia", role: .destructive) {
                    confirmsRemove = true
                }
            }
        }
        .disabled(viewModel.isBusy)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await viewModel.load() }
        .confirmationDialog("¿Quitar a \(member.firstName) de tu familia?", isPresented: $confirmsRemove,
                            titleVisibility: .visible) {
            Button("Quitar", role: .destructive) {
                Task {
                    if await viewModel.remove(member) { dismiss() }
                }
            }
        } message: {
            Text("Dejará de ver cómo estás y dónde estás.")
        }
    }
}
