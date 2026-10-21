package mx.cruzroja.enlacevital.features.emergency.ui

import androidx.navigation.NavGraphBuilder
import androidx.navigation.NavHostController
import androidx.navigation.compose.composable
import mx.cruzroja.enlacevital.app.containerViewModel
import mx.cruzroja.enlacevital.features.firstaid.model.FirstAidGuide
import mx.cruzroja.enlacevital.features.firstaid.ui.FirstAidScreen
import mx.cruzroja.enlacevital.features.firstaid.ui.GuideScreen

object EmergencyRoutes {
    const val HOME = "home"
    const val REPORT = "report"
    const val SUMMARY = "summary"
    const val FIRST_AID = "firstaid"
    const val GUIDE = "guide/{id}"

    fun guide(id: String) = "guide/$id"
}

// The same report flow is reachable from Emergency and Family
fun NavGraphBuilder.emergencyDestinations(navController: NavHostController, reportViewModel: EmergencyReportViewModel) {
    composable(EmergencyRoutes.REPORT) {
        ReportScreen(reportViewModel, onBack = navController::popBackStack, onContinue = { navController.navigate(EmergencyRoutes.SUMMARY) })
    }
    composable(EmergencyRoutes.SUMMARY) {
        SummaryScreen(reportViewModel, onBack = navController::popBackStack, onFirstAid = { navController.navigate(EmergencyRoutes.FIRST_AID) })
    }
    composable(EmergencyRoutes.FIRST_AID) {
        FirstAidScreen(
            viewModel = containerViewModel { makeFirstAidViewModel() },
            onBack = navController::popBackStack,
            onGuide = { navController.navigate(EmergencyRoutes.guide(it.id)) },
        )
    }
    composable(EmergencyRoutes.GUIDE) { entry ->
        val id = entry.arguments?.getString("id").orEmpty()
        GuideScreen(viewModel = containerViewModel(key = "guide-$id") { makeGuideViewModel(FirstAidGuide.byId(id)) }, onBack = navController::popBackStack)
    }
}
