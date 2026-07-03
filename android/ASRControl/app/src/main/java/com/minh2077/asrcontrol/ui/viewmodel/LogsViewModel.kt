package com.minh2077.asrcontrol.ui.viewmodel

import androidx.compose.runtime.mutableStateOf
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.minh2077.asrcontrol.data.repository.SystemRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class LogsViewModel @Inject constructor(
    private val systemRepository: SystemRepository
) : ViewModel() {

    val androidLogs = mutableStateOf("")
    val kernelLogs = mutableStateOf("")
    val isLoading = mutableStateOf(false)
    val error = mutableStateOf<String?>(null)

    fun getAndroidLogs() {
        viewModelScope.launch {
            isLoading.value = true
            error.value = null
            try {
                androidLogs.value = systemRepository.getAndroidLogs()
            } catch (e: Exception) {
                error.value = "Error getting Android logs: ${e.message}"
            } finally {
                isLoading.value = false
            }
        }
    }

    fun getKernelLogs() {
        viewModelScope.launch {
            isLoading.value = true
            error.value = null
            try {
                kernelLogs.value = systemRepository.getKernelLogs()
            } catch (e: Exception) {
                error.value = "Error getting Kernel logs: ${e.message}"
            } finally {
                isLoading.value = false
            }
        }
    }
}
