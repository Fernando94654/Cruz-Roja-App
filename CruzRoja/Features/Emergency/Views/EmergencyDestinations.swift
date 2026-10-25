import SwiftUI

extension View {
    // The same report flow is reachable from Emergency and Family
    func emergencyDestinations(report viewModel: EmergencyReportViewModel, container: AppContainer) -> some View {
        navigationDestination(for: EmergencyRoute.self) { route in
            switch route {
            case .report: ReportView(viewModel: viewModel)
            case .summary: SummaryView(viewModel: viewModel)
            case .firstAid: FirstAidView(viewModel: container.makeFirstAidViewModel()).ambulanceStatus(container)
            case .guide(let guide):
                GuideView(viewModel: container.makeGuideViewModel(guide: guide)).ambulanceStatus(container, announcesArrival: true)
            case .lesson(let lesson, let autoplay):
                LessonView(viewModel: container.makeLessonViewModel(lesson: lesson), autoplay: autoplay)
            }
        }
    }
}
