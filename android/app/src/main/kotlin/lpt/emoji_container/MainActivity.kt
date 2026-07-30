package lpt.emoji_container

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "lpt.emoji_container/storage"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openManageAllFilesSettings" -> {
                        openManageAllFilesSettings()
                        result.success(null)
                    }
                    "isExternalStorageManager" -> {
                        result.success(
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                                Environment.isExternalStorageManager()
                            } else {
                                true
                            },
                        )
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun openManageAllFilesSettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            try {
                val intent = Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION).apply {
                    data = Uri.parse("package:$packageName")
                }
                startActivity(intent)
                return
            } catch (_: Exception) {
                // fall through
            }
            try {
                startActivity(Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION))
                return
            } catch (_: Exception) {
                // fall through
            }
        }
        startActivity(
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:$packageName")
            },
        )
    }
}
