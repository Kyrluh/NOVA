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

/** Installation always stays in Android's installer, with user confirmation. */
class AppUpdates(private val activity: Activity, private val executor: ExecutorService) {
    @Suppress("DEPRECATION")
    private fun current(): PackageInfo = activity.packageManager.getPackageInfo(activity.packageName, signatureFlags())

    private fun signatureFlags(): Int = if (Build.VERSION.SDK_INT >= 28) PackageManager.GET_SIGNING_CERTIFICATES else PackageManager.GET_SIGNATURES

    @Suppress("DEPRECATION")
    private fun signatures(info: PackageInfo): Set<String> {
        val values = if (Build.VERSION.SDK_INT >= 28) info.signingInfo?.apkContentsSigners else info.signatures
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
                        require(file.path.startsWith(root) && file.name.endsWith(".apk") && file.isFile)
                        @Suppress("DEPRECATION")
                        val archive = activity.packageManager.getPackageArchiveInfo(file.path, signatureFlags()) ?: error("archive")
                        val installed = current()
                        require(archive.packageName == activity.packageName && code(archive) > code(installed))
                        val signer = signatures(installed)
                        require(signer.isNotEmpty() && signatures(archive) == signer)
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
                    } catch (_: Exception) {
                        activity.runOnUiThread { result.error("invalid_update", "Cette APK ne correspond pas à une mise à jour signée de cette application.", null) }
                    }
                }
            }
            else -> result.notImplemented()
        }
    }
}
