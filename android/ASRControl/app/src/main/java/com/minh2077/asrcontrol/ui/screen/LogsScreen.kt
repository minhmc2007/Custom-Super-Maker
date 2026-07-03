package com.minh2077.asrcontrol.ui.screen

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Description
import androidx.compose.material.icons.rounded.Terminal
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.minh2077.asrcontrol.ui.viewmodel.LogsViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LogsScreen(viewModel: LogsViewModel = hiltViewModel()) {
    Scaffold(
        topBar = { TopAppBar(title = { Text("System Logs") }) }
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .padding(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                Button(onClick = { viewModel.getAndroidLogs() }) {
                    Icon(Icons.Rounded.Description, contentDescription = null)
                    Spacer(Modifier.width(8.dp))
                    Text("Android Logs")
                }
                Button(onClick = { viewModel.getKernelLogs() }, colors = ButtonDefaults.filledTonalButtonColors()) {
                    Icon(Icons.Rounded.Terminal, contentDescription = null)
                    Spacer(Modifier.width(8.dp))
                    Text("Kernel Logs")
                }
            }
            Spacer(modifier = Modifier.height(16.dp))
            if (viewModel.isLoading.value) {
                Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
            } else {
                val logs = if (viewModel.androidLogs.value.isNotEmpty()) viewModel.androidLogs.value else viewModel.kernelLogs.value
                if (logs.isNotEmpty()) {
                    Card(
                        modifier = Modifier.fillMaxSize(),
                        shape = RoundedCornerShape(8.dp),
                        colors = CardDefaults.cardColors(containerColor = Color(0xFF1E1E1E))
                    ) {
                        SelectionContainer {
                            Text(
                                text = logs,
                                color = Color(0xFF00FF00),
                                fontFamily = FontFamily.Monospace,
                                fontSize = 12.sp,
                                modifier = Modifier.padding(12.dp).verticalScroll(rememberScrollState())
                            )
                        }
                    }
                } else if (viewModel.error.value != null) {
                    Text("Error: ${viewModel.error.value}", color = MaterialTheme.colorScheme.error)
                } else {
                    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        Text("Select a log type to view", color = MaterialTheme.colorScheme.outline)
                    }
                }
            }
        }
    }
}