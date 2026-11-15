package app.nova.iptv

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest
import java.util.concurrent.ExecutorService

class NovaUpdateFileProvider : FileProvider()
private class UpdateValidationException(message: String) : Exception(message)
private inline fun checkUpdate(condition: Boolean, message: () -> String) {
    if (!condition) throw UpdateValidationException(message())
}

/** Installation always stays in Android's installer, with user confirmation. */
class AppUpdates(private val activity: Activity, private val executor: ExecutorService) {
    @Suppress("DEPRECATION")
    private fun current(): PackageInfo {
        val manager = activity.packageManager
        val info = manager.getPackageInfo(activity.packageName, signatureFlags())
        return if (signatures(info).isNotEmpty()) info
            else manager.getPackageInfo(activity.packageName, PackageManager.GET_SIGNATURES)
    }

    private fun signatureFlags(): Int = PackageManager.GET_SIGNATURES or
        (if (Build.VERSION.SDK_INT >= 28) PackageManager.GET_SIGNING_CERTIFICATES else 0)

    @Suppress("DEPRECATION")
    private fun signatures(info: PackageInfo): Set<String> {
        val modern = if (Build.VERSION.SDK_INT >= 28) info.signingInfo?.apkContentsSigners else null
        val values = modern?.takeIf { it.isNotEmpty() } ?: info.signatures
        return values?.map { signature ->
            MessageDigest.getInstance("SHA-256").digest(signature.toByteArray()).joinToString("") { "%02x".format(it) }
        }?.toSet() ?: emptySet()
    }

    @Suppress("DEPRECATION")
    private fun code(info: PackageInfo): Long = if (Build.VERSION.SDK_INT >= 28) info.longVersionCode else info.versionCode.toLong()

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getUpdateInfo" -> {
                val info = current()
                result.success(mapOf("platform" to "android", "version" to (info.versionName ?: ""),
                    "build" to code(info), "television" to activity.packageName.startsWith("app.nova.iptv.tv"),
                    "abis" to Build.SUPPORTED_ABIS.toList(), "debug" to activity.packageName.endsWith(".debug")))
            }
            "openUpdateSettings" -> {
                try {
                    if (Build.VERSION.SDK_INT >= 26) {
                        activity.startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:${activity.packageName}")))
                    } else {
                        activity.startActivity(Intent(Settings.ACTION_SECURITY_SETTINGS))
                    }
                    result.success(null)
                } catch (_: Exception) {
                    try { activity.startActivity(Intent(Settings.ACTION_SECURITY_SETTINGS)); result.success(null) }
                    catch (_: Exception) {
                        try { activity.startActivity(Intent(Settings.ACTION_SETTINGS)); result.success(null) }
                        catch (_: Exception) { result.error("settings_unavailable", "Dans les paramètres Android / Fire TV, autorisez NOVA à installer des applications inconnues, puis revenez ici.", null) }
                    }
                }
            }
            "installUpdate" -> {
                val path = call.arguments as? String
                if (path == null) { result.error("invalid_apk", "Fichier APK absent.", null); return }
                executor.execute {
                    try {
                        val file = File(path).canonicalFile
                        val root = File(activity.cacheDir, "updates").canonicalPath + File.separator
                        checkUpdate(file.path.startsWith(root) && file.name.endsWith(".apk") && file.isFile) {
                            "Le fichier de mise à jour est absent ou inaccessible. Téléchargez-le à nouveau."
                        }
                        @Suppress("DEPRECATION")
                        val modernArchive = activity.packageManager.getPackageArchiveInfo(file.path, signatureFlags())
                        val archive = modernArchive?.takeIf { signatures(it).isNotEmpty() }
                            ?: activity.packageManager.getPackageArchiveInfo(file.path, PackageManager.GET_SIGNATURES)
                            ?: throw UpdateValidationException("Cette APK est illisible sur cet appareil. Téléchargez-la à nouveau.")
                        val installed = current()
                        checkUpdate(archive.packageName == activity.packageName) {
                            "Cette APK correspond à une autre édition de NOVA. Utilisez l’édition TV sur votre Fire Stick."
                        }
                        checkUpdate(code(archive) > code(installed)) {
                            "Cette version est déjà installée ou plus ancienne que votre application."
                        }
                        val signer = signatures(installed)
                        checkUpdate(signer.isNotEmpty() && signatures(archive).isNotEmpty()) {
                            "Impossible de lire les certificats de signature sur cet appareil. Essayez l’installateur Android avec l’APK officielle."
                        }
                        checkUpdate(signatures(archive) == signer) {
                            "La signature de cette APK diffère de celle de l’application installée. Installation bloquée."
                        }
                        activity.runOnUiThread {
                            if (activity.isFinishing || activity.isDestroyed) return@runOnUiThread
                            try {
                                if (Build.VERSION.SDK_INT >= 26 && !activity.packageManager.canRequestPackageInstalls()) {
                                    result.success("permission")
                                } else {
                                    val uri = FileProvider.getUriForFile(activity, "${activity.packageName}.updates", file)
                                    activity.startActivity(Intent(Intent.ACTION_VIEW).apply {
                                        setDataAndType(uri, "application/vnd.android.package-archive")
                                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                        clipData = android.content.ClipData.newRawUri("NOVA update", uri)
                                    })
                                    result.success("installer")
                                }
                            } catch (_: Exception) { result.error("installer_unavailable", "L’installateur Android est indisponible sur cet appareil.", null) }
                        }
                    } catch (error: Exception) {
                        // Only controlled validation messages are shown; no paths or platform diagnostics.
                        val message = if (error is UpdateValidationException) error.message
                            else null
                        activity.runOnUiThread { result.error("invalid_update", message ?: "La vérification de la mise à jour a échoué sur cet appareil. Essayez l’APK officielle avec l’installateur Android.", null) }
                    }
                }
            }
            else -> result.notImplemented()
        }
    }
}
