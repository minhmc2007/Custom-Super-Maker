package com.minh2077.asrcontrol.ui

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Build
import androidx.compose.material.icons.rounded.Home
import androidx.compose.material.icons.rounded.Info
import androidx.compose.material.icons.rounded.Terminal
import androidx.compose.ui.graphics.vector.ImageVector

sealed class Screen(val route: String, val title: String, val icon: ImageVector) {
    object Main : Screen("main", "Home", Icons.Rounded.Home)
    object Info : Screen("info", "System", Icons.Rounded.Info)
    object Logs : Screen("logs", "Logs", Icons.Rounded.Terminal)
    object Tweaks : Screen("tweaks", "Tweaks", Icons.Rounded.Build)
    object About : Screen("about", "About", Icons.Rounded.Info)
}