package mx.cruzroja.enlacevital.features.firstaid.ui

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.VolumeOff
import androidx.compose.material.icons.automirrored.filled.VolumeUp
import androidx.compose.material.icons.filled.Replay
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import mx.cruzroja.enlacevital.core.design.AmbulanceStatusBar
import mx.cruzroja.enlacevital.core.design.BrandRed
import mx.cruzroja.enlacevital.core.design.ScreenScaffold
import mx.cruzroja.enlacevital.core.design.SoftGray
import mx.cruzroja.enlacevital.core.design.brandStyle
import mx.cruzroja.enlacevital.core.design.symbol

@Composable
fun GuideScreen(viewModel: GuideViewModel, onBack: () -> Unit) {
    val state by viewModel.state.collectAsState()
    val ambulance by viewModel.ambulance.state.collectAsState()
    val isMuted by viewModel.speech.isMuted.collectAsState()
    val step = state.step
    val haptics = LocalHapticFeedback.current
    val pulse by animateFloatAsState(if (step.rate != null && state.beat) 1.15f else 1f, tween(100), label = "beat")

    LaunchedEffect(state.beat) {
        if (step.rate != null) haptics.performHapticFeedback(HapticFeedbackType.LongPress)
    }
    DisposableEffect(Unit) { onDispose { viewModel.stop() } }

    ScreenScaffold(
        title = state.guide.title,
        onBack = onBack,
        actions = {
            IconButton(onClick = viewModel::toggleMute) {
                Icon(if (isMuted) Icons.AutoMirrored.Filled.VolumeOff else Icons.AutoMirrored.Filled.VolumeUp, contentDescription = "Silenciar")
            }
        },
    ) { padding ->
        Column(Modifier.padding(padding).fillMaxSize().padding(16.dp), verticalArrangement = Arrangement.spacedBy(20.dp)) {
            AmbulanceStatusBar(ambulance.status, viewModel.ambulance.unit, ambulance.timeLeft, ambulance.progress, ambulance.hasArrived)

            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("Paso ${state.stepIndex + 1} de ${state.guide.steps.size}", color = Color.Gray, fontWeight = FontWeight.Medium)
                LinearProgressIndicator(
                    progress = { (state.stepIndex + 1f) / state.guide.steps.size },
                    color = BrandRed,
                    trackColor = Color.LightGray,
                    modifier = Modifier.fillMaxWidth(),
                )
            }

            Spacer(Modifier.weight(1f))

            Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                Box(Modifier.size(190.dp).clip(CircleShape).background(SoftGray), contentAlignment = Alignment.Center) {
                    val total = step.seconds
                    val left = state.secondsLeft
                    if (total != null && left != null) {
                        Canvas(Modifier.fillMaxSize().padding(8.dp)) {
                            drawArc(
                                color = BrandRed,
                                startAngle = -90f,
                                sweepAngle = 360f * left / total,
                                useCenter = false,
                                style = Stroke(width = 8.dp.toPx(), cap = StrokeCap.Round),
                            )
                        }
                    }
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Icon(symbol(step.icon), contentDescription = null, tint = BrandRed, modifier = Modifier.size(52.dp).scale(pulse))
                        left?.let { Text("%d:%02d".format(it / 60, it % 60), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.SemiBold) }
                        step.rate?.let { Text("$it por minuto", style = MaterialTheme.typography.labelMedium, color = Color.Gray) }
                    }
                }
            }

            Text(step.title, style = brandStyle(28))
            Text(step.instruction, style = MaterialTheme.typography.titleMedium, color = Color.Gray)

            Spacer(Modifier.weight(1f))

            Row(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.CenterVertically) {
                OutlinedButton(onClick = viewModel::previous, enabled = !state.isFirstStep, modifier = Modifier.weight(1f).height(44.dp)) {
                    Text("Anterior", color = Color.Black)
                }
                OutlinedButton(onClick = viewModel::repeatInstruction, modifier = Modifier.height(44.dp)) {
                    Icon(Icons.Filled.Replay, contentDescription = "Repetir", tint = Color.Black)
                }
                Button(
                    onClick = viewModel::next,
                    enabled = !state.isLastStep,
                    colors = ButtonDefaults.buttonColors(containerColor = Color.Black),
                    modifier = Modifier.weight(1f).height(44.dp),
                ) { Text("Siguiente") }
            }
            Text("Basado en protocolos de Cruz Roja", style = MaterialTheme.typography.bodySmall, color = Color.Gray, modifier = Modifier.align(Alignment.CenterHorizontally))
        }
    }
}
