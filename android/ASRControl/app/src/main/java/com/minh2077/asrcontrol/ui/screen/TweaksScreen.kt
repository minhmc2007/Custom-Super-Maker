package com.minh2077.asrcontrol.ui.screen

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Android
import androidx.compose.material.icons.rounded.Download
import androidx.compose.material.icons.rounded.Lock
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.minh2077.asrcontrol.ui.viewmodel.TweaksViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TweaksScreen(viewModel: TweaksViewModel = hiltViewModel()) {
    val isRooted = viewModel.isRooted.value
    val magiskList = viewModel.magiskList.value
    val isLoading = viewModel.isLoading.value
    val uriHandler = LocalUriHandler.current

    Scaffold(
        topBar = { TopAppBar(title = { Text("Tweaks") }) }
    ) { padding ->
        if (isLoading) {
            Box(Modifier.fillMaxSize().padding(padding), contentAlignment = Alignment.Center) {
                CircularProgressIndicator()
            }
        } else if (!isRooted) {
            Box(
                modifier = Modifier.fillMaxSize().padding(padding),
                contentAlignment = Alignment.Center
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Icon(
                        Icons.Rounded.Lock,
                         contentDescription = null,
                         modifier = Modifier.size(64.dp),
                         tint = MaterialTheme.colorScheme.error
                    )
                    Spacer(Modifier.height(16.dp))
                    Text("Root Access Required", style = MaterialTheme.typography.headlineSmall)
                    Text("This section is only for rooted devices.", color = Color.Gray)
                }
            }
        } else {
            LazyColumn(
                modifier = Modifier.fillMaxSize().padding(padding).padding(16.dp),
                       verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                item {
                    Text(
                        "Magisk",
                         style = MaterialTheme.typography.titleMedium,
                         color = MaterialTheme.colorScheme.primary
                    )
                }

                items(magiskList) { item ->
                    ElevatedCard(
                        modifier = Modifier.fillMaxWidth(),
                                 colors = CardDefaults.elevatedCardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer)
                    ) {
                        Row(
                            modifier = Modifier.padding(16.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Icon(
                                Icons.Rounded.Android,
                                 contentDescription = null,
                                 tint = Color(0xFF3DDC84),
                                 modifier = Modifier.size(40.dp)
                            )
                            Spacer(Modifier.width(16.dp))
                            Column(modifier = Modifier.weight(1f)) {
                                Text(item.title, fontWeight = FontWeight.Bold)
                                Text("v${item.version} (${item.versionCode})", style = MaterialTheme.typography.bodySmall)
                                if (item.note.isNotEmpty()) {
                                    TextButton(onClick = { uriHandler.openUri(item.note) }) {
                                        Text("View Changelog")
                                    }
                                }
                            }
                            IconButton(
                                onClick = { viewModel.downloadFile(item.link, item.title) },
                                       colors = IconButtonDefaults.filledIconButtonColors()
                            ) {
                                Icon(Icons.Rounded.Download, contentDescription = "Download")
                            }
                        }
                    }
                }
            }
        }
    }
}
