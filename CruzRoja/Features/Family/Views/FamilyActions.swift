import MapKit
import SwiftUI

// Call, directions and report for one member, the three things you need in an emergency
struct MemberActions: View {
    let member: FamilyMember
    let viewModel: FamilyViewModel
    let onReport: (FamilyMember) -> Void

    var body: some View {
        HStack(spacing: 8) {
            CallButton(member: member, viewModel: viewModel)
            if let coordinate = member.sharedCoordinate {
                DirectionsMenu(coordinate: coordinate)
            }
            ActionButton("Reportar", systemImage: "staroflife.fill", prominent: true) {
                onReport(member)
            }
        }
    }
}

struct ActionButton: View {
    let title: String
    let systemImage: String
    var prominent = false
    let action: () -> Void

    init(_ title: String, systemImage: String, prominent: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.prominent = prominent
        self.action = action
    }

    var body: some View {
        let button = Button(action: action) {
            ActionLabel(title: title, systemImage: systemImage)
        }
        if prominent {
            button.buttonStyle(.borderedProminent).tint(Color.brandRed)
        } else {
            button.buttonStyle(.bordered).tint(.primary)
        }
    }
}

struct ActionLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
            Text(title)
                .font(.caption.weight(.medium))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 44)
    }
}

struct CallButton: View {
    let member: FamilyMember
    let viewModel: FamilyViewModel
    @Environment(\.openURL) private var openURL

    var body: some View {
        if let url = member.phoneURL {
            ActionButton("Llamar", systemImage: "phone.fill") {
                // The simulator and iPads can't make calls, show the number instead
                openURL(url) { accepted in
                    if !accepted {
                        viewModel.notice = "Este dispositivo no puede llamar. El número de \(member.firstName) es \(member.formattedPhone ?? "")."
                    }
                }
            }
        }
    }
}

struct DirectionsMenu: View {
    let coordinate: Coordinate
    @Environment(\.openURL) private var openURL

    var body: some View {
        Menu {
            Button("Apple Maps", systemImage: "map") { openURL(Directions.appleMaps(to: coordinate)) }
            Button("Google Maps", systemImage: "car") { openURL(Directions.googleMaps(to: coordinate)) }
        } label: {
            ActionLabel(title: "Cómo llegar", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
        }
        .menuStyle(.button)
        .buttonStyle(.bordered)
        .tint(.primary)
    }
}

// Everyone who shares their location, plus me. Tapping someone shows how to reach them
struct FamilyMapSection: View {
    let viewModel: FamilyViewModel
    let onOpen: (FamilyMember) -> Void
    let onReport: (FamilyMember) -> Void
    @State private var selectedID: UUID?
    @State private var position: MapCameraPosition = .automatic

    private var selected: FamilyMember? {
        selectedID.flatMap { viewModel.member(id: $0) }
    }

    private var hiddenNames: [String] {
        viewModel.family.members.filter { $0.sharedCoordinate == nil }.map(\.firstName)
    }

    var body: some View {
        Section {
            Map(position: $position, selection: $selectedID) {
                if let myLocation = viewModel.myLocation {
                    Marker("Tú", systemImage: "person.fill", coordinate: CLLocationCoordinate2D(myLocation))
                        .tint(.blue)
                }
                ForEach(viewModel.membersOnMap) { member in
                    if let coordinate = member.sharedCoordinate {
                        Marker(member.firstName, systemImage: "person.fill",
                               coordinate: CLLocationCoordinate2D(coordinate))
                            .tint(member.status.color)
                            .tag(member.id)
                    }
                }
            }
            .frame(height: 260)
            .listRowInsets(EdgeInsets())
            .overlay(alignment: .topTrailing) {
                if selectedID != nil {
                    Button("Ver a todos", systemImage: "person.3.fill") {
                        withAnimation {
                            selectedID = nil
                            position = .automatic
                        }
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.bordered)
                    .background(.regularMaterial, in: Capsule())
                    .padding(10)
                }
            }
            .onChange(of: selectedID) { _, id in
                guard let coordinate = id.flatMap({ viewModel.member(id: $0)?.sharedCoordinate }) else { return }
                withAnimation {
                    position = .region(MKCoordinateRegion(center: CLLocationCoordinate2D(coordinate),
                                                          span: MKCoordinateSpan(latitudeDelta: 0.015, longitudeDelta: 0.015)))
                }
            }

            if let member = selected {
                VStack(alignment: .leading, spacing: 12) {
                    Button { onOpen(member) } label: {
                        HStack(spacing: 12) {
                            MemberAvatar(member: member, size: 40)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(member.name).font(.headline)
                                Text([viewModel.distance(to: member), member.status.text].compactMap { $0 }.joined(separator: " · "))
                                    .font(.subheadline)
                                    .foregroundStyle(member.status == .needHelp ? Color.brandRed : .secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                    MemberActions(member: member, viewModel: viewModel, onReport: onReport)
                }
                .padding(.vertical, 4)
            } else if !viewModel.membersOnMap.isEmpty {
                Text("Toca a alguien en el mapa para llamarle o ver cómo llegar.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } footer: {
            if !hiddenNames.isEmpty {
                Text("\(ListFormatter.localizedString(byJoining: hiddenNames)) no \(hiddenNames.count == 1 ? "comparte su" : "comparten su") ubicación.")
            }
        }
    }
}

extension FamilyMember {
    var initials: String {
        name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined()
    }
}
