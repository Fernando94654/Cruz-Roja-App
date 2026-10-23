import Foundation

// Composition root: builds the services once and hands each ViewModel its dependencies
@MainActor
final class AppContainer {
    let session: SessionStore
    let speech: SpeechSynthesizing
    let ambulance: AmbulanceTracker

    private let authService: AuthServicing
    private let medicalProfileService: MedicalProfileServicing
    private let medicalProfileCache: MedicalProfileCache
    private let emergencyReportService: EmergencyReportServicing
    private let firstAidAssistant: FirstAidAssisting
    private let alertsService: AlertsServicing
    private let familyService: FamilyServicing
    private let lessonsService: LessonsServicing

    init(
        session: SessionStore,
        speech: SpeechSynthesizing,
        ambulance: AmbulanceTracker,
        authService: AuthServicing = MockAuthService(),
        medicalProfileService: MedicalProfileServicing,
        medicalProfileCache: MedicalProfileCache = MedicalProfileCache(),
        emergencyReportService: EmergencyReportServicing = MockEmergencyReportService(),
        firstAidAssistant: FirstAidAssisting = KeywordFirstAidAssistant(),
        alertsService: AlertsServicing = MockAlertsService(),
        familyService: FamilyServicing = MockFamilyService(),
        lessonsService: LessonsServicing = MockLessonsService()
    ) {
        self.session = session
        self.speech = speech
        self.ambulance = ambulance
        self.authService = authService
        self.medicalProfileService = medicalProfileService
        self.medicalProfileCache = medicalProfileCache
        self.emergencyReportService = emergencyReportService
        self.firstAidAssistant = firstAidAssistant
        self.alertsService = alertsService
        self.familyService = familyService
        self.lessonsService = lessonsService
    }

    static let live = AppContainer(
        session: SessionStore(),
        speech: SpeechService(),
        ambulance: AmbulanceTracker(),
        medicalProfileService: MedicalProfileAPIService(),
        lessonsService: LessonsAPIService()
    )

    static let preview = AppContainer(
        session: SessionStore(defaults: UserDefaults(suiteName: "preview") ?? .standard),
        speech: SilentSpeech(),
        ambulance: AmbulanceTracker(),
        medicalProfileService: MockMedicalProfileService(),
        medicalProfileCache: MedicalProfileCache(directory: FileManager.default.temporaryDirectory)
    )

    // MARK: - ViewModels

    func makeAuthViewModel() -> AuthViewModel {
        AuthViewModel(service: authService, session: session)
    }

    func makeMedicalProfileViewModel() -> MedicalProfileViewModel {
        MedicalProfileViewModel(service: medicalProfileService, cache: medicalProfileCache)
    }

    func makeEmergencyReportViewModel(report: EmergencyReport = EmergencyReport(), isSent: Bool = false) -> EmergencyReportViewModel {
        EmergencyReportViewModel(report: report, isSent: isSent, service: emergencyReportService)
    }

    func makeFirstAidViewModel() -> FirstAidViewModel {
        var messages: [ChatMessage] = []
        if DemoMode.isActive("firstaid") {
            messages = [.user(UUID(), "Me corté y sangra mucho"), .assistant(KeywordFirstAidAssistant().search("sangra"))]
        }
        return FirstAidViewModel(assistant: firstAidAssistant, speech: speech, ambulance: ambulance, lessonsService: lessonsService, messages: messages)
    }

    func makeGuideViewModel(guide: FirstAidGuide) -> GuideViewModel {
        GuideViewModel(guide: guide, speech: speech, ambulance: ambulance, lessonsService: lessonsService)
    }

    func makeAlertsViewModel() -> AlertsViewModel {
        AlertsViewModel(service: alertsService)
    }

    func makeFamilyViewModel() -> FamilyViewModel {
        FamilyViewModel(service: familyService)
    }

    func makeLearnViewModel() -> LearnViewModel {
        LearnViewModel(service: lessonsService)
    }

    func makeLessonViewModel(lesson: Lesson) -> LessonViewModel {
        LessonViewModel(lesson: lesson, speech: speech)
    }
}
