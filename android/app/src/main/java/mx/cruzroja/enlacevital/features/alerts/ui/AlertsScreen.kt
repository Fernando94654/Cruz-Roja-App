package mx.cruzroja.enlacevital.features.alerts.ui

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.Thunderstorm
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.MenuAnchorType
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import mx.cruzroja.enlacevital.app.containerViewModel
import mx.cruzroja.enlacevital.core.design.BrandRed
import mx.cruzroja.enlacevital.core.design.ScreenScaffold
import mx.cruzroja.enlacevital.core.design.Section
import mx.cruzroja.enlacevital.core.design.relativeTime
import mx.cruzroja.enlacevital.features.alerts.model.CommunityReport
import mx.cruzroja.enlacevital.features.alerts.model.CommunityReportCategory
import mx.cruzroja.enlacevital.features.alerts.model.OfficialAlert

@Composable
fun AlertsTab() {
    val viewModel = containerViewModel { makeAlertsViewModel() }
    val state by viewModel.state.collectAsState()
    var showsNewReport by remember { mutableStateOf(false) }

    ScreenScaffold(
        title = "Alertas",
        bottomBar = {
            Surface(color = Color.Transparent) {
                Button(
                    onClick = { showsNewReport = true },
                    colors = ButtonDefaults.buttonColors(containerColor = Color.Black),
                    modifier = Modifier.fillMaxWidth().padding(16.dp).height(50.dp),
                ) {
                    Icon(Icons.Filled.Add, contentDescription = null)
                    Text(" Reportar algo en mi zona", fontWeight = FontWeight.SemiBold)
                }
            }
        },
    ) { padding ->
        Column(Modifier.padding(padding).verticalScroll(rememberScrollState())) {
            Section(title = "Alertas oficiales") {
                state.officialAlerts.forEachIndexed { i, alert ->
                    if (i > 0) HorizontalDivider()
                    OfficialAlertRow(alert)
                }
            }
            Section(title = "Reportes de vecinos") {
                state.activeReports.forEachIndexed { i, report ->
                    if (i > 0) HorizontalDivider()
                    CommunityReportRow(report, onConfirm = { viewModel.confirm(report) })
                }
            }
        }
    }

    if (showsNewReport) {
        NewCommunityReportSheet(
            onDismiss = { showsNewReport = false },
            onPublish = { category, title -> viewModel.publish(category, title) { showsNewReport = false } },
        )
    }
}

@Composable
private fun OfficialAlertRow(alert: OfficialAlert) {
    Row(Modifier.padding(vertical = 4.dp), verticalAlignment = Alignment.Top) {
        Icon(if (alert.isWeather) Icons.Filled.Thunderstorm else Icons.Filled.Warning, contentDescription = null, tint = BrandRed)
        Column(Modifier.padding(start = 12.dp)) {
            Text(alert.title, fontWeight = FontWeight.SemiBold)
            alert.message?.let { Text(it, color = Color.Gray) }
            Text("${alert.source} · ${alert.areaName} · ${relativeTime(alert.issuedAt)}", style = MaterialTheme.typography.bodySmall, color = Color.Gray)
        }
    }
}

@Composable
private fun CommunityReportRow(report: CommunityReport, onConfirm: () -> Unit) {
    Column(Modifier.padding(vertical = 4.dp)) {
        Text(report.title, fontWeight = FontWeight.SemiBold)
        Text(
            "${report.category.label} · confirmado por ${report.confirmations} vecinos · expira ${relativeTime(report.expiresAt)}",
            color = Color.Gray,
        )
        OutlinedButton(onClick = onConfirm, enabled = !report.confirmedByMe, modifier = Modifier.padding(top = 4.dp)) {
            Text(if (report.confirmedByMe) "Confirmado" else "Confirmar", color = if (report.confirmedByMe) Color.Gray else Color.Black)
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun NewCommunityReportSheet(onDismiss: () -> Unit, onPublish: (CommunityReportCategory, String) -> Unit) {
    var category by remember { mutableStateOf(CommunityReportCategory.FLOOD) }
    var title by remember { mutableStateOf("") }
    var expanded by remember { mutableStateOf(false) }

    ModalBottomSheet(onDismissRequest = onDismiss, containerColor = Color.White) {
        Column(Modifier.padding(horizontal = 16.dp).padding(bottom = 24.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                TextButton(onClick = onDismiss) { Text("Cancelar") }
                Text("Nuevo reporte", fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f), textAlign = TextAlign.Center)
                TextButton(onClick = { onPublish(category, title) }, enabled = title.isNotBlank()) { Text("Publicar") }
            }
            ExposedDropdownMenuBox(expanded = expanded, onExpandedChange = { expanded = it }) {
                OutlinedTextField(
                    value = category.label,
                    onValueChange = {},
                    readOnly = true,
                    label = { Text("Tipo") },
                    trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded) },
                    modifier = Modifier.fillMaxWidth().menuAnchor(MenuAnchorType.PrimaryNotEditable),
                )
                ExposedDropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
                    CommunityReportCategory.entries.forEach { option ->
                        DropdownMenuItem(text = { Text(option.label) }, onClick = { category = option; expanded = false })
                    }
                }
            }
            OutlinedTextField(
                value = title,
                onValueChange = { title = it },
                label = { Text("¿Qué pasó? Ej. Calle inundada") },
                modifier = Modifier.fillMaxWidth().padding(top = 12.dp),
            )
            Row(Modifier.padding(top = 12.dp), verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Filled.LocationOn, contentDescription = null, tint = Color.Gray)
                Text(" Se usará tu ubicación actual", color = Color.Gray)
            }
        }
    }
}
