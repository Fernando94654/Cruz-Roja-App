package mx.cruzroja.enlacevital.core.networking

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.KSerializer
import kotlinx.serialization.SerializationException
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.io.IOException
import java.util.concurrent.TimeUnit

sealed class ApiError(message: String) : Exception(message) {
    data object Offline : ApiError("No se pudo conectar con el servidor. Revisa tu conexión e intenta de nuevo.")
    data object InvalidResponse : ApiError("El servidor respondió algo inesperado.")
    class InvalidData(detail: String) : ApiError("Revisa los datos: $detail")
    class Server(status: Int, detail: String?) : ApiError(detail ?: "Error del servidor ($status).")
}

val ApiJson = Json {
    ignoreUnknownKeys = true
    // Unknown enum values fall back to the property's default
    coerceInputValues = true
    encodeDefaults = true
    explicitNulls = false
}

class ApiClient(
    private val baseUrl: String = ApiConfig.baseUrl,
    private val http: OkHttpClient = OkHttpClient.Builder()
        .callTimeout(ApiConfig.TIMEOUT_SECONDS, TimeUnit.SECONDS)
        .build(),
    private val json: Json = ApiJson,
) {
    // Returns null when the resource doesn't exist (404)
    suspend fun <T> get(path: String, serializer: KSerializer<T>): T? {
        val (status, body) = send(Request.Builder().url(baseUrl + path).get().build())
        if (status == 404) return null
        verify(status, body)
        return decode(body, serializer)
    }

    suspend fun <B, T> put(path: String, body: B, bodySerializer: KSerializer<B>, serializer: KSerializer<T>): T {
        val payload = json.encodeToString(bodySerializer, body).toRequestBody(JSON_TYPE)
        val (status, response) = send(Request.Builder().url(baseUrl + path).put(payload).build())
        verify(status, response)
        return decode(response, serializer)
    }

    private suspend fun send(request: Request): Pair<Int, String> = withContext(Dispatchers.IO) {
        try {
            http.newCall(request).execute().use { it.code to it.body?.string().orEmpty() }
        } catch (e: IOException) {
            throw ApiError.Offline
        }
    }

    private fun verify(status: Int, body: String) {
        when (status) {
            in 200..299 -> return
            422 -> throw ApiError.InvalidData(message(body) ?: "algún campo no es válido.")
            else -> throw ApiError.Server(status, message(body))
        }
    }

    private fun <T> decode(body: String, serializer: KSerializer<T>): T = try {
        json.decodeFromString(serializer, body)
    } catch (e: SerializationException) {
        throw ApiError.InvalidResponse
    } catch (e: IllegalArgumentException) {
        throw ApiError.InvalidResponse
    }

    companion object {
        private val JSON_TYPE = "application/json".toMediaType()

        // FastAPI puts errors in "detail", either as text or as a list of validation errors
        fun message(body: String): String? {
            val detail = runCatching { ApiJson.parseToJsonElement(body).jsonObject["detail"] }.getOrNull()
            return when (detail) {
                is JsonPrimitive -> detail.content
                is JsonArray -> (detail.firstOrNull() as? JsonObject)?.get("msg")?.jsonPrimitive?.content
                    ?.replace("Value error, ", "")
                else -> null
            }
        }
    }
}
