package mx.cruzroja.enlacevital.features.firstaid.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.MenuBook
import androidx.compose.material.icons.filled.ArrowUpward
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.filled.GraphicEq
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.automirrored.filled.VolumeUp
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import mx.cruzroja.enlacevital.core.design.AmbulanceStatusBar
import mx.cruzroja.enlacevital.core.design.BrandRed
import mx.cruzroja.enlacevital.core.design.ScreenScaffold
import mx.cruzroja.enlacevital.core.design.SoftGray
import mx.cruzroja.enlacevital.core.design.brandStyle
import mx.cruzroja.enlacevital.core.design.symbol
import mx.cruzroja.enlacevital.features.firstaid.model.AssistantAnswer
import mx.cruzroja.enlacevital.features.firstaid.model.ChatMessage
import mx.cruzroja.enlacevital.features.firstaid.model.FirstAidGuide

@Composable
fun FirstAidScreen(viewModel: FirstAidViewModel, onBack: () -> Unit, onGuide: (FirstAidGuide) -> Unit) {
    val state by viewModel.state.collectAsState()
    val ambulance by viewModel.ambulance.state.collectAsState()
    val isSpeaking by viewModel.speech.isSpeaking.collectAsState()
    val listState = rememberLazyListState()
    val focus = LocalFocusManager.current

    LaunchedEffect(state.messages.size, state.isThinking) {
        val count = listState.layoutInfo.totalItemsCount
        if (count > 0) listState.animateScrollToItem(count - 1)
    }
    DisposableEffect(Unit) { onDispose { viewModel.stop() } }

    fun send(text: String) {
        focus.clearFocus()
        viewModel.send(text)
    }

    ScreenScaffold(
        title = "Primeros auxilios",
        onBack = onBack,
        actions = { if (state.messages.isNotEmpty()) TextButton(onClick = viewModel::reset) { Text("Nueva") } },
        bottomBar = {
            Surface(color = Color.White, modifier = Modifier.imePadding()) {
                Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 10.dp), verticalAlignment = Alignment.CenterVertically) {
                    TextField(
                        value = state.draft,
                        onValueChange = viewModel::setDraft,
                        placeholder = { Text(if (state.isListening) "Escuchando…" else "¿Qué está pasando?") },
                        maxLines = 4,
                        shape = RoundedCornerShape(20.dp),
                        colors = TextFieldDefaults.colors(
                            focusedIndicatorColor = Color.Transparent,
                            unfocusedIndicatorColor = Color.Transparent,
                            unfocusedContainerColor = SoftGray,
                            focusedContainerColor = SoftGray,
                        ),
                        modifier = Modifier.weight(1f),
                    )
                    Spacer(Modifier.width(10.dp))
                    IconButton(
                        onClick = { if (state.hasDraft) send(state.draft) else { focus.clearFocus(); viewModel.dictate() } },
                        enabled = !state.isListening && !state.isThinking,
                        modifier = Modifier.size(46.dp).clip(CircleShape).background(if (state.isListening) Color.Black else BrandRed),
                    ) {
                        Icon(
                            when {
                                state.hasDraft -> Icons.Filled.ArrowUpward
                                state.isListening -> Icons.Filled.GraphicEq
                                else -> Icons.Filled.Mic
                            },
                            contentDescription = null,
                            tint = Color.White,
                        )
                    }
                }
            }
        },
    ) { padding ->
        LazyColumn(
            Modifier.padding(padding),
            state = listState,
            contentPadding = androidx.compose.foundation.layout.PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            item {
                AmbulanceStatusBar(ambulance.status, viewModel.ambulance.unit, ambulance.timeLeft, ambulance.progress, ambulance.hasArrived)
            }
            if (state.messages.isEmpty()) {
                item { Intro(viewModel, onSuggestion = ::send, onGuide = onGuide) }
            }
            items(state.messages, key = { it.id }) { message ->
                when (message) {
                    is ChatMessage.User -> Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
                        Text(
                            message.text,
                            color = Color.White,
                            modifier = Modifier.padding(start = 40.dp).clip(RoundedCornerShape(16.dp)).background(BrandRed).padding(12.dp),
                        )
                    }
                    is ChatMessage.Assistant -> AnswerCard(message.answer, isSpeaking, onToggleSpeech = { viewModel.toggleSpeech(message.answer) }, onGuide = onGuide)
                }
            }
            if (state.isThinking) {
                item {
                    Row(
                        Modifier.clip(RoundedCornerShape(14.dp)).background(SoftGray).padding(12.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        CircularProgressIndicator(Modifier.size(18.dp), strokeWidth = 2.dp)
                        Text("  Buscando en el material de Cruz Roja…", color = Color.Gray)
                    }
                }
            }
        }
    }
}

