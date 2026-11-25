package com.damiannass.remoteapptester

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Instalacja APK bez roota, bez ADB, przez PackageInstaller.Session.
 * Celowo mały i w całości do zaudytowania — bez pakietów instalacyjnych
 * trzecich stron.
 *
 * Wynik każdej instalacji (sukces / czeka na potwierdzenie / błąd) wraca do
 * Darta wywołaniem `installResult` — identyfikatorem jest ścieżka pliku.
 */
class PackageInstallerPlugin(private val context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        const val EXTRA_PATH = "com.damiannass.remoteapptester.APK_PATH"
        const val EXTRA_SILENT = "com.damiannass.remoteapptester.SILENT"
        private const val PREFS = "remotetester_installer"
        private const val KEY_SILENT_BLOCKED = "silent_update_blocked"
        private const val NOTIFICATION_CHANNEL = "installs"

        /** Kanał do Darta (null, gdy silnik Fluttera nie działa). */
        @Volatile var channel: MethodChannel? = null

        /** Czy ekran RemoteAppTestera jest na wierzchu (okno systemowe da się wtedy pokazać). */
        @Volatile var foreground = false
        @Volatile var lastPausedAt = 0L

        /**
         * Na wierzchu albo przed chwilą (okno potwierdzenia instalacji samo
         * przykrywa RemoteAppTestera) — wtedy Android pozwala otworzyć ekran.
         */
        fun visibleRecently() = foreground || System.currentTimeMillis() - lastPausedAt < 15_000

        /**
         * Część producentów (np. MIUI / HyperOS) nie pozwala zwykłym aplikacjom
         * na aktualizacje bez okna potwierdzenia — po pierwszej odmowie
         * zapamiętujemy to i od razu używamy zwykłej instalacji z oknem.
         */
        fun silentBlocked(context: Context) =
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean(KEY_SILENT_BLOCKED, false)

        fun markSilentBlocked(context: Context) =
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putBoolean(KEY_SILENT_BLOCKED, true).apply()

        fun install(context: Context, apkFile: File, launchPackage: String?, silent: Boolean) {
            val packageInstaller = context.packageManager.packageInstaller
            val params = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL)
            // Android 12+: aktualizacja aplikacji, którą wcześniej zainstalował
            // RemoteAppTester, bez okna "Zaktualizować?" (UPDATE_PACKAGES_WITHOUT_USER_ACTION).
            // Pierwsza instalacja i aplikacje z innego źródła nadal pytają.
            if (silent && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                params.setRequireUserAction(PackageInstaller.SessionParams.USER_ACTION_NOT_REQUIRED)
            }
            val sessionId = packageInstaller.createSession(params)
            packageInstaller.openSession(sessionId).use { session ->
                session.openWrite("package", 0, apkFile.length()).use { out ->
                    apkFile.inputStream().use { input -> input.copyTo(out) }
                    session.fsync(out)
                }
                val intent = Intent(context, InstallResultReceiver::class.java)
                    .putExtra(EXTRA_PATH, apkFile.path)
                    .putExtra(EXTRA_SILENT, silent)
                if (launchPackage != null) intent.putExtra(InstallResultReceiver.EXTRA_LAUNCH_PACKAGE, launchPackage)
                val flags = PendingIntent.FLAG_UPDATE_CURRENT or
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_MUTABLE else 0
                val pendingIntent = PendingIntent.getBroadcast(context, sessionId, intent, flags)
                session.commit(pendingIntent.intentSender)
            }
        }

        /** Przekazuje wynik do Darta (wątek główny). */
        fun report(path: String?, status: String, message: String? = null) {
            if (path == null) return
            Handler(Looper.getMainLooper()).post {
                channel?.invokeMethod("installResult", mapOf("path" to path, "status" to status, "message" to message))
            }
        }

        /**
         * Gdy aplikacja jest w tle, Android nie pozwala otworzyć okna — zamiast
         * tego powiadomienie, które po dotknięciu otwiera [target].
         */
        fun notify(context: Context, id: Int, title: String, text: String, target: Intent) {
            val manager = context.getSystemService(NotificationManager::class.java) ?: return
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                manager.createNotificationChannel(
                    NotificationChannel(NOTIFICATION_CHANNEL, "Instalacje z komputera", NotificationManager.IMPORTANCE_HIGH),
                )
            }
            target.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            val pending = PendingIntent.getActivity(
                context, id, target, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            @Suppress("DEPRECATION")
            val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                android.app.Notification.Builder(context, NOTIFICATION_CHANNEL)
            } else {
                android.app.Notification.Builder(context)
            }
            val notification = builder
                .setSmallIcon(android.R.drawable.stat_sys_download_done)
                .setContentTitle(title)
                .setContentText(text)
                .setContentIntent(pending)
                .setAutoCancel(true)
                .build()
            try {
                manager.notify(id, notification)
            } catch (e: SecurityException) {
                // Brak zgody na powiadomienia — wynik i tak widać w aplikacji.
            }
        }
    }

    private fun playNotes(notes: List<List<Number>>) {
        try {
            val rate = 22050
            val samples = ArrayList<Short>()
            for (note in notes) {
                val freq = note[0].toDouble()
                val n = rate * note[1].toInt() / 1000
                val fade = minOf(n / 4, rate / 200).coerceAtLeast(1)
                for (i in 0 until n) {
                    val envelope = minOf(1.0, minOf(i, n - 1 - i).toDouble() / fade)
                    val v = if (freq == 0.0) 0.0 else Math.sin(2 * Math.PI * freq * i / rate) * 0.35 * envelope
                    samples.add((v * 32767).toInt().toShort())
                }
            }
            if (samples.isEmpty()) return
            val pcm = samples.toShortArray()
            val track = AudioTrack.Builder()
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_NOTIFICATION_EVENT)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
                .setAudioFormat(
                    AudioFormat.Builder()
                        .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                        .setSampleRate(rate)
                        .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                        .build()
                )
                .setTransferMode(AudioTrack.MODE_STATIC)
                .setBufferSizeInBytes(pcm.size * 2)
                .build()
            track.write(pcm, 0, pcm.size)
            track.play()
            Thread.sleep(pcm.size * 1000L / rate + 150)
            track.release()
        } catch (e: Exception) {
            // Dźwięk to dodatek — brak nie może przeszkadzać w instalacji.
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "readPackageName" -> {
                val path = call.argument<String>("path")
                if (path == null) {
                    result.error("bad_args", "Brak argumentu 'path'.", null)
                    return
                }
                try {
                    val info = context.packageManager.getPackageArchiveInfo(path, 0)
                    result.success(info?.packageName)
                } catch (e: Exception) {
                    result.error("read_failed", e.message, null)
                }
            }
            "installApk" -> {
                val path = call.argument<String>("path")
                if (path == null) {
                    result.error("bad_args", "Brak argumentu 'path'.", null)
                    return
                }
                try {
                    install(context, File(path), call.argument<String>("launchPackage"), silent = !silentBlocked(context))
                    result.success(null)
                } catch (e: Exception) {
                    result.error("install_failed", e.message, null)
                }
            }
            "launchApp" -> {
                // Android 11+ pokazuje nam tylko pakiety, które sami zainstalowaliśmy.
                val packageName = call.argument<String>("packageName")
                if (packageName == null) {
                    result.error("bad_args", "Brak argumentu 'packageName'.", null)
                    return
                }
                result.success(launchApp(context, packageName))
            }
            "playNotes" -> {
                // Krótkie tony (częstotliwość Hz, czas ms) — te same co w oknie Windows.
                val notes = call.argument<List<List<Number>>>("notes") ?: emptyList()
                Thread { playNotes(notes) }.start()
                result.success(null)
            }
            "notifyIfInBackground" -> {
                if (!foreground) {
                    val open = context.packageManager.getLaunchIntentForPackage(context.packageName)
                    if (open != null) {
                        notify(
                            context,
                            (System.currentTimeMillis() and 0xFFFFFF).toInt(),
                            call.argument<String>("title") ?: "RemoteAppTester",
                            call.argument<String>("text") ?: "",
                            open,
                        )
                    }
                }
                result.success(null)
            }
            "canRequestPackageInstalls" -> {
                result.success(context.packageManager.canRequestPackageInstalls())
            }
            "openBiometricEnroll" -> {
                openBiometricEnroll(context)
                result.success(null)
            }
            "openInstallPermissionSettings" -> {
                val intent = Intent(
                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                    Uri.parse("package:${context.packageName}"),
                ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(intent)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }
}

/**
 * Ekran dodawania odcisku palca (blokada aplikacji, security/app_lock.dart).
 * Android 11+: systemowy kreator (sam poprosi o PIN, jeśli go nie ma);
 * Android 9–10: ekran odcisku; nakładki bez tych ekranów — ustawienia
 * zabezpieczeń, a w ostateczności główne ustawienia.
 */
fun openBiometricEnroll(context: Context) {
    val candidates = mutableListOf<Intent>()
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
        candidates += Intent(Settings.ACTION_BIOMETRIC_ENROLL).putExtra(
            Settings.EXTRA_BIOMETRIC_AUTHENTICATORS_ALLOWED,
            android.hardware.biometrics.BiometricManager.Authenticators.BIOMETRIC_WEAK or
                android.hardware.biometrics.BiometricManager.Authenticators.DEVICE_CREDENTIAL,
        )
    }
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
        @Suppress("DEPRECATION")
        candidates += Intent(Settings.ACTION_FINGERPRINT_ENROLL)
    }
    candidates += Intent(Settings.ACTION_SECURITY_SETTINGS)
    candidates += Intent(Settings.ACTION_SETTINGS)
    for (intent in candidates) {
        try {
            context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            return
        } catch (e: android.content.ActivityNotFoundException) {
            // następna możliwość
        } catch (e: SecurityException) {
            // następna możliwość
        }
    }
}

/** Zwraca false, gdy pakietu nie ma albo nie ma ekranu startowego. */
fun launchApp(context: Context, packageName: String): Boolean {
    val launch = context.packageManager.getLaunchIntentForPackage(packageName) ?: return false
    launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    context.startActivity(launch)
    return true
}
