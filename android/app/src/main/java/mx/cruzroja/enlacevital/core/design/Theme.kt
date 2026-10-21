package mx.cruzroja.enlacevital.core.design

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp

// Brand manual: PMS 485 and black
val BrandRed = Color(0xFFEE140A)
val SoftGray = Color(0x1F8E8E93)

// Bold sans-serif, closest to the institutional Helvetica Bold
fun brandStyle(size: Int) = TextStyle(fontFamily = FontFamily.SansSerif, fontWeight = FontWeight.Bold, fontSize = size.sp)

@Composable
fun EnlaceVitalTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = lightColorScheme(
            primary = BrandRed,
            onPrimary = Color.White,
            secondary = Color.Black,
            onSecondary = Color.White,
            // Neutral grays instead of Material's tinted containers, closer to iOS controls
            primaryContainer = Color(0xFFFDE3E1),
            onPrimaryContainer = Color.Black,
            secondaryContainer = Color(0xFFE5E5EA),
            onSecondaryContainer = Color.Black,
            surfaceVariant = Color(0xFFE5E5EA),
            background = Color.White,
            surface = Color.White,
            surfaceContainer = Color(0xFFF2F2F7),
        ),
        content = content,
    )
}
