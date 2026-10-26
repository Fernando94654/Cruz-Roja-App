import SwiftUI

extension View {
    // The emergency flow pins the ambulance status on top of the screens it opens
    func ambulanceStatus(_ container: AppContainer, announcesArrival: Bool = false) -> some View {
        modifier(AmbulanceStatus(ambulance: container.ambulance, speech: container.speech,
                                 announcesArrival: announcesArrival))
    }
}

private struct AmbulanceStatus: ViewModifier {
    let ambulance: AmbulanceTracker
    let speech: SpeechSynthesizing
    let announcesArrival: Bool
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .top) {
                AmbulanceStatusBar(ambulance: ambulance)
                    .padding([.horizontal, .bottom])
                    .background(.background)
            }
            .onAppear { isVisible = true }
            .onDisappear { isVisible = false }
            .onChange(of: ambulance.hasArrived) {
                if announcesArrival && isVisible && ambulance.hasArrived {
                    speech.speak("La ambulancia llegó. Cuéntale a los paramédicos qué pasó y qué hiciste.")
                }
            }
    }
}
