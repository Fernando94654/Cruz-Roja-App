package mx.cruzroja.enlacevital

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain
import mx.cruzroja.enlacevital.core.networking.ApiError
import mx.cruzroja.enlacevital.features.alerts.data.AlertsService
import mx.cruzroja.enlacevital.features.alerts.data.MockAlertsService
import mx.cruzroja.enlacevital.features.alerts.ui.AlertsViewModel
import mx.cruzroja.enlacevital.features.medicalprofile.data.MedicalProfileCache
import mx.cruzroja.enlacevital.features.medicalprofile.data.MedicalProfileService
import mx.cruzroja.enlacevital.features.medicalprofile.data.MockMedicalProfileService
import mx.cruzroja.enlacevital.features.medicalprofile.model.MedicalProfile
import mx.cruzroja.enlacevital.features.medicalprofile.ui.LoadState
import mx.cruzroja.enlacevital.features.medicalprofile.ui.MedicalProfileViewModel
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

@OptIn(ExperimentalCoroutinesApi::class)
class ViewModelTests {
    @get:Rule
    val folder = TemporaryFolder()

    @Before
    fun setUp() = Dispatchers.setMain(UnconfinedTestDispatcher())

    @After
    fun tearDown() = Dispatchers.resetMain()

    private class OfflineProfileService : MedicalProfileService {
        override suspend fun fetchProfile(userId: String): MedicalProfile? = throw ApiError.Offline
        override suspend fun saveProfile(profile: MedicalProfile, userId: String): MedicalProfile = throw ApiError.Offline
    }

    @Test
    fun profileFallsBackToCachedCopyWhenOffline() {
        val cache = MedicalProfileCache(folder.root).apply { save(MedicalProfile.SAMPLE) }
        val state = MedicalProfileViewModel(OfflineProfileService(), cache).state.value

        assertEquals(LoadState.Ready, state.loadState)
        assertTrue(state.isShowingCachedCopy)
        assertEquals("María López", state.profile?.fullName)
    }

    @Test
    fun profileFailsWhenOfflineWithoutCache() {
        val state = MedicalProfileViewModel(OfflineProfileService(), MedicalProfileCache(folder.root)).state.value
        assertEquals(LoadState.Failed(ApiError.Offline.message!!), state.loadState)
    }

    @Test
    fun invalidProfileIsNotSaved() {
        val viewModel = MedicalProfileViewModel(MockMedicalProfileService(), MedicalProfileCache(folder.root))
        var saved = false
        viewModel.save(MedicalProfile(fullName = " ")) { saved = true }

        assertFalse(saved)
        assertEquals("Escribe el nombre de la persona.", viewModel.state.value.errorMessage)
    }

    private class FailingConfirmService(private val inner: AlertsService = MockAlertsService()) : AlertsService by inner {
        override suspend fun confirm(reportId: String) = throw ApiError.Offline
    }

    @Test
    fun confirmIsOptimisticAndCountsOnce() {
        val viewModel = AlertsViewModel(MockAlertsService())
        val report = viewModel.state.value.reports.first()
        viewModel.confirm(report)
        viewModel.confirm(report)

        val updated = viewModel.state.value.reports.first()
        assertTrue(updated.confirmedByMe)
        assertEquals(report.confirmations + 1, updated.confirmations)
    }

    @Test
    fun confirmRollsBackWhenRequestFails() {
        val viewModel = AlertsViewModel(FailingConfirmService())
        val report = viewModel.state.value.reports.first()
        viewModel.confirm(report)

        val updated = viewModel.state.value.reports.first()
        assertFalse(updated.confirmedByMe)
        assertEquals(report.confirmations, updated.confirmations)
        assertEquals(ApiError.Offline.message, viewModel.state.value.errorMessage)
    }
}
