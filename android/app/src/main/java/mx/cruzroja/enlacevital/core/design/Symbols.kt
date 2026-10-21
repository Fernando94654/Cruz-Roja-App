package mx.cruzroja.enlacevital.core.design

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Accessibility
import androidx.compose.material.icons.filled.Air
import androidx.compose.material.icons.filled.AirlineSeatFlat
import androidx.compose.material.icons.filled.ArrowCircleUp
import androidx.compose.material.icons.filled.BackHand
import androidx.compose.material.icons.filled.Bed
import androidx.compose.material.icons.filled.Checkroom
import androidx.compose.material.icons.filled.CropFree
import androidx.compose.material.icons.filled.DoNotDisturbOn
import androidx.compose.material.icons.filled.ElectricBolt
import androidx.compose.material.icons.filled.Healing
import androidx.compose.material.icons.filled.HeartBroken
import androidx.compose.material.icons.filled.Layers
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material.icons.filled.MedicalServices
import androidx.compose.material.icons.filled.MonitorHeart
import androidx.compose.material.icons.filled.PanTool
import androidx.compose.material.icons.filled.QuestionAnswer
import androidx.compose.material.icons.filled.RadioButtonUnchecked
import androidx.compose.material.icons.filled.Repeat
import androidx.compose.material.icons.filled.ReportProblem
import androidx.compose.material.icons.filled.SignLanguage
import androidx.compose.material.icons.filled.Thermostat
import androidx.compose.material.icons.filled.Timer
import androidx.compose.material.icons.filled.TouchApp
import androidx.compose.material.icons.filled.Visibility
import androidx.compose.material.icons.filled.Water
import androidx.compose.material.icons.filled.WaterDrop
import androidx.compose.ui.graphics.vector.ImageVector

// Maps the SF Symbol names shared with iOS content to Material icons
fun symbol(name: String): ImageVector = when (name) {
    "heart.slash.fill" -> Icons.Filled.HeartBroken
    "lungs.fill" -> Icons.Filled.Air
    "drop.fill" -> Icons.Filled.WaterDrop
    "drop.triangle.fill" -> Icons.Filled.Water
    "flame.fill" -> Icons.Filled.LocalFireDepartment
    "bolt.heart.fill" -> Icons.Filled.ElectricBolt
    "figure.fall" -> Icons.Filled.AirlineSeatFlat
    "figure.stand" -> Icons.Filled.Accessibility
    "eye.fill" -> Icons.Filled.Visibility
    "hand.tap.fill", "hand.point.down.fill" -> Icons.Filled.TouchApp
    "hands.clap.fill" -> Icons.Filled.SignLanguage
    "hand.raised.fill" -> Icons.Filled.PanTool
    "hand.raised.square.fill" -> Icons.Filled.BackHand
    "waveform.path.ecg", "arrow.clockwise.heart.fill" -> Icons.Filled.MonitorHeart
    "arrow.up.circle.fill" -> Icons.Filled.ArrowCircleUp
    "bandage.fill" -> Icons.Filled.Healing
    "bed.double.fill" -> Icons.Filled.Bed
    "circle.dashed" -> Icons.Filled.RadioButtonUnchecked
    "square.dashed" -> Icons.Filled.CropFree
    "square.stack.fill" -> Icons.Filled.Layers
    "person.crop.circle.badge.exclamationmark" -> Icons.Filled.ReportProblem
    "questionmark.bubble.fill" -> Icons.Filled.QuestionAnswer
    "repeat" -> Icons.Filled.Repeat
    "stopwatch.fill" -> Icons.Filled.Timer
    "thermometer.medium" -> Icons.Filled.Thermostat
    "tshirt.fill" -> Icons.Filled.Checkroom
    "xmark.octagon.fill" -> Icons.Filled.DoNotDisturbOn
    else -> Icons.Filled.MedicalServices
}
