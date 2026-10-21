import SwiftUI

struct AmbulanceStatusBar: View {
    let ambulance: AmbulanceTracker

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: ambulance.hasArrived ? "checkmark.circle.fill" : "cross.case.fill")
                    .font(.title3)
                    .foregroundStyle(ambulance.hasArrived ? Color.primary : Color.brandRed)
                    .symbolEffect(.pulse, isActive: !ambulance.hasArrived)
                VStack(alignment: .leading) {
                    Text(ambulance.status).font(.headline)
                    Text(ambulance.unit).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if !ambulance.hasArrived {
                    Text(ambulance.timeLeft)
                        .font(.title3.monospacedDigit().weight(.semibold))
                        .contentTransition(.numericText())
                }
            }
            ProgressView(value: ambulance.progress)
                .tint(Color.brandRed)
        }
        .padding()
        .background(.gray.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
    }
}
