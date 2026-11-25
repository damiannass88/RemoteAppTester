package com.damiannass.remoteapptester

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.util.Log
import java.io.File

/**
 * Odbiera wynik sesji PackageInstaller.commit() i przekazuje go do aplikacji.
 *
 * - STATUS_PENDING_USER_ACTION — Android chce potwierdzenia: na wierzchu
 *   pokazujemy okno systemowe od razu, w tle — powiadomienie, które je otwiera.
 * - Odmowa cichej aktualizacji (np. MIUI / HyperOS: INSTALL_FAILED_ABORTED
 *   „Permission denied”) — ponawiamy zwykłą instalacją z oknem potwierdzenia
 *   i zapamiętujemy, że ten telefon cichych aktualizacji nie wspiera.
 */
class InstallResultReceiver : BroadcastReceiver() {
    companion object {
        const val EXTRA_LAUNCH_PACKAGE = "com.damiannass.remoteapptester.LAUNCH_PACKAGE"
        private const val TAG = "InstallResultReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val status = intent.getIntExtra(PackageInstaller.EXTRA_STATUS, PackageInstaller.STATUS_FAILURE)
        val message = intent.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE)
        val path = intent.getStringExtra(PackageInstallerPlugin.EXTRA_PATH)
        val silent = intent.getBooleanExtra(PackageInstallerPlugin.EXTRA_SILENT, false)
        val launchPackage = intent.getStringExtra(EXTRA_LAUNCH_PACKAGE)
        val sessionId = intent.getIntExtra(PackageInstaller.EXTRA_SESSION_ID, 0)

        when (status) {
            PackageInstaller.STATUS_PENDING_USER_ACTION -> {
                @Suppress("DEPRECATION")
                val confirmIntent = intent.getParcelableExtra<Intent>(Intent.EXTRA_INTENT) ?: return
                PackageInstallerPlugin.report(path, "pending")
                if (PackageInstallerPlugin.visibleRecently()) {
                    confirmIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    context.startActivity(confirmIntent)
                } else {
                    PackageInstallerPlugin.notify(
                        context, sessionId, "Nowa wersja gotowa",
                        "Dotknij, aby zainstalować.", confirmIntent,
                    )
                }
            }
            PackageInstaller.STATUS_SUCCESS -> {
                Log.i(TAG, "Instalacja zakończona sukcesem.")
                PackageInstallerPlugin.report(path, "success")
                // Uruchamiamy tylko pakiet, który właśnie zainstalowaliśmy i o który
                // prosił użytkownik — nazwa porównana z tą zgłoszoną przez system.
                val installed = intent.getStringExtra(PackageInstaller.EXTRA_PACKAGE_NAME)
                if (launchPackage != null && (installed == null || launchPackage == installed)) {
                    launchWhenReady(context.applicationContext, launchPackage, sessionId, attempt = 0)
                }
            }
            PackageInstaller.STATUS_FAILURE_ABORTED -> {
                if (silent && path != null && File(path).exists()) {
                    Log.w(TAG, "Cicha aktualizacja odrzucona ($message) — ponawiam z potwierdzeniem.")
                    PackageInstallerPlugin.markSilentBlocked(context)
                    try {
                        PackageInstallerPlugin.install(context, File(path), launchPackage, silent = false)
                    } catch (e: Exception) {
                        PackageInstallerPlugin.report(path, "failure", e.message)
                    }
                } else {
                    Log.w(TAG, "Instalacja przerwana: $message")
                    PackageInstallerPlugin.report(path, "failure", message ?: "Instalacja przerwana.")
                }
            }
            else -> {
                Log.w(TAG, "Instalacja nieudana (status=$status): $message")
                PackageInstallerPlugin.report(path, "failure", message ?: "Instalacja nieudana (status $status).")
            }
        }
    }

    /**
     * Tuż po instalacji Android jeszcze podmienia pakiet i nie zna jego ekranu
     * startowego — próbujemy kilka razy co 0,7 s.
     */
    private fun launchWhenReady(context: Context, packageName: String, id: Int, attempt: Int) {
        val launch = context.packageManager.getLaunchIntentForPackage(packageName)
        if (launch == null) {
            if (attempt < 10) {
                android.os.Handler(android.os.Looper.getMainLooper())
                    .postDelayed({ launchWhenReady(context, packageName, id, attempt + 1) }, 700)
            } else {
                Log.w(TAG, "Brak ekranu startowego dla $packageName — nie uruchamiam.")
            }
            return
        }
        if (PackageInstallerPlugin.visibleRecently()) {
            try {
                launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(Intent(launch))
                Log.i(TAG, "Uruchomiono $packageName.")
                // Na wierzchu start na pewno przejdzie; inaczej (np. ekran skanera
                // producenta przykrył RemoteAppTestera) Android może go po cichu
                // zablokować — wtedy zostaje powiadomienie.
                if (PackageInstallerPlugin.foreground) return
            } catch (e: Exception) {
                Log.w(TAG, "Nie udało się uruchomić $packageName: ${e.message}")
            }
        }
        PackageInstallerPlugin.notify(context, id, "Zainstalowano nową wersję", "Dotknij, aby uruchomić.", launch)
    }
}
