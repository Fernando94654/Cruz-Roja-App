package mx.cruzroja.enlacevital.app

import android.app.Application

class EnlaceVitalApp : Application() {
    lateinit var container: AppContainer
        private set

    override fun onCreate() {
        super.onCreate()
        container = AppContainer(this)
    }
}
