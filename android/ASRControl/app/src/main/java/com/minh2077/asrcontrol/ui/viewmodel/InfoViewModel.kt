package com.minh2077.asrcontrol.ui.viewmodel

import androidx.compose.runtime.mutableStateOf
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.minh2077.asrcontrol.data.repository.SystemRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class InfoViewModel @Inject constructor(
    private val systemRepository: SystemRepository
) : ViewModel() {

    val systemProperties = mutableStateOf<Map<String, String>>(emptyMap())
    val isRooted = mutableStateOf(false)
    val hasBusyBox = mutableStateOf(false)

    init {
        loadSystemInfo()
    }

    private fun loadSystemInfo() {
        viewModelScope.launch {
            systemProperties.value = systemRepository.getSystemProperties()
            isRooted.value = systemRepository.isRooted()
            hasBusyBox.value = systemRepository.hasBusybox()
        }
    }
}
