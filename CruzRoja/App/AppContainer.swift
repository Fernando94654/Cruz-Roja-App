import Foundation

// Composition root: builds the services once and hands each ViewModel its dependencies
@MainActor
final class AppContainer {
    let session: SessionStore
    let speech: SpeechSynthesizing
    let ambulance: AmbulanceTracker
    let locationProvider: LocationProviding
    let lessonProgress: LessonProgress
    private let dictationFactory: @MainActor () -> Dictating

    private let authService: AuthServicing
    private let medicalProfileService: MedicalProfileServicing
    private let medicalProfileCache: MedicalProfileCache
    private let emergencyReportService: EmergencyReportServicing
    private let reportExtractor: ReportExtracting
    private let firstAidAssistant: FirstAidAssisting
    private let alertsService: AlertsServicing
    private let familyService: FamilyServicing
    private let lessonsService: LessonsServicing
    private let guidesService: GuidesServicing
    private let guideCache: GuideCache

    init(
        session: SessionStore,
        speech: SpeechSynthesizing,
        ambulance: AmbulanceTracker,
        locationProvider: LocationProviding,
        dictation: @escaping @MainActor () -> Dictating,
        authService: AuthServicing = MockAuthService(),
        medicalProfileService: MedicalProfileServicing,
        medicalProfileCache: MedicalProfileCache = MedicalProfileCache(),
        emergencyReportService: EmergencyReportServicing = MockEmergencyReportService(),
        reportExtractor: ReportExtracting? = nil,
        firstAidAssistant: FirstAidAssisting? = nil,
        alertsService: AlertsServicing = MockAlertsService(),
        familyService: FamilyServicing = MockFamilyService(),
        lessonsService: LessonsServicing = MockLessonsService(),
        lessonProgressService: LessonProgressServicing = MockLessonProgressService(),
        lessonProgressStore: LessonProgressStore = LessonProgressStore(),
        guidesService: GuidesServicing = MockGuidesService(),
        guideCache: GuideCache = GuideCache()
    ) {
        self.session = session
        self.speech = speech
        self.ambulance = ambulance
        self.locationProvider = locationProvider
        self.dictationFactory = dictation
        self.authService = authService
        self.medicalProfileService = medicalProfileService
        self.medicalProfileCache = medicalProfileCache
        self.emergencyReportService = emergencyReportService
        self.reportExtractor = reportExtractor ?? RuleBasedReportExtractor()
        self.firstAidAssistant = firstAidAssistant ?? KeywordFirstAidAssistant(guides: { guideCache.load() })
        self.alertsService = alertsService
        self.familyService = familyService
        self.lessonsService = lessonsService
        self.lessonProgress = LessonProgress(service: lessonProgressService, store: lessonProgressStore)
        self.guidesService = guidesService
        self.guideCache = guideCache
    }

    static let live = AppContainer(
        session: SessionStore(),
        speech: SpeechService(),
        ambulance: AmbulanceTracker(),
        locationProvider: CoreLocationService(),
        dictation: { SpeechDictation() },
        authService: AuthAPIService(),
        medicalProfileService: MedicalProfileAPIService(),
        emergencyReportService: EmergencyReportAPIService(),
        reportExtractor: FallbackReportExtractor(),
        alertsService: DemoMode.isActive("alerts") ? MockAlertsService() : AlertsAPIService(locationProvider: CoreLocationService()),
        familyService: DemoMode.isActive("family") ? MockFamilyService() : FamilyAPIService(),
        lessonsService: LessonsAPIService(),
        lessonProgressService: DemoMode.isActive("learn", "lesson") ? MockLessonProgressService() : LessonProgressAPIService(),
        guidesService: GuidesAPIService()
    )

    static let preview = AppContainer(
        session: SessionStore(defaults: UserDefaults(suiteName: "preview") ?? .standard),
        speech: SpeechService(),
        ambulance: AmbulanceTracker(),
        locationProvider: FixedLocationProvider(location: CurrentLocation(
            coordinate: Coordinate(latitude: 25.6516, longitude: -100.2895),
            address: "Ubicación simulada, Monterrey, Nuevo León",
            accuracyMeters: 100
        )),
        dictation: { SpeechDictation() },
        medicalProfileService: MockMedicalProfileService(),
        medicalProfileCache: MedicalProfileCache(directory: FileManager.default.temporaryDirectory),
        lessonsService: LessonsAPIService(),
        lessonProgressService: LessonProgressAPIService(),
        lessonProgressStore: LessonProgressStore(defaults: UserDefaults(suiteName: "preview") ?? .standard),
        guidesService: GuidesAPIService(),
        guideCache: GuideCache(directory: FileManager.default.temporaryDirectory)
    )

    var guides: [FirstAidGuide] { guideCache.load() }

    // Keeps the guides cached for offline use; on failure the last copy (or the bundled one) stays
    func refreshGuides() async {
        guard let guides = try? await guidesService.fetchGuides() else { return }
        guideCache.save(guides)
    }

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
        let ambulance = ambulance
        return EmergencyReportViewModel(
            report: report,
            location: location,
            shareURL: shareURL,
            service: emergencyReportService,
            extractor: reportExtractor,
            locationProvider: locationProvider,
            dictation: dictationFactory(),
            medicalSummary: { cache.load()?.reportSummary },
            onSent: { ambulance.request() }
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
        return FirstAidViewModel(assistant: firstAidAssistant, speech: speech, lessonsService: lessonsService,
                                 guides: guideCache.load(), messages: messages)
    }

    func makeGuideViewModel(guide: FirstAidGuide) -> GuideViewModel {
        GuideViewModel(guide: guide, speech: speech, lessonsService: lessonsService)
    }

    func makeAlertsViewModel() -> AlertsViewModel {
        AlertsViewModel(service: alertsService)
    }

    func makeFamilyViewModel() -> FamilyViewModel {
        FamilyViewModel(service: familyService, locationProvider: locationProvider)
    }

    func makeLearnViewModel() -> LearnViewModel {
        LearnViewModel(service: lessonsService, progress: lessonProgress, guides: guideCache.load())
    }

    func makeLessonViewModel(lesson: Lesson) -> LessonViewModel {
        LessonViewModel(lesson: lesson, speech: speech, progress: lessonProgress)
    }
}
