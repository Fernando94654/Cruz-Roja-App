import Foundation

// Composition root: builds the services once and hands each ViewModel its dependencies
@MainActor
final class AppContainer {
    let session: SessionStore
    let speech: SpeechSynthesizing
    let ambulance: AmbulanceTracker
    let locationProvider: LocationProviding
    let dictation: Dictating

    private let authService: AuthServicing
    private let medicalProfileService: MedicalProfileServicing
    private let medicalProfileCache: MedicalProfileCache
    private let emergencyReportService: EmergencyReportServicing
    private let reportExtractor: ReportExtracting
    private let firstAidAssistant: FirstAidAssisting
    private let alertsService: AlertsServicing
    private let familyService: FamilyServicing
    private let lessonsService: LessonsServicing

    init(
        session: SessionStore,
        speech: SpeechSynthesizing,
        ambulance: AmbulanceTracker,
        locationProvider: LocationProviding,
        dictation: Dictating,
        authService: AuthServicing = MockAuthService(),
        medicalProfileService: MedicalProfileServicing,
        medicalProfileCache: MedicalProfileCache = MedicalProfileCache(),
        emergencyReportService: EmergencyReportServicing = MockEmergencyReportService(),
        reportExtractor: ReportExtracting? = nil,
        firstAidAssistant: FirstAidAssisting = KeywordFirstAidAssistant(),
        alertsService: AlertsServicing = MockAlertsService(),
        familyService: FamilyServicing = MockFamilyService(),
        lessonsService: LessonsServicing = MockLessonsService()
    ) {
        self.session = session
        self.speech = speech
        self.ambulance = ambulance
        self.locationProvider = locationProvider
        self.dictation = dictation
        self.authService = authService
        self.medicalProfileService = medicalProfileService
        self.medicalProfileCache = medicalProfileCache
        self.emergencyReportService = emergencyReportService
        self.reportExtractor = reportExtractor ?? RuleBasedReportExtractor()
        self.firstAidAssistant = firstAidAssistant
        self.alertsService = alertsService
        self.familyService = familyService
        self.lessonsService = lessonsService
    }

    static let live = AppContainer(
        session: SessionStore(),
        speech: SpeechService(),
        ambulance: AmbulanceTracker(),
        locationProvider: CoreLocationService(),
        dictation: SpeechDictation(),
        authService: AuthAPIService(),
        medicalProfileService: MedicalProfileAPIService(),
        emergencyReportService: EmergencyReportAPIService(),
        reportExtractor: FallbackReportExtractor(),
        familyService: DemoMode.isActive("family") ? MockFamilyService() : FamilyAPIService(),
        lessonsService: LessonsAPIService()
    )

    static let preview = AppContainer(
        session: SessionStore(defaults: UserDefaults(suiteName: "preview") ?? .standard),
        speech: SilentSpeech(),
        ambulance: AmbulanceTracker(),
        locationProvider: FixedLocationProvider(location: CurrentLocation(
            coordinate: Coordinate(latitude: 25.6516, longitude: -100.2895),
            address: "Ubicación simulada, Monterrey, Nuevo León",
            accuracyMeters: 100
        )),
        dictation: SilentDictation(),
        medicalProfileService: MockMedicalProfileService(),
        medicalProfileCache: MedicalProfileCache(directory: FileManager.default.temporaryDirectory),
        lessonsService: LessonsAPIService()
    )

    // MARK: - ViewModels

    func makeAuthViewModel() -> AuthViewModel {
        AuthViewModel(service: authService, session: session)
    }

    func makeMedicalProfileViewModel() -> MedicalProfileViewModel {
        MedicalProfileViewModel(service: medicalProfileService, cache: medicalProfileCache)
    }

    func makeEmergencyReportViewModel(report: EmergencyReport = EmergencyReport(),
                                      location: EmergencyLocation? = nil, shareURL: String? = nil) -> EmergencyReportViewModel {
        let cache = medicalProfileCache
        return EmergencyReportViewModel(
            report: report,
            location: location,
            shareURL: shareURL,
            service: emergencyReportService,
            extractor: reportExtractor,
            locationProvider: locationProvider,
            dictation: dictation,
            medicalSummary: { cache.load()?.reportSummary }
        )
    }

    // Report filled from the sample description, for the screenshot demo modes
    func demoReport() -> EmergencyReport {
        var report = EmergencyReport()
        report.description = EmergencyReport.demoDescription
        return report.merging(RuleBasedReportExtractor().fields(from: EmergencyReport.demoDescription))
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
        FamilyViewModel(service: familyService, locationProvider: locationProvider)
    }

    func makeLearnViewModel() -> LearnViewModel {
        LearnViewModel(service: lessonsService)
    }

    func makeLessonViewModel(lesson: Lesson) -> LessonViewModel {
        LessonViewModel(lesson: lesson, speech: speech)
    }
}
