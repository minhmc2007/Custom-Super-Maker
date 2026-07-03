package com.minh2077.asrcontrol.ui.screen

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.slideInVertically
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.minh2077.asrcontrol.ui.viewmodel.InfoViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun InfoScreen(viewModel: InfoViewModel = hiltViewModel()) {
    val systemProperties = viewModel.systemProperties.value
    var visible by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) { visible = true }

    Scaffold(
        topBar = {
            LargeTopAppBar(
                title = { Text("System Info") },
                colors = TopAppBarDefaults.largeTopAppBarColors(
                    containerColor = MaterialTheme.colorScheme.surface
                )
            )
        }
    ) { paddingValues ->
        AnimatedVisibility(
            visible = visible,
            enter = fadeIn() + slideInVertically { it / 4 }
        ) {
            LazyColumn(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(paddingValues)
                    .padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                item {
                    InfoSection(title = "Device Status") {
                        InfoRow(Icons.Rounded.Smartphone, "ROM", systemProperties["ro.build.display.id"] ?: "Unknown")
                        HorizontalDivider(modifier = Modifier.padding(vertical = 8.dp))
                        InfoRow(Icons.Rounded.Security, "Root Access", if(viewModel.isRooted.value) "Granted" else "Denied",
                            color = if(viewModel.isRooted.value) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.error)
                        InfoRow(Icons.Rounded.Build, "BusyBox", if(viewModel.hasBusyBox.value) "Installed" else "Missing")
                    }
                }

                item {
                    InfoSection(title = "Repack Details") {
                        InfoRow(Icons.Rounded.Info, "Version", systemProperties["ro.repack.version"] ?: "N/A")
                        InfoRow(Icons.Rounded.Person, "Author", systemProperties["ro.repack.author"] ?: "N/A")
                        InfoRow(Icons.Rounded.Storage, "File System", systemProperties["ro.repack.fs"] ?: "N/A")
                        InfoRow(Icons.Rounded.Layers, "GSI Type", systemProperties["ro.repack.gsi"] ?: "N/A")
                    }
                }
            }
        }
    }
}

@Composable
fun InfoSection(title: String, content: @Composable ColumnScope.() -> Unit) {
    Column {
        Text(
            text = title,
            style = MaterialTheme.typography.titleMedium,
            color = MaterialTheme.colorScheme.primary,
            modifier = Modifier.padding(start = 4.dp, bottom = 8.dp)
        )
        ElevatedCard(
            modifier = Modifier.fillMaxWidth(),
            colors = CardDefaults.elevatedCardColors(containerColor = MaterialTheme.colorScheme.surfaceContainerLow)
        ) {
            Column(modifier = Modifier.padding(16.dp)) {
                content()
            }
        }
    }
}

@Composable
fun InfoRow(icon: ImageVector, label: String, value: String, color: Color = MaterialTheme.colorScheme.onSurface) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.secondary,
            modifier = Modifier.size(20.dp)
        )
        Spacer(modifier = Modifier.width(12.dp))
        Column {
            Text(text = label, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.outline)
            Text(text = value, style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.Medium, color = color)
        }
    }
}