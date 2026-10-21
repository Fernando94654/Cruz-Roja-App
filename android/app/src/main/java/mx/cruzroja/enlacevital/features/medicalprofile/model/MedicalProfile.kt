package mx.cruzroja.enlacevital.features.medicalprofile.model

import kotlinx.serialization.KSerializer
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.Transient
import kotlinx.serialization.descriptors.PrimitiveKind
import kotlinx.serialization.descriptors.PrimitiveSerialDescriptor
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder
import java.time.LocalDate
import java.time.Period
import java.util.UUID

@Serializable
enum class BloodType(val label: String) {
    @SerialName("A+") A_POSITIVE("A+"),
    @SerialName("A-") A_NEGATIVE("A-"),
    @SerialName("B+") B_POSITIVE("B+"),
    @SerialName("B-") B_NEGATIVE("B-"),
    @SerialName("AB+") AB_POSITIVE("AB+"),
    @SerialName("AB-") AB_NEGATIVE("AB-"),
    @SerialName("O+") O_POSITIVE("O+"),
    @SerialName("O-") O_NEGATIVE("O-"),
    @SerialName("unknown") UNKNOWN("No lo sé"),
}

@Serializable
data class EmergencyContact(
    val name: String,
    val relationship: String,
    val phone: String,
    // Local identity for lists; not sent to the API
    @Transient val id: String = UUID.randomUUID().toString(),
) {
    val formattedPhone: String get() = MedicalProfile.formatPhone(phone)
}

// "1958-03-14"
object LocalDateSerializer : KSerializer<LocalDate> {
    override val descriptor = PrimitiveSerialDescriptor("LocalDate", PrimitiveKind.STRING)
    override fun serialize(encoder: Encoder, value: LocalDate) = encoder.encodeString(value.toString())
    override fun deserialize(decoder: Decoder): LocalDate = LocalDate.parse(decoder.decodeString())
}

// Same shape as GET /users/{id}/medical-profile
@Serializable
data class MedicalProfile(
    @SerialName("user_id") val userId: String? = null,
    @SerialName("full_name") val fullName: String = "",
    @SerialName("date_of_birth") @Serializable(LocalDateSerializer::class) val dateOfBirth: LocalDate? = null,
    @SerialName("blood_type") val bloodType: BloodType = BloodType.UNKNOWN,
    val allergies: List<String> = emptyList(),
    val conditions: List<String> = emptyList(),
    val medications: List<String> = emptyList(),
    val contacts: List<EmergencyContact> = emptyList(),
    @SerialName("updated_at") val updatedAt: String? = null,
) {
    // User-facing messages of what must be fixed; empty when the profile can be saved
    val validationErrors: List<String>
        get() = buildList {
            if (fullName.isBlank()) add("Escribe el nombre de la persona.")
            if (dateOfBirth != null && dateOfBirth.isAfter(LocalDate.now())) add("La fecha de nacimiento no puede ser futura.")
            if (contacts.size > MAX_CONTACTS) add("Puedes registrar hasta $MAX_CONTACTS contactos.")
            contacts.forEachIndexed { i, contact ->
                val label = "Contacto ${i + 1}"
                if (contact.name.isBlank()) add("$label: escribe su nombre.")
                if (contact.relationship.isBlank()) add("$label: escribe el parentesco.")
                if (!isValidPhone(contact.phone)) add("$label: el teléfono debe tener 10 dígitos.")
            }
        }

    val isValid: Boolean get() = validationErrors.isEmpty()

    // Trimmed copy without empty or duplicate items and with digit-only phones
    fun cleaned() = copy(
        fullName = fullName.trim(),
        allergies = cleanList(allergies),
        conditions = cleanList(conditions),
        medications = cleanList(medications),
        contacts = contacts.map { it.copy(name = it.name.trim(), relationship = it.relationship.trim(), phone = digitsOnly(it.phone)) },
    )

    fun age(on: LocalDate = LocalDate.now()): Int? = dateOfBirth?.let { Period.between(it, on).years }

    // Text inside the QR code; any camera reads it offline
    fun qrText(includeContacts: Boolean): String = buildList {
        add("CRUZ ROJA · PERFIL MÉDICO")
        add("Nombre: $fullName")
        age()?.let { add("Edad: $it años") }
        add("Sangre: ${bloodType.label}")
        add("Alergias: ${text(allergies)}")
        add("Padecimientos: ${text(conditions)}")
        add("Medicamentos: ${text(medications)}")
        if (includeContacts) contacts.forEach { add("Contacto: ${it.name} (${it.relationship}) ${it.formattedPhone}") }
    }.joinToString("\n")

    // One-line summary attached to emergency reports
    val reportSummary: String
        get() = listOf(
            "Sangre ${bloodType.label}",
            "Alergias: ${text(allergies)}",
            "Padecimientos: ${text(conditions)}",
            "Medicamentos: ${text(medications)}",
        ).joinToString(" · ")

    companion object {
        const val MAX_CONTACTS = 5

        // "81 1234-5678" → "8112345678"
        fun digitsOnly(text: String) = text.filter { it in '0'..'9' }

        // Mexican phone numbers have 10 digits
        fun isValidPhone(text: String) = digitsOnly(text).length == 10

        // "8112345678" → "81 1234 5678"; anything else is returned unchanged
        fun formatPhone(text: String): String {
            val d = digitsOnly(text)
            return if (d.length == 10) "${d.substring(0, 2)} ${d.substring(2, 6)} ${d.substring(6)}" else text
        }

        fun cleanList(list: List<String>): List<String> {
            val seen = mutableSetOf<String>()
            return list.map { it.trim() }.filter { it.isNotEmpty() && seen.add(it.lowercase()) }
        }

        fun text(list: List<String>) = if (list.isEmpty()) "Ninguno registrado" else list.joinToString(", ")

        val SAMPLE = MedicalProfile(
            fullName = "María López",
            dateOfBirth = LocalDate.of(1958, 3, 14),
            bloodType = BloodType.O_POSITIVE,
            allergies = listOf("Penicilina"),
            conditions = listOf("Asma"),
            medications = listOf("Salbutamol"),
            contacts = listOf(EmergencyContact(name = "Ana López", relationship = "Hija", phone = "8112345678")),
        )
    }
}
