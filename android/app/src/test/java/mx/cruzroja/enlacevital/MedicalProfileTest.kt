package mx.cruzroja.enlacevital

import mx.cruzroja.enlacevital.core.networking.ApiJson
import mx.cruzroja.enlacevital.features.medicalprofile.model.BloodType
import mx.cruzroja.enlacevital.features.medicalprofile.model.EmergencyContact
import mx.cruzroja.enlacevital.features.medicalprofile.model.MedicalProfile
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate

class MedicalProfileTest {
    @Test
    fun cleanedTrimsAndDropsDuplicates() {
        val profile = MedicalProfile(
            fullName = "  María ",
            allergies = listOf(" Penicilina ", "", "penicilina", "Látex"),
            contacts = listOf(EmergencyContact(name = " Ana ", relationship = "Hija ", phone = "81 1234-5678")),
        ).cleaned()

        assertEquals("María", profile.fullName)
        assertEquals(listOf("Penicilina", "Látex"), profile.allergies)
        assertEquals("8112345678", profile.contacts[0].phone)
    }

    @Test
    fun validationReportsEachProblem() {
        val profile = MedicalProfile(
            fullName = " ",
            dateOfBirth = LocalDate.now().plusDays(1),
            contacts = listOf(EmergencyContact(name = "", relationship = "", phone = "123")),
        )
        assertEquals(5, profile.validationErrors.size)
        assertTrue(MedicalProfile.SAMPLE.isValid)
    }

    @Test
    fun formatsPhones() {
        assertEquals("81 1234 5678", MedicalProfile.formatPhone("8112345678"))
        assertEquals("123", MedicalProfile.formatPhone("123"))
        assertFalse(MedicalProfile.isValidPhone("81 1234 567"))
    }

    @Test
    fun decodesApiJsonAndFallsBackOnUnknownBloodType() {
        val json = """
            {"user_id":"00000000-0000-4000-8000-000000000001","full_name":"María López","date_of_birth":"1958-03-14",
             "blood_type":"Z+","allergies":["Penicilina"],"conditions":[],"medications":[],
             "contacts":[{"name":"Ana","relationship":"Hija","phone":"8112345678"}],"updated_at":"2026-10-21T18:14:07Z"}
        """.trimIndent()
        val profile = ApiJson.decodeFromString(MedicalProfile.serializer(), json)

        assertEquals(BloodType.UNKNOWN, profile.bloodType)
        assertEquals(LocalDate.of(1958, 3, 14), profile.dateOfBirth)
        assertEquals("Ana", profile.contacts[0].name)
    }

    @Test
    fun encodesSnakeCaseWithoutNulls() {
        val json = ApiJson.encodeToString(MedicalProfile.serializer(), MedicalProfile(fullName = "Ana", bloodType = BloodType.O_POSITIVE))
        assertTrue(json.contains("\"full_name\":\"Ana\""))
        assertTrue(json.contains("\"blood_type\":\"O+\""))
        assertFalse(json.contains("date_of_birth"))
    }

    @Test
    fun qrTextHidesContactsUnlessAsked() {
        assertFalse(MedicalProfile.SAMPLE.qrText(includeContacts = false).contains("Contacto"))
        assertTrue(MedicalProfile.SAMPLE.qrText(includeContacts = true).contains("Contacto: Ana López (Hija) 81 1234 5678"))
    }
}
