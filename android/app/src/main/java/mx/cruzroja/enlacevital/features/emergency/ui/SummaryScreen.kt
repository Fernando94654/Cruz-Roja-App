package mx.cruzroja.enlacevital.features.emergency.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Healing
import androidx.compose.material.icons.filled.RadioButtonUnchecked
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import mx.cruzroja.enlacevital.core.design.BrandRed
import mx.cruzroja.enlacevital.core.design.LabeledRow
import mx.cruzroja.enlacevital.core.design.ScreenScaffold
import mx.cruzroja.enlacevital.core.design.Section

@Composable
fun SummaryScreen(viewModel: EmergencyReportViewModel, onBack: () -> Unit, onFirstAid: () -> Unit) {
    val state by viewModel.state.collectAsState()
    val report = state.report

    ScreenScaffold(title = if (state.isSent) "Reporte enviado" else "Revisar reporte", onBack = onBack) { padding ->
        Column(Modifier.padding(padding).verticalScroll(rememberScrollState())) {
            if (state.isSent) {
                Section(title = "Seguimiento") {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Filled.CheckCircle, contentDescription = null)
                        Text(" Ubicación compartida por SMS y enlace")
                    }
                    TrackingStep("Recibido", "17:42", done = true)
                    TrackingStep("Unidad asignada", "Ambulancia 214 · 17:43", done = true)
                    TrackingStep("En camino", "≈ 8 min", done = false)
                }
                Section {
                    Row(Modifier.fillMaxWidth().clickable(onClick = onFirstAid).padding(vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Filled.Healing, contentDescription = null, tint = BrandRed)
                        Text(" Ver instrucciones de primeros auxilios", color = BrandRed)
                    }
                }
            }

            Section(title = "Resumen del reporte", footer = "Generado a partir de lo que dictaste. Revisa que esté correcto.") {
                LabeledRow("Para", state.patientDescription)
                LabeledRow("Motivo", report.reason)
                LabeledRow("Lesionados", "${report.injuredCount}")
                LabeledRow("Lesión principal", report.injury)
                LabeledRow("Lugar", report.place)
                LabeledRow("Estado mental", report.mentalState)
                LabeledRow("Respiración", report.breathing)
                LabeledRow("Color de piel", report.skin)
                LabeledRow("Referencia", report.reference)
                LabeledRow("Ubicación", "±${state.location.accuracyMeters} m")
            }

            if (!state.isSent) {
                Button(
                    onClick = viewModel::send,
                    enabled = !state.isSending,
                    colors = ButtonDefaults.buttonColors(containerColor = BrandRed),
                    modifier = Modifier.fillMaxWidth().padding(16.dp).height(50.dp),
                ) { Text("Enviar a Cruz Roja", fontWeight = FontWeight.SemiBold) }
            }
        }
    }
}

@Composable
private fun TrackingStep(title: String, detail: String, done: Boolean) {
    Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(vertical = 2.dp)) {
        Icon(
            if (done) Icons.Filled.CheckCircle else Icons.Filled.RadioButtonUnchecked,
            contentDescription = null,
            tint = if (done) Color.Black else BrandRed,
        )
        Column(Modifier.padding(start = 12.dp)) {
            Text(title, fontWeight = if (done) FontWeight.Normal else FontWeight.SemiBold)
            Text(detail, style = MaterialTheme.typography.bodySmall, color = Color.Gray)
        }
    }
}
