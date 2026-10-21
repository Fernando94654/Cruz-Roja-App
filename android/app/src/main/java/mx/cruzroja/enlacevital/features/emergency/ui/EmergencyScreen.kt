package mx.cruzroja.enlacevital.features.emergency.ui

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.PanTool
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import kotlinx.coroutines.delay
import kotlinx.coroutines.withTimeoutOrNull
import mx.cruzroja.enlacevital.app.containerViewModel
import mx.cruzroja.enlacevital.core.demo.DemoMode
import mx.cruzroja.enlacevital.core.design.BrandRed
import mx.cruzroja.enlacevital.core.design.ScreenScaffold
import mx.cruzroja.enlacevital.core.design.SoftGray
import mx.cruzroja.enlacevital.core.design.brandStyle
import mx.cruzroja.enlacevital.core.map.MapMarker
import mx.cruzroja.enlacevital.core.map.OsmMap
import mx.cruzroja.enlacevital.features.emergency.model.EmergencyReport
import mx.cruzroja.enlacevital.features.firstaid.model.FirstAidGuide

private fun demoRoutes(): List<String> = when (DemoMode.current) {
    "report", "vitals" -> listOf(EmergencyRoutes.REPORT)
    "summary", "sent" -> listOf(EmergencyRoutes.REPORT, EmergencyRoutes.SUMMARY)
    "firstaid" -> listOf(EmergencyRoutes.REPORT, EmergencyRoutes.SUMMARY, EmergencyRoutes.FIRST_AID)
    "guide" -> listOf(EmergencyRoutes.REPORT, EmergencyRoutes.SUMMARY, EmergencyRoutes.FIRST_AID, EmergencyRoutes.guide(FirstAidGuide.CATALOG[0].id))
    else -> emptyList()
}

@Composable
fun EmergencyTab() {
    val navController = rememberNavController()
    val reportViewModel = containerViewModel(key = "emergency-report") {
        val prefilled = DemoMode.isActive("report", "vitals", "summary", "sent", "firstaid", "guide")
        makeEmergencyReportViewModel(
            report = if (prefilled) EmergencyReport().withDictationSample() else EmergencyReport(),
            isSent = DemoMode.isActive("sent"),
        )
    }
    var appliedDemo by rememberSaveable { mutableStateOf(false) }

    NavHost(navController, startDestination = EmergencyRoutes.HOME) {
        composable(EmergencyRoutes.HOME) {
            EmergencyHomeScreen(reportViewModel, onReport = { navController.navigate(EmergencyRoutes.REPORT) })
        }
        emergencyDestinations(navController, reportViewModel)
    }

    LaunchedEffect(Unit) {
        if (!appliedDemo) {
            appliedDemo = true
            demoRoutes().forEach { navController.navigate(it) }
        }
    }
}

