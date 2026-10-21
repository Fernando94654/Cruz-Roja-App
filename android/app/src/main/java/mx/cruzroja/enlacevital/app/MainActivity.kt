package mx.cruzroja.enlacevital.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.CompositionLocalProvider
import mx.cruzroja.enlacevital.core.demo.DemoMode
import mx.cruzroja.enlacevital.core.design.EnlaceVitalTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        DemoMode.current = intent.getStringExtra("demo").orEmpty()
        val container = (application as EnlaceVitalApp).container
        setContent {
            CompositionLocalProvider(LocalAppContainer provides container) {
                EnlaceVitalTheme { RootScreen() }
            }
        }
    }
}
