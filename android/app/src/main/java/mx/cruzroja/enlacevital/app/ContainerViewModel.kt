package mx.cruzroja.enlacevital.app

import androidx.compose.runtime.Composable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewmodel.compose.viewModel

val LocalAppContainer = staticCompositionLocalOf<AppContainer> { error("AppContainer not provided") }

// ViewModel built by the AppContainer and scoped to the nearest ViewModelStoreOwner
@Composable
inline fun <reified VM : ViewModel> containerViewModel(key: String? = null, crossinline create: AppContainer.() -> VM): VM {
    val container = LocalAppContainer.current
    return viewModel(key = key) { container.create() }
}
