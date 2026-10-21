package mx.cruzroja.enlacevital.features.medicalprofile.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AddCircle
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.MenuAnchorType
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.SelectableDates
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberDatePickerState
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
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import mx.cruzroja.enlacevital.core.design.BrandRed
import mx.cruzroja.enlacevital.core.design.Section
import mx.cruzroja.enlacevital.features.medicalprofile.model.BloodType
import mx.cruzroja.enlacevital.features.medicalprofile.model.EmergencyContact
import mx.cruzroja.enlacevital.features.medicalprofile.model.MedicalProfile
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneOffset

// Edits a draft copy; nothing is stored until "Guardar"
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun EditMedicalProfileDialog(profile: MedicalProfile, isNew: Boolean, viewModel: MedicalProfileViewModel, onDismiss: () -> Unit) {
    val state by viewModel.state.collectAsState()
    var draft by remember { mutableStateOf(profile) }
    var hasDateOfBirth by remember { mutableStateOf(profile.dateOfBirth != null) }
    var picksDate by remember { mutableStateOf(false) }
    var bloodMenu by remember { mutableStateOf(false) }

    fun save() {
        val dateOfBirth = if (hasDateOfBirth) draft.dateOfBirth ?: SUGGESTED_DATE else null
        viewModel.save(draft.copy(dateOfBirth = dateOfBirth), onSaved = onDismiss)
    }

    Dialog(onDismissRequest = { if (!state.isSaving) onDismiss() }, properties = DialogProperties(usePlatformDefaultWidth = false)) {
        Column(Modifier.fillMaxSize().background(MaterialTheme.colorScheme.surfaceContainer).systemBarsPadding().imePadding()) {
            Row(Modifier.fillMaxWidth().background(Color.White).padding(8.dp), verticalAlignment = Alignment.CenterVertically) {
                TextButton(onClick = onDismiss) { Text("Cancelar") }
                Text(if (isNew) "Nuevo perfil" else "Editar perfil", fontWeight = FontWeight.SemiBold, textAlign = TextAlign.Center, modifier = Modifier.weight(1f))
                if (state.isSaving) CircularProgressIndicator(Modifier.padding(12.dp), color = BrandRed, strokeWidth = 2.dp)
                else TextButton(onClick = ::save, enabled = draft.fullName.isNotBlank()) { Text("Guardar", fontWeight = FontWeight.SemiBold) }
            }
            Column(Modifier.verticalScroll(rememberScrollState())) {
                Section(title = "Datos personales") {
                    OutlinedTextField(draft.fullName, { draft = draft.copy(fullName = it) }, label = { Text("Nombre completo") }, singleLine = true, modifier = Modifier.fillMaxWidth())
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text("Fecha de nacimiento", modifier = Modifier.weight(1f))
                        Switch(hasDateOfBirth, { hasDateOfBirth = it }, colors = SwitchDefaults.colors(checkedTrackColor = BrandRed))
                    }
                    if (hasDateOfBirth) {
                        TextButton(onClick = { picksDate = true }) { Text((draft.dateOfBirth ?: SUGGESTED_DATE).toString()) }
                    }
                }
                Section(title = "Tipo de sangre") {
                    ExposedDropdownMenuBox(expanded = bloodMenu, onExpandedChange = { bloodMenu = it }) {
                        OutlinedTextField(
                            value = draft.bloodType.label,
                            onValueChange = {},
                            readOnly = true,
                            trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(bloodMenu) },
                            modifier = Modifier.fillMaxWidth().menuAnchor(MenuAnchorType.PrimaryNotEditable),
                        )
                        ExposedDropdownMenu(expanded = bloodMenu, onDismissRequest = { bloodMenu = false }) {
                            BloodType.entries.forEach { type ->
                                DropdownMenuItem(text = { Text(type.label) }, onClick = { draft = draft.copy(bloodType = type); bloodMenu = false })
                            }
                        }
                    }
                }
                EditableListSection("Alergias", "Ej. Penicilina", draft.allergies) { draft = draft.copy(allergies = it) }
                EditableListSection("Padecimientos", "Ej. Asma", draft.conditions) { draft = draft.copy(conditions = it) }
                EditableListSection("Medicamentos", "Ej. Salbutamol", draft.medications) { draft = draft.copy(medications = it) }
                ContactsSection(draft.contacts) { draft = draft.copy(contacts = it) }
            }
        }
    }

    if (picksDate) {
        val pickerState = rememberDatePickerState(
            initialSelectedDateMillis = (draft.dateOfBirth ?: SUGGESTED_DATE).atStartOfDay().toInstant(ZoneOffset.UTC).toEpochMilli(),
            selectableDates = object : SelectableDates {
                override fun isSelectableDate(utcTimeMillis: Long) = utcTimeMillis <= System.currentTimeMillis()
            },
        )
        DatePickerDialog(
            onDismissRequest = { picksDate = false },
            confirmButton = {
                TextButton(onClick = {
                    pickerState.selectedDateMillis?.let {
                        draft = draft.copy(dateOfBirth = Instant.ofEpochMilli(it).atZone(ZoneOffset.UTC).toLocalDate())
                    }
                    picksDate = false
                }) { Text("Aceptar") }
            },
            dismissButton = { TextButton(onClick = { picksDate = false }) { Text("Cancelar") } },
        ) { DatePicker(pickerState) }
    }

    state.errorMessage?.let { message ->
        AlertDialog(
            onDismissRequest = viewModel::dismissError,
            title = { Text("No se pudo guardar") },
            text = { Text(message) },
            confirmButton = { TextButton(onClick = viewModel::dismissError) { Text("Aceptar") } },
        )
    }
}

