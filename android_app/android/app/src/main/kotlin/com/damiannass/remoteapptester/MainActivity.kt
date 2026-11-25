package com.damiannass.remoteapptester

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity (nie FlutterActivity) — wymóg local_auth na Androidzie:
// BiometricPrompt z androidx.biometric potrzebuje FragmentActivity.
class MainActivity : FlutterFragmentActivity() {
    private val channelName = "com.damiannass.remoteapptester/package_installer"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        channel.setMethodCallHandler(PackageInstallerPlugin(applicationContext))
        PackageInstallerPlugin.channel = channel
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Powiadomienie „Dotknij, aby zainstalować”, gdy dostawa przyjdzie w tle.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1)
        }
    }

    override fun onResume() {
        super.onResume()
        PackageInstallerPlugin.foreground = true
    }

    override fun onPause() {
        PackageInstallerPlugin.foreground = false
        PackageInstallerPlugin.lastPausedAt = System.currentTimeMillis()
        super.onPause()
    }
}
