package com.socialnova.app

import android.view.WindowManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val channel = "socialnova/privacy"
    private val deviceChannel = "socialnova/device"
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel).setMethodCallHandler { call, result ->
            when (call.method) {
                "setSecure" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: true
                    if (enabled) window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    else window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, deviceChannel).setMethodCallHandler { call, result ->
            when (call.method) {
                "deviceId" -> {
                    val id = Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID)
                    if (id.isNullOrBlank()) result.error("NO_DEVICE_ID", "ANDROID_ID unavailable", null)
                    else result.success(id)
                }
                else -> result.notImplemented()
            }
        }
    }
}