@Composable
private fun Intro(viewModel: FirstAidViewModel, onSuggestion: (String) -> Unit, onGuide: (FirstAidGuide) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Text("Describe la emergencia", style = brandStyle(30))
        Text("Escribe o habla. El asistente busca en el material de Cruz Roja y te guía paso a paso por voz.", color = Color.Gray)
        Row(
            Modifier.clip(CircleShape).background(BrandRed.copy(alpha = 0.1f)).padding(horizontal = 10.dp, vertical = 6.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(Icons.AutoMirrored.Filled.MenuBook, contentDescription = null, tint = BrandRed, modifier = Modifier.size(16.dp))
            Text(" RAG sobre manuales de Cruz Roja · demo", color = BrandRed, style = MaterialTheme.typography.labelMedium)
        }
        viewModel.suggestions.forEach { suggestion ->
            Text(
                suggestion,
                modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(SoftGray).clickable { onSuggestion(suggestion) }.padding(12.dp),
            )
        }
        Text("O elige el tipo de emergencia", color = Color.Gray, fontWeight = FontWeight.Medium)
        Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            viewModel.guides.forEach { guide ->
                Row(
                    Modifier.clip(CircleShape).background(SoftGray).clickable { onGuide(guide) }.padding(horizontal = 12.dp, vertical = 8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(symbol(guide.icon), contentDescription = null, modifier = Modifier.size(18.dp))
                    Text(" ${guide.title}")
                }
            }
        }
        Text("Basado en protocolos de Cruz Roja. No sustituye un curso certificado.", style = MaterialTheme.typography.bodySmall, color = Color.Gray)
    }
}

@Composable
private fun AnswerCard(answer: AssistantAnswer, isSpeaking: Boolean, onToggleSpeech: () -> Unit, onGuide: (FirstAidGuide) -> Unit) {
    Column(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(SoftGray).padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        answer.guide?.let { guide ->
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(symbol(guide.icon), contentDescription = null, tint = BrandRed)
                Text(" ${guide.title}", color = BrandRed, fontWeight = FontWeight.SemiBold)
            }
        }
        Text(answer.text)
        Column(
            Modifier.fillMaxWidth().clip(RoundedCornerShape(10.dp)).background(Color.White).padding(10.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Text("Fuentes consultadas", style = MaterialTheme.typography.labelMedium, color = Color.Gray)
            answer.sources.forEach { source ->
                Row(verticalAlignment = Alignment.Top) {
                    Icon(Icons.Filled.Description, contentDescription = null, tint = BrandRed, modifier = Modifier.size(16.dp))
                    Column(Modifier.padding(start = 8.dp)) {
                        Text("${source.document} · pág. ${source.page}", style = MaterialTheme.typography.labelMedium)
                        Text("“${source.excerpt}”", style = MaterialTheme.typography.bodySmall, color = Color.Gray, maxLines = 2)
                    }
                }
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            OutlinedButton(onClick = onToggleSpeech) {
                Icon(if (isSpeaking) Icons.Filled.Stop else Icons.AutoMirrored.Filled.VolumeUp, contentDescription = null, tint = Color.Black)
                Text(if (isSpeaking) " Detener" else " Escuchar", color = Color.Black)
            }
            answer.guide?.let { guide ->
                Button(onClick = { onGuide(guide) }, colors = ButtonDefaults.buttonColors(containerColor = Color.Black)) {
                    Icon(Icons.Filled.PlayArrow, contentDescription = null)
                    Text(" Iniciar guía por voz")
                }
            }
        }
    }
}