private val SUGGESTED_DATE: LocalDate get() = LocalDate.now().minusYears(30)

// List of texts that can be added and removed (allergies, conditions, medications)
@Composable
private fun EditableListSection(title: String, placeholder: String, items: List<String>, onChange: (List<String>) -> Unit) {
    var newItem by remember { mutableStateOf("") }

    fun add() {
        val text = newItem.trim()
        newItem = ""
        if (text.isNotEmpty() && items.none { it.equals(text, ignoreCase = true) }) onChange(items + text)
    }

    Section(title = title, footer = if (items.isEmpty()) "Si no tienes, déjalo vacío." else null) {
        items.forEach { item ->
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(item, modifier = Modifier.weight(1f))
                IconButton(onClick = { onChange(items - item) }) { Icon(Icons.Filled.Delete, contentDescription = "Eliminar", tint = Color.Gray) }
            }
            HorizontalDivider()
        }
        Row(verticalAlignment = Alignment.CenterVertically) {
            OutlinedTextField(newItem, { newItem = it }, placeholder = { Text(placeholder) }, singleLine = true, modifier = Modifier.weight(1f))
            IconButton(onClick = ::add, enabled = newItem.isNotBlank()) { Icon(Icons.Filled.AddCircle, contentDescription = "Agregar", tint = BrandRed) }
        }
    }
}

@Composable
private fun ContactsSection(contacts: List<EmergencyContact>, onChange: (List<EmergencyContact>) -> Unit) {
    fun update(index: Int, contact: EmergencyContact) = onChange(contacts.toMutableList().also { it[index] = contact })

    Section(title = "Contactos de emergencia", footer = "Hasta ${MedicalProfile.MAX_CONTACTS} contactos.") {
        contacts.forEachIndexed { i, contact ->
            Column {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("Contacto ${i + 1}", fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
                    IconButton(onClick = { onChange(contacts.filterIndexed { j, _ -> j != i }) }) {
                        Icon(Icons.Filled.Delete, contentDescription = "Eliminar", tint = Color.Gray)
                    }
                }
                OutlinedTextField(contact.name, { update(i, contact.copy(name = it)) }, label = { Text("Nombre") }, singleLine = true, modifier = Modifier.fillMaxWidth())
                OutlinedTextField(contact.relationship, { update(i, contact.copy(relationship = it)) }, label = { Text("Parentesco (ej. Hija)") }, singleLine = true, modifier = Modifier.fillMaxWidth())
                OutlinedTextField(
                    contact.phone,
                    { update(i, contact.copy(phone = it)) },
                    label = { Text("Teléfono a 10 dígitos") },
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Phone),
                    isError = contact.phone.isNotEmpty() && !MedicalProfile.isValidPhone(contact.phone),
                    supportingText = {
                        if (contact.phone.isNotEmpty() && !MedicalProfile.isValidPhone(contact.phone)) Text("El teléfono debe tener 10 dígitos.")
                    },
                    modifier = Modifier.fillMaxWidth(),
                )
            }
            HorizontalDivider()
        }
        if (contacts.size < MedicalProfile.MAX_CONTACTS) {
            TextButton(onClick = { onChange(contacts + EmergencyContact(name = "", relationship = "", phone = "")) }) {
                Icon(Icons.Filled.AddCircle, contentDescription = null, tint = BrandRed)
                Text(" Agregar contacto")
            }
        }
    }
}
