package mx.cruzroja.enlacevital.features.medicalprofile.data

import mx.cruzroja.enlacevital.core.networking.ApiClient
import mx.cruzroja.enlacevital.features.medicalprofile.model.MedicalProfile
import java.time.Instant

interface MedicalProfileService {
    // Returns null when the user has no profile yet
    suspend fun fetchProfile(userId: String): MedicalProfile?

    // Creates or replaces the profile and returns what was stored
    suspend fun saveProfile(profile: MedicalProfile, userId: String): MedicalProfile
}

// GET and PUT /users/{id}/medical-profile
class MedicalProfileApiService(private val client: ApiClient = ApiClient()) : MedicalProfileService {
    override suspend fun fetchProfile(userId: String) =
        client.get(path(userId), MedicalProfile.serializer())

    override suspend fun saveProfile(profile: MedicalProfile, userId: String) =
        client.put(path(userId), profile, MedicalProfile.serializer(), MedicalProfile.serializer())

    private fun path(userId: String) = "users/${userId.lowercase()}/medical-profile"
}

class MockMedicalProfileService(private var profile: MedicalProfile? = MedicalProfile.SAMPLE) : MedicalProfileService {
    override suspend fun fetchProfile(userId: String) = profile

    override suspend fun saveProfile(profile: MedicalProfile, userId: String): MedicalProfile {
        val saved = profile.copy(userId = userId, updatedAt = Instant.now().toString())
        this.profile = saved
        return saved
    }
}
