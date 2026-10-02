package com.socialnova.app

import android.app.DownloadManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.Settings
import android.view.WindowManager
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity: FlutterActivity() {
    private val channel = "socialnova/privacy"
    private val deviceChannel = "socialnova/device"
    private val unityChannel = "socialnova/unity_gifts"
    private val updaterChannel = "socialnova/updater"
    private var updateReceiver: BroadcastReceiver? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel).setMethodCallHandler { call, result ->
            when (call.method) {
                "setSecure" -> { val enabled = call.argument<Boolean>("enabled") ?: true; if (enabled) window.addFlags(WindowManager.LayoutParams.FLAG_SECURE) else window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE); result.success(true) }
                else -> result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, unityChannel).setMethodCallHandler { call, result ->
            when (call.method) { "isAvailable", "show", "hide", "playGift" -> result.success(false); else -> result.notImplemented() }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, deviceChannel).setMethodCallHandler { call, result ->
            when (call.method) { "deviceId" -> { val id = Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID); if (id.isNullOrBlank()) result.error("NO_DEVICE_ID", "ANDROID_ID unavailable", null) else result.success(id) }; else -> result.notImplemented() }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, updaterChannel).setMethodCallHandler { call, result ->
            when (call.method) {
                "downloadAndInstall" -> {
                    val url = call.argument<String>("url")?.trim().orEmpty()
                    val fileName = call.argument<String>("fileName")?.trim().orEmpty().ifEmpty { "SocialNova-update.apk" }
                    if (!url.startsWith("https://")) { result.error("BAD_URL", "HTTPS APK URL required", null); return@setMethodCallHandler }
                    try { downloadAndInstall(url, fileName); result.success(true) } catch (e: Exception) { result.error("UPDATE_FAILED", e.message, null) }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun downloadAndInstall(url: String, fileName: String) {
        val safeName = fileName.replace(Regex("[^A-Za-z0-9._-]"), "_")
        val dm = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
        val request = DownloadManager.Request(Uri.parse(url))
            .setTitle("SocialNova — تحديث التطبيق")
            .setDescription("جارٍ تنزيل التحديث")
            .setMimeType("application/vnd.android.package-archive")
            .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
            .setAllowedOverMetered(true)
            .setAllowedOverRoaming(true)
            .setDestinationInExternalFilesDir(this, Environment.DIRECTORY_DOWNLOADS, safeName)
        val downloadId = dm.enqueue(request)
        updateReceiver?.let { try { unregisterReceiver(it) } catch (_: Exception) {} }
        updateReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                if (intent.getLongExtra(DownloadManager.EXTRA_DOWNLOAD_ID, -1L) != downloadId) return
                try {
                    unregisterReceiver(this)
                } catch (_: Exception) {}
                val file = File(getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS), safeName)
                if (!file.exists()) return
                val uri = FileProvider.getUriForFile(this@MainActivity, "${BuildConfig.APPLICATION_ID}.fileprovider", file)
                val install = Intent(Intent.ACTION_VIEW).apply {
                    setDataAndType(uri, "application/vnd.android.package-archive")
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(install)
            }
        }
        val filter = IntentFilter(DownloadManager.ACTION_DOWNLOAD_COMPLETE)
        if (Build.VERSION.SDK_INT >= 33) registerReceiver(updateReceiver, filter, Context.RECEIVER_NOT_EXPORTED) else registerReceiver(updateReceiver, filter)
    }

    override fun onDestroy() {
        updateReceiver?.let { try { unregisterReceiver(it) } catch (_: Exception) {} }
        updateReceiver = null
        super.onDestroy()
    }
}
