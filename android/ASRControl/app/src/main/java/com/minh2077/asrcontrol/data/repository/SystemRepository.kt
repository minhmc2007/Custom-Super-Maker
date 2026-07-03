package com.minh2077.asrcontrol.data.repository

import com.minh2077.asrcontrol.data.model.MagiskItem
import com.minh2077.asrcontrol.data.util.ShellUtils
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.io.BufferedReader
import java.io.File
import java.io.InputStreamReader
import java.net.URL
import javax.inject.Inject

class SystemRepository @Inject constructor() {

    fun getSystemProperties(): Map<String, String> {
        val properties = mutableMapOf<String, String>()
        try {
            val process = Runtime.getRuntime().exec("getprop")
            val reader = BufferedReader(InputStreamReader(process.inputStream))
            var line: String?
            while (reader.readLine().also { line = it } != null) {
                val parts = line!!.split(": ")
                if (parts.size >= 2) {
                    val key = parts[0].trim().removeSurrounding("[", "]")
                    val value = parts[1].trim().removeSurrounding("[", "]")
                    properties[key] = value
                }
            }
            reader.close()
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return properties
    }

    fun isRooted(): Boolean {
        // Simple check + check if we can actually run su
        val paths = arrayOf("/sbin/su", "/system/bin/su", "/system/xbin/su", "/data/local/xbin/su", "/data/local/bin/su", "/system/sd/xbin/su", "/system/bin/failsafe/su", "/data/local/su", "/su/bin/su")
        if (paths.none { File(it).exists() }) return false

        return try {
            val process = Runtime.getRuntime().exec(arrayOf("su", "-c", "id"))
            process.waitFor() == 0
        } catch (e: Exception) {
            false
        }
    }

    fun hasBusybox(): Boolean {
        return try {
            val process = Runtime.getRuntime().exec(arrayOf("which", "busybox"))
            process.waitFor() == 0
        } catch (e: Exception) {
            false
        }
    }

    // Updated to use Root Shell
    fun getAndroidLogs(): String = ShellUtils.execRootCmd("logcat -d -t 500 -v threadtime")
    fun getKernelLogs(): String = ShellUtils.execRootCmd("dmesg")

    suspend fun getMagiskConfig(): List<MagiskItem> = withContext(Dispatchers.IO) {
        try {
            // Using the raw JSON url provided or a fallback
            val jsonString = URL("https://raw.githubusercontent.com/topjohnwu/magisk-files/refs/heads/master/stable.json").readText()
            val json = JSONObject(jsonString)

            val list = mutableListOf<MagiskItem>()

            // Parse Magisk
            if (json.has("magisk")) {
                val m = json.getJSONObject("magisk")
                list.add(MagiskItem(
                    title = "Magisk Stable",
                    version = m.optString("version"),
                    versionCode = m.optString("versionCode"),
                    link = m.optString("link"),
                    note = m.optString("note")
                ))
            }
            // Parse Stub (if needed, or just Magisk)
            // You can extend this logic if the JSON structure changes

            list
        } catch (e: Exception) {
            e.printStackTrace()
            emptyList()
        }
    }
}