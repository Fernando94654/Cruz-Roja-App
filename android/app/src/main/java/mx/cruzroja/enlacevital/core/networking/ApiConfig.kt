package mx.cruzroja.enlacevital.core.networking

import mx.cruzroja.enlacevital.BuildConfig

object ApiConfig {
    val baseUrl: String = BuildConfig.API_BASE_URL

    // Demo user created by backend/scripts/seed.py until real sign-in exists
    const val DEMO_USER_ID = "00000000-0000-4000-8000-000000000001"

    const val TIMEOUT_SECONDS = 10L
}