@Composable
private fun EmergencyHomeScreen(viewModel: EmergencyReportViewModel, onReport: () -> Unit) {
    val state by viewModel.state.collectAsState()
    val location = state.location
    var isPressing by remember { mutableStateOf(false) }
    var showsConfirmation by remember { mutableStateOf(DemoMode.isActive("confirm")) }
    var showsCountdown by remember { mutableStateOf(DemoMode.isActive("countdown")) }
    val haptics = LocalHapticFeedback.current
    // Fills left to right while held; must be held 3 seconds to avoid accidental reports
    val fill by animateFloatAsState(
        targetValue = if (isPressing) 1f else 0f,
        animationSpec = tween(if (isPressing) 3000 else 200, easing = LinearEasing),
        label = "press",
    )

    ScreenScaffold(title = "Emergencia") { padding ->
        Column(
            Modifier.padding(padding).verticalScroll(rememberScrollState()).padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Row(
                Modifier.clip(CircleShape).background(SoftGray).padding(horizontal = 12.dp, vertical = 6.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(Icons.Filled.LocationOn, contentDescription = null, modifier = Modifier.size(16.dp))
                Text(" Ubicación exacta, ±${location.accuracyMeters} m", style = MaterialTheme.typography.labelLarge)
            }
            OsmMap(
                center = location.coordinate,
                zoom = 17.0,
                markers = listOf(MapMarker("Tú", location.coordinate, Color.Black)),
                modifier = Modifier.fillMaxWidth().height(170.dp).clip(RoundedCornerShape(14.dp)),
            )
            Text(location.address, style = MaterialTheme.typography.bodySmall, color = Color.Gray)

            Spacer(Modifier.height(16.dp))

            Box(
                Modifier
                    .fillMaxWidth()
                    .height(200.dp)
                    .scale(if (isPressing) 0.97f else 1f)
                    .clip(RoundedCornerShape(22.dp))
                    .background(BrandRed)
                    .pointerInput(Unit) {
                        detectTapGestures(onPress = {
                            isPressing = true
                            val released = withTimeoutOrNull(3000) { tryAwaitRelease() }
                            isPressing = false
                            if (released == null) {
                                haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                                showsConfirmation = true
                            }
                        })
                    },
            ) {
                Box(Modifier.fillMaxHeight().fillMaxWidth(fill).background(Color.Black.copy(alpha = 0.25f)))
                Column(Modifier.align(Alignment.Center), horizontalAlignment = Alignment.CenterHorizontally) {
                    Icon(Icons.Filled.Warning, contentDescription = null, tint = Color.White, modifier = Modifier.size(40.dp))
                    Text("Reportar emergencia", style = brandStyle(24), color = Color.White)
                    Text(
                        if (isPressing) "Sigue presionando…" else "Mantén presionado 3 segundos",
                        color = Color.White.copy(alpha = 0.85f),
                    )
                }
            }

            Row(verticalAlignment = Alignment.Top) {
                Icon(Icons.Filled.PanTool, contentDescription = null, tint = Color.Gray, modifier = Modifier.size(16.dp))
                Text(
                    " Antes de enviar te pediremos confirmar y tendrás 5 segundos para cancelar.",
                    style = MaterialTheme.typography.bodySmall,
                    color = Color.Gray,
                )
            }
        }
    }

    if (showsConfirmation) {
        AlertDialog(
            onDismissRequest = { showsConfirmation = false },
            title = { Text("¿Reportar una emergencia?") },
            text = { Text("Se enviará tu ubicación exacta a Cruz Roja.") },
            confirmButton = {
                TextButton(onClick = { showsConfirmation = false; showsCountdown = true }) { Text("Sí, reportar", color = BrandRed) }
            },
            dismissButton = { TextButton(onClick = { showsConfirmation = false }) { Text("Cancelar") } },
        )
    }

    if (showsCountdown) {
        CountdownDialog(
            onCancel = { showsCountdown = false },
            onFinish = { showsCountdown = false; onReport() },
        )
    }
}

@Composable
private fun CountdownDialog(onCancel: () -> Unit, onFinish: () -> Unit) {
    var seconds by remember { mutableIntStateOf(5) }

    LaunchedEffect(Unit) {
        if (DemoMode.isActive("countdown")) { seconds = 3; return@LaunchedEffect } // fixed for the screenshot
        while (seconds > 0) {
            delay(1000)
            seconds -= 1
        }
        onFinish()
    }

    Dialog(onDismissRequest = onCancel, properties = DialogProperties(usePlatformDefaultWidth = false)) {
        Column(
            Modifier.fillMaxSize().background(Color.White).padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(28.dp),
        ) {
            Spacer(Modifier.weight(1f))
            Text("Enviando reporte en", style = MaterialTheme.typography.titleMedium, color = Color.Gray)
            Box(Modifier.size(210.dp).clip(CircleShape).background(BrandRed), contentAlignment = Alignment.Center) {
                Text("$seconds", style = brandStyle(110), color = Color.White)
            }
            Text("Se compartirá tu ubicación con Cruz Roja", color = Color.Gray)
            Spacer(Modifier.weight(1f))
            OutlinedButton(onClick = onCancel, modifier = Modifier.fillMaxWidth().height(54.dp)) {
                Text("Cancelar", color = Color.Black)
            }
            Text("¿Fue un error? Cancela antes de que termine.", style = MaterialTheme.typography.bodySmall, color = Color.Gray)
        }
    }
}
