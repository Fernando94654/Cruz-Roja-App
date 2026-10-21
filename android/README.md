# Enlace Vital — Android

Native Android port of the iOS app: Kotlin, Jetpack Compose, Material 3, MVVM (`ViewModel` + `StateFlow`), manual DI through `app/AppContainer.kt`. The package layout mirrors `CruzRoja/` (`app`, `core`, `features/<feature>/{model,data,ui}`).

## Requirements

- JDK 17 (`JAVA_HOME`)
- Android SDK with `platforms;android-35`, `build-tools;35.0.0`, `platform-tools`, `emulator` and an x86_64 system image
- `android/local.properties` with `sdk.dir=/path/to/Android/Sdk`

## Run on the emulator

```bash
# backend (from the repo root): docker compose up -d, then in backend/: uvicorn app.main:app
emulator -avd enlace_vital &
cd android
./gradlew installDebug
adb shell am start -n mx.cruzroja.enlacevital/.app.MainActivity
```

The app calls the API at `http://10.0.2.2:8000/`, the emulator's alias for the host's localhost (`API_BASE_URL` in `app/build.gradle.kts`). Cleartext HTTP is allowed only for that host.

## Tests

```bash
./gradlew testDebugUnitTest
```

## Demo screens

Same flags as iOS, passed as an intent extra:

```bash
adb shell am start -n mx.cruzroja.enlacevital/.app.MainActivity -e demo report
```

`report`, `vitals`, `summary`, `sent`, `firstaid`, `guide`, `countdown`, `confirm`, `family`, `alerts`, `learn`, `lesson`, `profile`, `login`.

## Notes

- Maps use OpenStreetMap (osmdroid), so no API key is needed.
- Speech uses Android TextToSpeech with a Spanish (Mexico) voice when installed.
- With 14 GB of RAM, keep the emulator at 1.5–2 GB and Gradle at `-Xmx2g`; otherwise the OOM killer may stop the emulator during builds.
