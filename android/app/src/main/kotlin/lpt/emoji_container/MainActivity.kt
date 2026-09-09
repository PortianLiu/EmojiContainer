package lpt.emoji_container

import android.content.ActivityNotFoundException
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.Settings
import android.webkit.MimeTypeMap
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
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
                        val target = call.argument<String>("target")
                        if (filePath.isNullOrBlank() || packageName.isNullOrBlank()) {
                            result.error("invalid_args", "filePath/packageName required", null)
                            return@setMethodCallHandler
                        }
                        try {
                            shareToFriends(filePath, packageName, target)
                            result.success(null)
                        } catch (e: ActivityNotFoundException) {
                            result.error("app_not_found", e.message, null)
                        } catch (e: Exception) {
                            result.error("share_failed", e.message, null)
                        }
                    }
                    "getAppIcon" -> {
                        val packageName = call.argument<String>("packageName")
                        if (packageName.isNullOrBlank()) {
                            result.error("invalid_args", "packageName required", null)
                            return@setMethodCallHandler
                        }
                        try {
                            result.success(appIconPng(packageName))
                        } catch (e: Exception) {
                            result.error("icon_not_found", e.message, null)
                        }
                    }
                    "listImageShareTargets" -> {
                        try {
                            result.success(listImageShareTargets())
                        } catch (e: Exception) {
                            result.error("list_failed", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // 定向分享给好友会话，避免拉起含朋友圈/状态/收藏等的完整面板。
    // 微信: ShareImgUI；QQ: JumpActivity。
    private fun shareToFriends(filePath: String, packageName: String, target: String?) {
        val source = File(filePath)
        if (!source.exists()) {
            throw IllegalArgumentException("文件不存在")
        }

        val shareDir = File(cacheDir, "share_to_app").apply { mkdirs() }
        val targetFile = File(shareDir, source.name)
        source.copyTo(targetFile, overwrite = true)

        val uri: Uri = FileProvider.getUriForFile(
            this,
            "${applicationContext.packageName}.fileprovider",
            targetFile,
        )

        val mime = mimeTypeFor(source) ?: "image/*"
        grantUriPermission(
            packageName,
            uri,
            Intent.FLAG_GRANT_READ_URI_PERMISSION,
        )

        val classNames = friendShareClassNames(packageName, target)
        var lastError: Exception? = null
        for (className in classNames) {
            val intent = Intent(Intent.ACTION_SEND).apply {
                type = mime
                putExtra(Intent.EXTRA_STREAM, uri)
                component = ComponentName(packageName, className)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            if (intent.resolveActivity(packageManager) == null) {
                lastError = ActivityNotFoundException(className)
                continue
            }
            try {
                startActivity(intent)
                return
            } catch (e: ActivityNotFoundException) {
                lastError = e
            } catch (e: Exception) {
                lastError = e
            }
        }

        // 自定义通道或未知 App：按包名拉起该应用的图片分享入口
        val activity = target?.takeIf {
            it.isNotBlank() &&
                it != "wechat_friends" &&
                it != "qq_friends" &&
                it.contains('.')
        }
        val fallback = Intent(Intent.ACTION_SEND).apply {
            type = mime
            putExtra(Intent.EXTRA_STREAM, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            if (activity != null) {
                component = ComponentName(packageName, activity)
            } else {
                setPackage(packageName)
            }
        }
        if (fallback.resolveActivity(packageManager) == null) {
            throw lastError ?: ActivityNotFoundException("无法打开分享目标")
        }
        startActivity(fallback)
    }

    // 可接收图片分享的已安装应用（用于用户扩展通道）。
    private fun listImageShareTargets(): List<Map<String, String>> {
        val intent = Intent(Intent.ACTION_SEND).apply { type = "image/*" }
        @Suppress("DEPRECATION")
        val resolves = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.queryIntentActivities(
                intent,
                PackageManager.ResolveInfoFlags.of(
                    PackageManager.MATCH_DEFAULT_ONLY.toLong(),
                ),
            )
        } else {
            packageManager.queryIntentActivities(intent, PackageManager.MATCH_DEFAULT_ONLY)
        }

        val self = applicationContext.packageName
        val seen = LinkedHashSet<String>()
        val out = ArrayList<Map<String, String>>()
        for (info in resolves) {
            val pkg = info.activityInfo?.packageName ?: continue
            if (pkg == self) continue
            if (!seen.add(pkg)) continue
            val label = info.loadLabel(packageManager)?.toString()?.trim().orEmpty()
            val activity = info.activityInfo?.name.orEmpty()
            out.add(
                mapOf(
                    "packageName" to pkg,
                    "label" to label.ifEmpty { pkg },
                    "activity" to activity,
                ),
            )
        }
        out.sortBy { it["label"]?.lowercase() ?: it["packageName"]!! }
        return out
    }

    private fun friendShareClassNames(packageName: String, target: String?): List<String> {
        return when {
            packageName == "com.tencent.mm" || target == "wechat_friends" -> listOf(
                "com.tencent.mm.ui.tools.ShareImgUI",
            )
            packageName == "com.tencent.mobileqq" || target == "qq_friends" -> listOf(
                "com.tencent.mobileqq.activity.JumpActivity",
                "com.tencent.mobileqq.activity.qfileJumpActivity",
            )
            else -> emptyList()
        }
    }

    private fun mimeTypeFor(file: File): String? {
        val ext = file.extension.lowercase()
        if (ext.isEmpty()) return null
        return MimeTypeMap.getSingleton().getMimeTypeFromExtension(ext)
    }

    // 读取已安装应用图标，返回 PNG 字节（无需内置资源）。
    private fun appIconPng(packageName: String): ByteArray {
        val drawable = packageManager.getApplicationIcon(packageName)
        val bitmap = drawableToBitmap(drawable)
        return ByteArrayOutputStream().use { out ->
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
            out.toByteArray()
        }
    }

    private fun drawableToBitmap(drawable: Drawable): Bitmap {
        if (drawable is BitmapDrawable && drawable.bitmap != null) {
            return drawable.bitmap
        }
        val width = drawable.intrinsicWidth.takeIf { it > 0 } ?: 192
        val height = drawable.intrinsicHeight.takeIf { it > 0 } ?: 192
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        drawable.setBounds(0, 0, canvas.width, canvas.height)
        drawable.draw(canvas)
        return bitmap
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
