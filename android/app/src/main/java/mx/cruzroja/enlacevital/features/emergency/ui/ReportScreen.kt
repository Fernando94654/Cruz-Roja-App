package mx.cruzroja.enlacevital.features.emergency.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import mx.cruzroja.enlacevital.core.demo.DemoMode
import mx.cruzroja.enlacevital.core.design.ScreenScaffold
import mx.cruzroja.enlacevital.core.design.Section
import mx.cruzroja.enlacevital.features.emergency.model.EmergencyReport
import mx.cruzroja.enlacevital.features.emergency.model.ReportingFor

@Composable
fun ReportScreen(viewModel: EmergencyReportViewModel, onBack: () -> Unit, onContinue: () -> Unit) {
    val state by viewModel.state.collectAsState()
    val report = state.report
    val listState = rememberLazyListState()

    LaunchedEffect(Unit) {
        if (DemoMode.isActive("vitals")) listState.scrollToItem(VITALS_INDEX)
    }

    ScreenScaffold(
        title = "Reporte",
        onBack = onBack,
        bottomBar = {
            Surface(color = Color.White) {
                Button(
                    onClick = onContinue,
                    colors = ButtonDefaults.buttonColors(containerColor = Color.Black),
                    modifier = Modifier.fillMaxWidth().padding(16.dp).height(50.dp),
                ) { Text("Continuar") }
            }
        },
    ) { padding ->
        LazyColumn(Modifier.padding(padding), state = listState) {
            item {
                Section(title = "¿Para quién?") {
                    Segmented(ReportingFor.entries.map { it.label }, report.reportingFor.label) { label ->
                        viewModel.updateReport { it.copy(reportingFor = ReportingFor.entries.first { r -> r.label == label }) }
                    }
                    report.patientName?.let { Text("Perfil médico de $it cargado", style = MaterialTheme.typography.bodyMedium) }
                }
            }
            item {
                Section(footer = "Describe lo que pasa y llenamos el reporte por ti.") {
                    FilledTonalButton(onClick = viewModel::dictate, enabled = !state.isListening, modifier = Modifier.fillMaxWidth()) {
                        Icon(Icons.Filled.Mic, contentDescription = null)
                        Text(if (state.isListening) " Escuchando…" else " Dictar")
                    }
                }
            }
            item {
                Section(title = "Incidente") {
                    Field("Motivo", report.reason) { v -> viewModel.updateReport { it.copy(reason = v) } }
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text("Lesionados: ${report.injuredCount}", modifier = Modifier.weight(1f))
                        IconButton(onClick = { viewModel.updateReport { it.copy(injuredCount = (it.injuredCount - 1).coerceAtLeast(1)) } }) {
                            Icon(Icons.Filled.Remove, contentDescription = "Menos")
                        }
                        IconButton(onClick = { viewModel.updateReport { it.copy(injuredCount = (it.injuredCount + 1).coerceAtMost(20)) } }) {
                            Icon(Icons.Filled.Add, contentDescription = "Más")
                        }
                    }
                    Field("Lesión principal", report.injury) { v -> viewModel.updateReport { it.copy(injury = v) } }
                    Field("Lugar", report.place) { v -> viewModel.updateReport { it.copy(place = v) } }
                }
            }
            item {
                Section(title = "Ubicación") {
                    Row(verticalAlignment = Alignment.Top) {
                        Icon(Icons.Filled.LocationOn, contentDescription = null)
                        Column(Modifier.padding(start = 8.dp)) {
                            Text(state.location.address)
                            Text("Automática · ±${state.location.accuracyMeters} m", style = MaterialTheme.typography.bodySmall, color = Color.Gray)
                        }
                    }
                    Field("Referencia", report.reference) { v -> viewModel.updateReport { it.copy(reference = v) } }
                }
            }
            item {
                Section(title = "Estado del paciente") {
                    VitalSign("Estado mental", EmergencyReport.MENTAL_STATES, report.mentalState) { v -> viewModel.updateReport { it.copy(mentalState = v) } }
                    VitalSign("Respiración", EmergencyReport.BREATHING_OPTIONS, report.breathing) { v -> viewModel.updateReport { it.copy(breathing = v) } }
                    VitalSign("Color de piel", EmergencyReport.SKIN_COLORS, report.skin) { v -> viewModel.updateReport { it.copy(skin = v) } }
                }
            }
        }
    }
}

private const val VITALS_INDEX = 4

@Composable
private fun Field(label: String, value: String, onChange: (String) -> Unit) {
    OutlinedTextField(value = value, onValueChange = onChange, label = { Text(label) }, singleLine = true, modifier = Modifier.fillMaxWidth())
}

@Composable
private fun VitalSign(title: String, options: List<String>, selected: String, onSelect: (String) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.padding(vertical = 4.dp)) {
        Text(title, style = MaterialTheme.typography.bodyMedium, color = Color.Gray)
        Segmented(options, selected, onSelect)
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun Segmented(options: List<String>, selected: String, onSelect: (String) -> Unit) {
    SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth()) {
        options.forEachIndexed { i, option ->
            SegmentedButton(
                selected = option == selected,
                onClick = { onSelect(option) },
                shape = SegmentedButtonDefaults.itemShape(i, options.size),
                icon = {},
                label = { Text(option, fontSize = 12.sp, maxLines = 1, overflow = TextOverflow.Ellipsis) },
            )
        }
    }
}
