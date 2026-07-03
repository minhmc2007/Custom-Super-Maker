package com.minh2077.asrcontrol.ui.screen

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AboutScreen() {
    val uriHandler = LocalUriHandler.current

    Scaffold(
        topBar = { TopAppBar(title = { Text("About") }) }
    ) { padding ->
        LazyColumn(
            modifier = Modifier
            .fillMaxSize()
            .padding(padding)
            .padding(16.dp),
                   verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // Header
            item {
                ElevatedCard(
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer)
                ) {
                    Column(Modifier.padding(16.dp)) {
                        Text(
                            "Custom Super Maker",
                             style = MaterialTheme.typography.headlineMedium,
                             fontWeight = FontWeight.Bold
                        )
                        Spacer(Modifier.height(8.dp))
                        Text("Revive your laggy Samsung budget device by replacing the bloated OneUI with a lightweight custom ROM.")
                        Spacer(Modifier.height(8.dp))
                        Button(onClick = { uriHandler.openUri("https://github.com/minhmc2007/Custom-Super-Maker") }) {
                            Text("View on GitHub")
                        }
                    }
                }
            }

            // Updated Info (EROFS Supported)
            item {
                Card(
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.tertiaryContainer)
                ) {
                    Row(Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Rounded.CheckCircle, contentDescription = null, tint = MaterialTheme.colorScheme.onTertiaryContainer)
                        Spacer(Modifier.width(12.dp))
                        Column {
                            Text("File System Support", fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.onTertiaryContainer)
                            Text(
                                "This tool supports both EXT4 and EROFS file systems. You can use any compatible GSI.",
                                 style = MaterialTheme.typography.bodySmall,
                                 color = MaterialTheme.colorScheme.onTertiaryContainer
                            )
                        }
                    }
                }
            }

            item {
                SectionTitle("Supported Devices")
                Text("Samsung Galaxy A04s, A05, A05s, A06, A16, and other Treble-supported devices with a Super Partition.")
            }

            item {
                SectionTitle("What does this do?")
                Text(buildAnnotatedString {
                    append("It rebuilds the ")
                    withStyle(SpanStyle(fontWeight = FontWeight.Bold)) { append("Super Partition") }
                    append(" to replace the stock system image with a custom GSI. This runs entirely in the cloud via GitHub Actions.")
                })
            }

            item {
                SectionTitle("Disclaimer")
                Card(
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainerHigh)
                ) {
                    Text(
                        text = "I am not responsible for bricked devices, dead SD cards, or thermonuclear war. You are choosing to make these modifications. Flashing custom firmware voids warranties.",
                         modifier = Modifier.padding(12.dp),
                         style = MaterialTheme.typography.bodySmall,
                         color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }

            item {
                Spacer(Modifier.height(24.dp))
                CenterText("Built with ❤️ by Minhmc2077")
                CenterText("Original script by Uluruman")
            }
        }
    }
}

@Composable
fun SectionTitle(text: String) {
    Text(
        text = text,
         style = MaterialTheme.typography.titleMedium,
         color = MaterialTheme.colorScheme.primary,
         fontWeight = FontWeight.Bold,
         modifier = Modifier.padding(bottom = 4.dp, top = 8.dp)
    )
}

@Composable
fun CenterText(text: String) {
    Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
        Text(text, style = MaterialTheme.typography.labelMedium, color = Color.Gray)
    }
}
