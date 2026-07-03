package com.minh2077.asrcontrol.data.util

import java.io.BufferedReader
import java.io.DataOutputStream
import java.io.InputStreamReader

object ShellUtils {
    fun execRootCmd(command: String): String {
        var process: Process? = null
        var os: DataOutputStream? = null
        val output = StringBuilder()

        try {
            process = Runtime.getRuntime().exec("su")
            os = DataOutputStream(process.outputStream)
            os.writeBytes("$command\n")
            os.writeBytes("exit\n")
            os.flush()

            val reader = BufferedReader(InputStreamReader(process.inputStream))
            var line: String?
            while (reader.readLine().also { line = it } != null) {
                output.append(line).append("\n")
            }
            process.waitFor()
        } catch (e: Exception) {
            return "Error: ${e.message}\n\nMake sure your device is Rooted and you granted permission."
        } finally {
            try {
                os?.close()
                process?.destroy()
            } catch (e: Exception) { /* ignored */ }
        }
        return output.toString()
    }
}
