package mx.cruzroja.enlacevital.features.medicalprofile.data

import mx.cruzroja.enlacevital.core.networking.ApiJson
import mx.cruzroja.enlacevital.features.medicalprofile.model.MedicalProfile
import java.io.File

// Last profile received from the API, so the profile and QR work offline; stored in app-private storage
class MedicalProfileCache(directory: File) {
    private val file = File(directory, "medical-profile.json")

    fun load(): MedicalProfile? = runCatching {
        ApiJson.decodeFromString(MedicalProfile.serializer(), file.readText())
    }.getOrNull()

    fun save(profile: MedicalProfile) {
        runCatching {
            file.parentFile?.mkdirs()
            file.writeText(ApiJson.encodeToString(MedicalProfile.serializer(), profile))
        }
    }

    fun clear() {
        file.delete()
    }
}
