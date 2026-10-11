import SwiftUI
import MapKit

struct FamiliaView: View {
    @State private var ruta: [Pantalla] = []
    @State private var preguntado = false
    // el reporte ya lleva el perfil de mamá
    @State private var reporte: Reporte = {
        let r = Reporte()
        r.paraQuien = "Para un familiar"
        r.nombre = "Mamá"
        r.motivo = "Ritmo cardiaco anormal"
        return r
    }()

    var body: some View {
        NavigationStack(path: $ruta) {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "heart.fill")
                                .foregroundStyle(Color.rojo)
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Mamá registró un ritmo cardiaco anormal")
                                    .font(.headline)
                                Text("Hace 2 min · Apple Watch")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        HStack {
                            Button(preguntado ? "Enviado" : "¿Estás bien?") {
                                preguntado = true
                            }
                            .buttonStyle(.bordered)
                            .tint(.primary)
                            .disabled(preguntado)

                            Button("Reportar por ella") {
                                ruta = [.reporte]
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color.rojo)
                        }
                    }
                    .padding(.vertical, 6)
                }

                Section("Mi círculo") {
                    ForEach(familia) { f in
                        HStack(spacing: 12) {
                            Text(String(f.nombre.prefix(1)))
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(width: 38, height: 38)
                                .background(f.alerta ? Color.rojo : Color.gray, in: Circle())
                            Text(f.nombre)
                            Spacer()
                            Text(f.estado)
                                .font(.subheadline)
                                .foregroundStyle(f.alerta ? Color.rojo : .secondary)
                        }
                    }
                }

                Section("Ubicación compartida") {
                    Map(initialPosition: .region(MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: 25.658, longitude: -100.295),
                        span: MKCoordinateSpan(latitudeDelta: 0.045, longitudeDelta: 0.045)))) {
                        ForEach(familia) { f in
                            Marker(f.nombre, coordinate: f.coordenada)
                                .tint(f.alerta ? Color.rojo : .gray)
                        }
                    }
                    .frame(height: 220)
                    .listRowInsets(EdgeInsets())
                }
            }
            .navigationTitle("Familia")
            .pantallas(reporte)
        }
    }
}

#Preview {
    FamiliaView()
}
