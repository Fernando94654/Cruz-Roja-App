package mx.cruzroja.enlacevital.features.medicalprofile.ui

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.FilterQuality
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import mx.cruzroja.enlacevital.core.design.brandStyle
import mx.cruzroja.enlacevital.core.qr.QrCodeGenerator

// Full-screen QR so the paramedic can scan it easily
@Composable
fun QrCodeDialog(name: String, text: String, onDismiss: () -> Unit) {
    val image = remember(text) { QrCodeGenerator.image(text) }

    Dialog(onDismissRequest = onDismiss, properties = DialogProperties(usePlatformDefaultWidth = false)) {
        Column(
            Modifier.fillMaxSize().background(Color.White).systemBarsPadding().padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(20.dp),
        ) {
            Spacer(Modifier.weight(1f))
            Text("Perfil médico", style = brandStyle(28))
            Text(name, style = MaterialTheme.typography.titleMedium, color = Color.Gray)
            if (image != null) {
                Image(image, contentDescription = "Código QR del perfil médico", filterQuality = FilterQuality.None, modifier = Modifier.size(300.dp))
            } else {
                Text("El perfil tiene demasiada información para un solo código. Quita algunos elementos.", color = Color.Gray, textAlign = TextAlign.Center)
            }
            Text("Muestra este código al paramédico.\nSe lee con la cámara, sin internet.", color = Color.Gray, textAlign = TextAlign.Center)
            Spacer(Modifier.weight(1f))
            Button(
                onClick = onDismiss,
                colors = ButtonDefaults.buttonColors(containerColor = Color.Black),
                modifier = Modifier.fillMaxWidth().height(50.dp),
            ) { Text("Cerrar") }
        }
    }
}
