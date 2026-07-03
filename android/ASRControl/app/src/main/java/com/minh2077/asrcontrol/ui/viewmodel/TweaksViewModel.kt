package com.minh2077.asrcontrol.ui.viewmodel

import android.app.DownloadManager
import android.content.Context
import android.net.Uri
import android.os.Environment
import android.widget.Toast
import androidx.compose.runtime.mutableStateOf
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.minh2077.asrcontrol.data.model.MagiskItem
import com.minh2077.asrcontrol.data.repository.SystemRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class TweaksViewModel @Inject constructor(
    private val systemRepository: SystemRepository,
        @ApplicationContext private val context: Context
) : ViewModel() {

    val magiskList = mutableStateOf<List<MagiskItem>>(emptyList())
    val isRooted = mutableStateOf(false)
    val isLoading = mutableStateOf(false)

    init {
        loadData()
    }

    private fun loadData() {
        viewModelScope.launch {
            isLoading.value = true
            isRooted.value = systemRepository.isRooted()
            if (isRooted.value) {
                magiskList.value = systemRepository.getMagiskConfig()
            }
            isLoading.value = false
        }
    }

    fun downloadFile(url: String, title: String) {
        try {
            val request = DownloadManager.Request(Uri.parse(url))
            .setTitle(title)
            .setDescription("Downloading...")
            .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
            .setDestinationInExternalPublicDir(Environment.DIRECTORY_DOWNLOADS, "$title.apk")
            .setAllowedOverMetered(true)
            .setAllowedOverRoaming(true)

            val dm = context.getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
            dm.enqueue(request)
            Toast.makeText(context, "Downloading $title...", Toast.LENGTH_SHORT).show()
        } catch (e: Exception) {
            Toast.makeText(context, "Download failed: ${e.message}", Toast.LENGTH_LONG).show()
        }
    }
}
