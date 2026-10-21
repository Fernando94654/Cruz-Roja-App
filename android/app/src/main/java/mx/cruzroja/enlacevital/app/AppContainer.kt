package mx.cruzroja.enlacevital.app

import android.content.Context
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import mx.cruzroja.enlacevital.core.demo.DemoMode
import mx.cruzroja.enlacevital.core.speech.SpeechSynthesizing
import mx.cruzroja.enlacevital.core.speech.TtsSpeechService
import mx.cruzroja.enlacevital.features.alerts.data.MockAlertsService
import mx.cruzroja.enlacevital.features.alerts.ui.AlertsViewModel
import mx.cruzroja.enlacevital.features.auth.data.MockAuthService
import mx.cruzroja.enlacevital.features.auth.data.SessionStore
import mx.cruzroja.enlacevital.features.auth.ui.AuthViewModel
import mx.cruzroja.enlacevital.features.emergency.data.AmbulanceTracker
import mx.cruzroja.enlacevital.features.emergency.data.MockEmergencyReportService
import mx.cruzroja.enlacevital.features.emergency.model.EmergencyReport
import mx.cruzroja.enlacevital.features.emergency.ui.EmergencyReportViewModel
import mx.cruzroja.enlacevital.features.family.data.MockFamilyService
import mx.cruzroja.enlacevital.features.family.ui.FamilyViewModel
import mx.cruzroja.enlacevital.features.firstaid.data.KeywordFirstAidAssistant
import mx.cruzroja.enlacevital.features.firstaid.model.ChatMessage
import mx.cruzroja.enlacevital.features.firstaid.model.FirstAidGuide
import mx.cruzroja.enlacevital.features.firstaid.ui.FirstAidViewModel
import mx.cruzroja.enlacevital.features.firstaid.ui.GuideViewModel
import mx.cruzroja.enlacevital.features.learn.data.MockLessonsService
import mx.cruzroja.enlacevital.features.learn.model.Lesson
import mx.cruzroja.enlacevital.features.learn.ui.LearnViewModel
import mx.cruzroja.enlacevital.features.learn.ui.LessonViewModel
import mx.cruzroja.enlacevital.features.medicalprofile.data.MedicalProfileApiService
import mx.cruzroja.enlacevital.features.medicalprofile.data.MedicalProfileCache
import mx.cruzroja.enlacevital.features.medicalprofile.ui.MedicalProfileViewModel

// Composition root: builds the services once and hands each ViewModel its dependencies
class AppContainer(context: Context) {
    private val appScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val preferences = context.getSharedPreferences("enlace_vital", Context.MODE_PRIVATE)

    val session = SessionStore(preferences)
    val speech: SpeechSynthesizing = TtsSpeechService(context)
    val ambulance = AmbulanceTracker(appScope)

    private val authService = MockAuthService()
    private val medicalProfileService = MedicalProfileApiService()
    private val medicalProfileCache = MedicalProfileCache(context.filesDir)
    private val emergencyReportService = MockEmergencyReportService()
    private val firstAidAssistant = KeywordFirstAidAssistant()
    private val alertsService = MockAlertsService()
    private val familyService = MockFamilyService()
    private val lessonsService = MockLessonsService()

    fun makeAuthViewModel() = AuthViewModel(authService, session)

    fun makeMedicalProfileViewModel() = MedicalProfileViewModel(medicalProfileService, medicalProfileCache, preferences)

    fun makeEmergencyReportViewModel(report: EmergencyReport = EmergencyReport(), isSent: Boolean = false) =
        EmergencyReportViewModel(emergencyReportService, report, isSent)

    fun makeFirstAidViewModel(): FirstAidViewModel {
        val messages = if (DemoMode.isActive("firstaid")) {
            listOf(ChatMessage.User("Me corté y sangra mucho"), ChatMessage.Assistant(KeywordFirstAidAssistant().search("sangra")))
        } else emptyList()
        return FirstAidViewModel(firstAidAssistant, speech, ambulance, messages)
    }

    fun makeGuideViewModel(guide: FirstAidGuide) = GuideViewModel(guide, speech, ambulance)

    fun makeAlertsViewModel() = AlertsViewModel(alertsService)

    fun makeFamilyViewModel() = FamilyViewModel(familyService)

    fun makeLearnViewModel() = LearnViewModel(lessonsService)

    fun makeLessonViewModel(lesson: Lesson) = LessonViewModel(lesson, speech)
}
