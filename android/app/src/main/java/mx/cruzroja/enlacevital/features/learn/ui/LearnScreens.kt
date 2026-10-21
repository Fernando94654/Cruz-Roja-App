package mx.cruzroja.enlacevital.features.learn.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.VolumeUp
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material.icons.filled.Verified
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import mx.cruzroja.enlacevital.app.containerViewModel
import mx.cruzroja.enlacevital.core.demo.DemoMode
import mx.cruzroja.enlacevital.core.design.BrandRed
import mx.cruzroja.enlacevital.core.design.ScreenScaffold
import mx.cruzroja.enlacevital.core.design.Section
import mx.cruzroja.enlacevital.core.design.brandStyle
import mx.cruzroja.enlacevital.features.learn.model.Lesson

@Composable
fun LearnTab() {
    val navController = rememberNavController()
    val viewModel = containerViewModel { makeLearnViewModel() }
    val lessons by viewModel.lessons.collectAsState()
    var appliedDemo by rememberSaveable { mutableStateOf(false) }

    NavHost(navController, startDestination = "lessons") {
        composable("lessons") {
            LearnScreen(lessons, onLesson = { navController.navigate("lesson/${it.id}") })
        }
        composable("lesson/{id}") { entry ->
            val lesson = lessons.firstOrNull { it.id == entry.arguments?.getString("id") } ?: return@composable
            LessonScreen(containerViewModel(key = "lesson-${lesson.id}") { makeLessonViewModel(lesson) }, onBack = navController::popBackStack)
        }
    }

    LaunchedEffect(lessons) {
        val first = lessons.firstOrNull()
        if (!appliedDemo && first != null && DemoMode.isActive("lesson")) {
            appliedDemo = true
            navController.navigate("lesson/${first.id}")
        }
    }
}

@Composable
private fun LearnScreen(lessons: List<Lesson>, onLesson: (Lesson) -> Unit) {
    ScreenScaffold(title = "Aprende") { padding ->
        Column(Modifier.padding(padding).verticalScroll(rememberScrollState())) {
            Section {
                lessons.forEachIndexed { i, lesson ->
                    if (i > 0) HorizontalDivider()
                    Row(
                        Modifier.fillMaxWidth().clickable { onLesson(lesson) }.padding(vertical = 4.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        LessonThumbnail(Modifier.size(width = 110.dp, height = 66.dp))
                        Column(Modifier.padding(start = 14.dp)) {
                            Text(lesson.title, fontWeight = FontWeight.SemiBold)
                            Text("Video · ${lesson.duration}", color = Color.Gray)
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun LessonThumbnail(modifier: Modifier = Modifier) {
    Box(modifier.clip(RoundedCornerShape(10.dp)).background(Color.LightGray.copy(alpha = 0.5f)), contentAlignment = Alignment.Center) {
        Icon(
            Icons.Filled.PlayArrow,
            contentDescription = null,
            tint = Color.White,
            modifier = Modifier.clip(CircleShape).background(Color.Black.copy(alpha = 0.35f)).padding(10.dp),
        )
    }
}

@Composable
private fun LessonScreen(viewModel: LessonViewModel, onBack: () -> Unit) {
    val lesson = viewModel.lesson
    val playback by viewModel.playback.collectAsState()
    val isSpeaking by viewModel.speech.isSpeaking.collectAsState()

    ScreenScaffold(title = "", onBack = onBack) { padding ->
        Column(
            Modifier.padding(padding).verticalScroll(rememberScrollState()).padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            // Placeholder player until lesson videos exist
            LessonThumbnail(Modifier.fillMaxWidth().aspectRatio(16f / 9f))
            Column {
                Slider(
                    value = playback,
                    onValueChange = viewModel::setPlayback,
                    colors = SliderDefaults.colors(thumbColor = BrandRed, activeTrackColor = BrandRed),
                )
                Row {
                    Text("0:00", style = MaterialTheme.typography.bodySmall, color = Color.Gray, modifier = Modifier.weight(1f))
                    Text(lesson.duration, style = MaterialTheme.typography.bodySmall, color = Color.Gray)
                }
            }
            Text(lesson.title, style = brandStyle(28))
            Text(lesson.summary, color = Color.Gray)
            lesson.steps.forEachIndexed { i, step ->
                Row(verticalAlignment = Alignment.Top) {
                    Box(Modifier.size(28.dp).clip(CircleShape).background(BrandRed), contentAlignment = Alignment.Center) {
                        Text("${i + 1}", color = Color.White, fontWeight = FontWeight.SemiBold)
                    }
                    Text(step, modifier = Modifier.padding(start = 12.dp))
                }
            }
            OutlinedButton(onClick = viewModel::toggleSpeech) {
                Icon(if (isSpeaking) Icons.Filled.Stop else Icons.AutoMirrored.Filled.VolumeUp, contentDescription = null, tint = Color.Black)
                Text(if (isSpeaking) " Detener" else " Escuchar lección", color = Color.Black)
            }
            HorizontalDivider()
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Filled.Verified, contentDescription = null)
                Text(" Lección certificada por instructores de Cruz Roja")
            }
        }
    }
}
