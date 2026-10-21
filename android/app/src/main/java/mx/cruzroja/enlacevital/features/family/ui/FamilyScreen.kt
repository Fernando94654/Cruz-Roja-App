package mx.cruzroja.enlacevital.features.family.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import mx.cruzroja.enlacevital.app.containerViewModel
import mx.cruzroja.enlacevital.core.design.BrandRed
import mx.cruzroja.enlacevital.core.design.ScreenScaffold
import mx.cruzroja.enlacevital.core.design.Section
import mx.cruzroja.enlacevital.core.location.Coordinate
import mx.cruzroja.enlacevital.core.map.MapMarker
import mx.cruzroja.enlacevital.core.map.OsmMap
import mx.cruzroja.enlacevital.features.emergency.ui.EmergencyRoutes
import mx.cruzroja.enlacevital.features.emergency.ui.emergencyDestinations
import mx.cruzroja.enlacevital.features.family.model.FamilyAlert

private val MAP_CENTER = Coordinate(25.658, -100.295)

@Composable
fun FamilyTab() {
    val navController = rememberNavController()
    val viewModel = containerViewModel { makeFamilyViewModel() }
    val reportViewModel = containerViewModel(key = "family-report") { makeEmergencyReportViewModel() }

    NavHost(navController, startDestination = EmergencyRoutes.HOME) {
        composable(EmergencyRoutes.HOME) {
            FamilyScreen(viewModel, onReportForMember = {
                reportViewModel.replaceReport(viewModel.reportForActiveAlert())
                navController.navigate(EmergencyRoutes.REPORT)
            })
        }
        emergencyDestinations(navController, reportViewModel)
    }
}

@Composable
private fun FamilyScreen(viewModel: FamilyViewModel, onReportForMember: () -> Unit) {
    val state by viewModel.state.collectAsState()

    ScreenScaffold(title = "Familia") { padding ->
        Column(Modifier.padding(padding).verticalScroll(rememberScrollState())) {
            state.activeAlert?.let { alert ->
                Section { AlertCard(alert, state.hasSentWellbeingCheck, viewModel::sendWellbeingCheck, onReportForMember) }
            }
            Section(title = "Mi círculo") {
                state.members.forEachIndexed { i, member ->
                    if (i > 0) HorizontalDivider()
                    Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(vertical = 4.dp)) {
                        Box(
                            Modifier.size(38.dp).clip(CircleShape).background(if (member.hasAlert) BrandRed else Color.Gray),
                            contentAlignment = Alignment.Center,
                        ) { Text(member.name.take(1), color = Color.White, fontWeight = FontWeight.SemiBold) }
                        Text(member.name, modifier = Modifier.weight(1f).padding(start = 12.dp))
                        Text(member.status, color = if (member.hasAlert) BrandRed else Color.Gray)
                    }
                }
            }
            Section(title = "Ubicación compartida") {
                OsmMap(
                    center = MAP_CENTER,
                    zoom = 13.0,
                    markers = state.members.map { MapMarker(it.name, it.coordinate, if (it.hasAlert) BrandRed else Color.Gray) },
                    modifier = Modifier.fillMaxWidth().height(220.dp).clip(RoundedCornerShape(10.dp)),
                )
            }
        }
    }
}

@Composable
private fun AlertCard(alert: FamilyAlert, hasSentCheck: Boolean, onCheck: () -> Unit, onReport: () -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp), modifier = Modifier.padding(vertical = 6.dp)) {
        Row(verticalAlignment = Alignment.Top) {
            Icon(Icons.Filled.Favorite, contentDescription = null, tint = BrandRed)
            Column(Modifier.padding(start = 10.dp)) {
                Text(alert.title, fontWeight = FontWeight.SemiBold)
                Text(alert.detail, color = Color.Gray)
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            OutlinedButton(onClick = onCheck, enabled = !hasSentCheck) {
                Text(if (hasSentCheck) "Enviado" else "¿Estás bien?", color = if (hasSentCheck) Color.Gray else Color.Black)
            }
            Button(onClick = onReport, colors = ButtonDefaults.buttonColors(containerColor = BrandRed)) { Text("Reportar por ella") }
        }
    }
}
