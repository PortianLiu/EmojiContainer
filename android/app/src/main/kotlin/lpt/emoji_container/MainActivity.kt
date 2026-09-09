package lpt.emoji_container

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.Settings
import android.webkit.MimeTypeMap
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val storageChannelName = "lpt.emoji_container/storage"
    private val shareChannelName = "lpt.emoji_container/share"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, storageChannelName)
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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, shareChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "shareToPackage" -> {
                        val filePath = call.argument<String>("filePath")
                        val packageName = call.argument<String>("packageName")
                        if (filePath.isNullOrBlank() || packageName.isNullOrBlank()) {
                            result.error("invalid_args", "filePath/packageName required", null)
                            return@setMethodCallHandler
                        }
                        try {
                            shareToPackage(filePath, packageName)
                            result.success(null)
                        } catch (e: ActivityNotFoundException) {
                            result.error("app_not_found", e.message, null)
                        } catch (e: Exception) {
                            result.error("share_failed", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun shareToPackage(filePath: String, packageName: String) {
        val source = File(filePath)
        if (!source.exists()) {
            throw IllegalArgumentException("文件不存在")
        }

        // 拷到 cache，避免外部路径无法被 FileProvider / 目标 App 读取
        val shareDir = File(cacheDir, "share_to_app").apply { mkdirs() }
        val target = File(shareDir, source.name)
        source.copyTo(target, overwrite = true)

        val uri: Uri = FileProvider.getUriForFile(
            this,
            "${applicationContext.packageName}.fileprovider",
            target,
        )

        val mime = mimeTypeFor(source) ?: "image/*"
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = mime
            putExtra(Intent.EXTRA_STREAM, uri)
            setPackage(packageName)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }

        grantUriPermission(
            packageName,
            uri,
            Intent.FLAG_GRANT_READ_URI_PERMISSION,
        )

        startActivity(intent)
    }

    private fun mimeTypeFor(file: File): String? {
        val ext = file.extension.lowercase()
        if (ext.isEmpty()) return null
        return MimeTypeMap.getSingleton().getMimeTypeFromExtension(ext)
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
