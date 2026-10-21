package mx.cruzroja.enlacevital.features.medicalprofile.ui

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.CloudOff
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.WifiOff
import androidx.compose.material.icons.filled.MonitorHeart
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.FilterQuality
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import mx.cruzroja.enlacevital.app.LocalAppContainer
import mx.cruzroja.enlacevital.app.containerViewModel
import mx.cruzroja.enlacevital.core.demo.DemoMode
import mx.cruzroja.enlacevital.core.design.BrandRed
import mx.cruzroja.enlacevital.core.design.LabeledRow
import mx.cruzroja.enlacevital.core.design.ScreenScaffold
import mx.cruzroja.enlacevital.core.design.Section
import mx.cruzroja.enlacevital.core.qr.QrCodeGenerator
import mx.cruzroja.enlacevital.features.auth.data.Session
import mx.cruzroja.enlacevital.features.auth.ui.LoginDialog
import mx.cruzroja.enlacevital.features.medicalprofile.model.MedicalProfile

@Composable
fun MedicalProfileTab() {
    val container = LocalAppContainer.current
    val viewModel = containerViewModel { makeMedicalProfileViewModel() }
    val state by viewModel.state.collectAsState()
    val session by container.session.session.collectAsState()
    var showsLogin by remember { mutableStateOf(DemoMode.isActive("login")) }
    var isEditing by remember { mutableStateOf(false) }
    var showsQr by remember { mutableStateOf(false) }

    ScreenScaffold(
        title = "Perfil médico",
        actions = {
            if (session.isSignedIn) TextButton(onClick = container.session::signOut) { Text("Cerrar sesión") }
            if (state.profile != null) TextButton(onClick = { isEditing = true }) { Text("Editar") }
        },
    ) { padding ->
        Column(Modifier.padding(padding).verticalScroll(rememberScrollState())) {
            Section { Account(session, onSignIn = { showsLogin = true }) }
            when (val load = state.loadState) {
                LoadState.Loading -> Section {
                    Box(Modifier.fillMaxWidth().padding(16.dp), contentAlignment = Alignment.Center) { CircularProgressIndicator(color = BrandRed) }
                }
                LoadState.Empty -> Section {
                    Column(Modifier.fillMaxWidth().padding(vertical = 16.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        Icon(Icons.Filled.MonitorHeart, contentDescription = null, tint = BrandRed, modifier = Modifier.size(40.dp))
                        Text("Completa tu perfil médico", fontWeight = FontWeight.SemiBold)
                        Text("Los paramédicos sabrán tu tipo de sangre, alergias y medicamentos antes de llegar.", color = Color.Gray, textAlign = TextAlign.Center)
                        Button(onClick = { isEditing = true }, colors = ButtonDefaults.buttonColors(containerColor = BrandRed)) { Text("Completar perfil") }
                    }
                }
                is LoadState.Failed -> Section {
                    Column(Modifier.fillMaxWidth().padding(vertical = 16.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        Icon(Icons.Filled.CloudOff, contentDescription = null, tint = Color.Gray, modifier = Modifier.size(36.dp))
                        Text(load.message, textAlign = TextAlign.Center)
                        OutlinedButton(onClick = viewModel::load) { Text("Reintentar", color = Color.Black) }
                    }
                }
                LoadState.Ready -> state.profile?.let { profile ->
                    ProfileSections(profile, state, viewModel, onShowQr = { showsQr = true })
                }
            }
        }
    }

    if (showsLogin) LoginDialog(containerViewModel(key = "auth") { makeAuthViewModel() }, onDismiss = { showsLogin = false })
    if (isEditing) EditMedicalProfileDialog(state.profile ?: MedicalProfile(), isNew = state.profile == null, viewModel, onDismiss = { isEditing = false })
    if (showsQr) state.profile?.let { QrCodeDialog(it.fullName, it.qrText(state.qrIncludesContacts), onDismiss = { showsQr = false }) }
}

@Composable
private fun ProfileSections(profile: MedicalProfile, state: MedicalProfileUiState, viewModel: MedicalProfileViewModel, onShowQr: () -> Unit) {
    val context = LocalContext.current

    if (state.isShowingCachedCopy) {
        Section {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Filled.WifiOff, contentDescription = null, tint = Color.Gray, modifier = Modifier.size(18.dp))
                Text("  Sin conexión. Se muestra la última copia guardada.", style = MaterialTheme.typography.bodySmall, color = Color.Gray)
            }
        }
    }
    Section(title = "Datos personales") {
        LabeledRow("Nombre", profile.fullName)
        profile.age()?.let { LabeledRow("Edad", "$it años") }
    }
    Section(title = "Datos médicos") {
        LabeledRow("Tipo de sangre", profile.bloodType.label)
        LabeledRow("Alergias", MedicalProfile.text(profile.allergies))
        LabeledRow("Padecimientos", MedicalProfile.text(profile.conditions))
        LabeledRow("Medicamentos", MedicalProfile.text(profile.medications))
    }
    Section(title = "Contactos de emergencia") {
        if (profile.contacts.isEmpty()) Text("Sin contactos registrados", color = Color.Gray)
        profile.contacts.forEachIndexed { i, contact ->
            if (i > 0) HorizontalDivider()
            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(vertical = 4.dp)) {
                Column(Modifier.weight(1f)) {
                    Text(contact.name)
                    Text(contact.relationship, style = MaterialTheme.typography.bodySmall, color = Color.Gray)
                }
                Text(
                    contact.formattedPhone,
                    color = BrandRed,
                    modifier = Modifier.clickable {
                        context.startActivity(Intent(Intent.ACTION_DIAL, Uri.parse("tel:${MedicalProfile.digitsOnly(contact.phone)}")))
                    },
                )
            }
        }
    }
    Section(footer = "El código funciona sin internet. Cualquier persona que lo escanee puede leerlo.") {
        Row(Modifier.fillMaxWidth().clickable(onClick = onShowQr).padding(vertical = 4.dp), verticalAlignment = Alignment.CenterVertically) {
            QrCodeGenerator.image(profile.qrText(state.qrIncludesContacts))?.let {
                Image(it, contentDescription = "Código QR", filterQuality = FilterQuality.None, modifier = Modifier.size(96.dp))
            }
            Text(
                "El paramédico escanea el código y ve tu perfil. Toca para agrandarlo.",
                color = Color.Gray,
                modifier = Modifier.padding(start = 16.dp),
            )
        }
        HorizontalDivider()
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("Incluir contactos en el código", modifier = Modifier.weight(1f))
            Switch(
                checked = state.qrIncludesContacts,
                onCheckedChange = viewModel::setQrIncludesContacts,
                colors = SwitchDefaults.colors(checkedTrackColor = BrandRed),
            )
        }
    }
}

@Composable
private fun Account(session: Session, onSignIn: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().then(if (session.isSignedIn) Modifier else Modifier.clickable(onClick = onSignIn)).padding(vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            Modifier.size(44.dp).clip(CircleShape).background(if (session.isSignedIn) BrandRed else Color.Gray),
            contentAlignment = Alignment.Center,
        ) { Icon(Icons.Filled.Person, contentDescription = null, tint = Color.White) }
        Column(Modifier.weight(1f).padding(start = 14.dp)) {
            if (session.isSignedIn) {
                Text("Mi cuenta", fontWeight = FontWeight.SemiBold)
                Text(session.email.ifEmpty { "usuario@correo.com" }, color = Color.Gray)
            } else {
                Text("Inicia sesión o regístrate", fontWeight = FontWeight.SemiBold)
                Text("Respalda tu perfil y compártelo con tu familia", color = Color.Gray)
            }
        }
        if (!session.isSignedIn) Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, contentDescription = null, tint = Color.LightGray)
    }
}
