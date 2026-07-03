package com.minh2077.asrcontrol

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.*
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.navigation.NavDestination.Companion.hierarchy
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.minh2077.asrcontrol.ui.Screen
import com.minh2077.asrcontrol.ui.screen.*
import com.minh2077.asrcontrol.ui.theme.ASRControlTheme
import dagger.hilt.android.AndroidEntryPoint

@AndroidEntryPoint
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            ASRControlTheme {
                val navController = rememberNavController()
                val screens = listOf(
                    Screen.Main,
                    Screen.Info,
                    Screen.Logs,
                    Screen.Tweaks,
                    Screen.About
                )

                Scaffold(
                    bottomBar = {
                        NavigationBar {
                            val navBackStackEntry by navController.currentBackStackEntryAsState()
                            val currentDestination = navBackStackEntry?.destination
                            screens.forEach { screen ->
                                NavigationBarItem(
                                    icon = { Icon(screen.icon, contentDescription = null) },
                                    label = { Text(screen.title) },
                                    selected = currentDestination?.hierarchy?.any { it.route == screen.route } == true,
                                    onClick = {
                                        navController.navigate(screen.route) {
                                            popUpTo(navController.graph.findStartDestination().id) { saveState = true }
                                            launchSingleTop = true
                                            restoreState = true
                                        }
                                    }
                                )
                            }
                        }
                    }
                ) { innerPadding ->
                    NavHost(
                        navController,
                        startDestination = Screen.Main.route,
                        Modifier.padding(innerPadding)
                    ) {
                        composable(Screen.Main.route) { MainScreen() }
                        composable(Screen.Info.route) { InfoScreen() }
                        composable(Screen.Logs.route) { LogsScreen() }
                        composable(Screen.Tweaks.route) { TweaksScreen() }
                        composable(Screen.About.route) { AboutScreen() }
                    }
                }
            }
        }
    }
}