package mx.cruzroja.enlacevital.app

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AccountCircle
import androidx.compose.material.icons.filled.Group
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.OndemandVideo
import androidx.compose.material.icons.filled.Sos
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.saveable.rememberSaveableStateHolder
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import mx.cruzroja.enlacevital.core.demo.DemoMode
import mx.cruzroja.enlacevital.core.design.BrandRed
import mx.cruzroja.enlacevital.features.alerts.ui.AlertsTab
import mx.cruzroja.enlacevital.features.emergency.ui.EmergencyTab
import mx.cruzroja.enlacevital.features.family.ui.FamilyTab
import mx.cruzroja.enlacevital.features.learn.ui.LearnTab
import mx.cruzroja.enlacevital.features.medicalprofile.ui.MedicalProfileTab

enum class AppTab(val label: String, val icon: ImageVector) {
    EMERGENCY("Emergencia", Icons.Filled.Sos),
    FAMILY("Familia", Icons.Filled.Group),
    ALERTS("Alertas", Icons.Filled.Notifications),
    LEARN("Aprende", Icons.Filled.OndemandVideo),
    PROFILE("Perfil", Icons.Filled.AccountCircle),
}

private fun demoTab() = when (DemoMode.current) {
    "family" -> AppTab.FAMILY
    "alerts" -> AppTab.ALERTS
    "learn", "lesson" -> AppTab.LEARN
    "profile", "login" -> AppTab.PROFILE
    else -> AppTab.EMERGENCY
}

@Composable
fun RootScreen() {
    var tab by rememberSaveable { mutableStateOf(demoTab()) }
    // Keeps each tab's navigation stack when switching tabs
    val stateHolder = rememberSaveableStateHolder()

    Scaffold(
        bottomBar = {
            NavigationBar(containerColor = Color.White) {
                AppTab.entries.forEach { item ->
                    NavigationBarItem(
                        selected = tab == item,
                        onClick = { tab = item },
                        icon = { Icon(item.icon, contentDescription = null) },
                        label = { Text(item.label) },
                        colors = NavigationBarItemDefaults.colors(selectedIconColor = BrandRed, selectedTextColor = BrandRed, indicatorColor = Color.Transparent),
                    )
                }
            }
        },
    ) { padding ->
        // Tab screens draw their own top bar under the status bar
        Box(Modifier.padding(bottom = padding.calculateBottomPadding())) {
            stateHolder.SaveableStateProvider(tab.name) {
                when (tab) {
                    AppTab.EMERGENCY -> EmergencyTab()
                    AppTab.FAMILY -> FamilyTab()
                    AppTab.ALERTS -> AlertsTab()
                    AppTab.LEARN -> LearnTab()
                    AppTab.PROFILE -> MedicalProfileTab()
                }
            }
        }
    }
}
