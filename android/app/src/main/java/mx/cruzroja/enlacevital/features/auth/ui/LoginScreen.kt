package mx.cruzroja.enlacevital.features.auth.ui

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
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.MonitorHeart
import androidx.compose.material.icons.filled.Visibility
import androidx.compose.material.icons.filled.VisibilityOff
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
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
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import mx.cruzroja.enlacevital.core.design.BrandRed
import mx.cruzroja.enlacevital.core.design.SoftGray
import mx.cruzroja.enlacevital.core.design.brandStyle

@Composable
fun LoginDialog(viewModel: AuthViewModel, onDismiss: () -> Unit) {
    val state by viewModel.state.collectAsState()
    var showsPassword by remember { mutableStateOf(false) }
    val signIn = { viewModel.signIn(onSignedIn = onDismiss) }

    Dialog(onDismissRequest = onDismiss, properties = DialogProperties(usePlatformDefaultWidth = false)) {
        Box(Modifier.fillMaxSize().background(Color.White).systemBarsPadding()) {
            Column(
                Modifier.verticalScroll(rememberScrollState()).padding(horizontal = 24.dp),
                verticalArrangement = Arrangement.spacedBy(28.dp),
            ) {
                Column(Modifier.padding(top = 40.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                    Box(Modifier.size(64.dp).clip(RoundedCornerShape(16.dp)).background(BrandRed), contentAlignment = Alignment.Center) {
                        Icon(Icons.Filled.MonitorHeart, contentDescription = null, tint = Color.White, modifier = Modifier.size(34.dp))
                    }
                    Text("Inicia sesión", style = brandStyle(34))
                    Text("Guarda tu perfil médico para que los paramédicos sepan cómo atenderte.", color = Color.Gray)
                }

                Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                    InputField(Icons.Filled.Email, "Correo electrónico", state.email, viewModel::setEmail, KeyboardType.Email)
                    InputField(
                        Icons.Filled.Lock, "Contraseña", state.password, viewModel::setPassword, KeyboardType.Password,
                        visualTransformation = if (showsPassword) VisualTransformation.None else PasswordVisualTransformation(),
                        trailing = {
                            IconButton(onClick = { showsPassword = !showsPassword }) {
                                Icon(if (showsPassword) Icons.Filled.VisibilityOff else Icons.Filled.Visibility, contentDescription = null, tint = Color.Gray)
                            }
                        },
                    )
                    TextButton(onClick = {}, modifier = Modifier.align(Alignment.End)) { Text("¿Olvidaste tu contraseña?") }
                }

                Button(
                    onClick = signIn,
                    enabled = !state.isLoading,
                    shape = RoundedCornerShape(14.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = BrandRed),
                    modifier = Modifier.fillMaxWidth().height(54.dp),
                ) {
                    if (state.isLoading) CircularProgressIndicator(color = Color.White, modifier = Modifier.size(22.dp), strokeWidth = 2.dp)
                    else Text("Iniciar sesión", style = brandStyle(17))
                }

                Row(verticalAlignment = Alignment.CenterVertically) {
                    HorizontalDivider(Modifier.weight(1f))
                    Text("  o  ", color = Color.Gray)
                    HorizontalDivider(Modifier.weight(1f))
                }

                // Placeholder until Sign in with Google is wired
                Button(
                    onClick = signIn,
                    shape = RoundedCornerShape(14.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = Color.Black),
                    modifier = Modifier.fillMaxWidth().height(54.dp),
                ) { Text("Continuar con Google", fontWeight = FontWeight.SemiBold) }

                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically) {
                    Text("¿No tienes cuenta?", color = Color.Gray)
                    TextButton(onClick = {}) { Text("Regístrate", fontWeight = FontWeight.SemiBold) }
                }

                Text(
                    "Cruz Roja Mexicana · Delegación Nuevo León",
                    style = MaterialTheme.typography.labelSmall,
                    color = Color.Gray,
                    modifier = Modifier.align(Alignment.CenterHorizontally).padding(bottom = 24.dp),
                )
            }
            IconButton(
                onClick = onDismiss,
                modifier = Modifier.align(Alignment.TopEnd).padding(16.dp).size(36.dp).clip(CircleShape).background(SoftGray),
            ) { Icon(Icons.Filled.Close, contentDescription = "Cerrar", tint = Color.Gray) }
        }
    }
}

@Composable
private fun InputField(
    icon: ImageVector,
    placeholder: String,
    value: String,
    onChange: (String) -> Unit,
    keyboardType: KeyboardType,
    visualTransformation: VisualTransformation = VisualTransformation.None,
    trailing: @Composable (() -> Unit)? = null,
) {
    TextField(
        value = value,
        onValueChange = onChange,
        placeholder = { Text(placeholder) },
        leadingIcon = { Icon(icon, contentDescription = null, tint = Color.Gray) },
        trailingIcon = trailing,
        singleLine = true,
        visualTransformation = visualTransformation,
        keyboardOptions = KeyboardOptions(keyboardType = keyboardType),
        shape = RoundedCornerShape(14.dp),
        colors = TextFieldDefaults.colors(
            focusedIndicatorColor = Color.Transparent,
            unfocusedIndicatorColor = Color.Transparent,
            focusedContainerColor = SoftGray,
            unfocusedContainerColor = SoftGray,
        ),
        modifier = Modifier.fillMaxWidth(),
    )
    Spacer(Modifier.height(0.dp))
}
