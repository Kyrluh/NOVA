package app.nova.iptv

import android.app.PictureInPictureParams
import android.app.PictureInPictureUiState
import android.app.AlertDialog
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ActivityInfo
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Rational
import android.view.View
import android.view.KeyEvent
import android.view.WindowInsets
import android.view.WindowInsetsController
import android.view.WindowManager
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputMethodManager
import android.text.InputFilter
import android.text.InputType
import android.widget.EditText
import android.widget.LinearLayout
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.security.KeyStore
import java.util.UUID
import java.util.concurrent.Executors
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** Window and crypto operations only. Dart owns the one media session. */
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private val cryptoExecutor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private val instanceId = UUID.randomUUID().toString()
    private var configurationChanges = 0
    private var pipEnabled = false
    private var fullscreen = false
    private var fullscreenLandscape = true
    private var destroyed = false
    private var playbackActive = false
    private var noisyRegistered = false
    private var focusRequest: AudioFocusRequest? = null
    private var exportResult: MethodChannel.Result? = null
    private var sourceEditor: AlertDialog? = null
    private var sourceEditorResult: MethodChannel.Result? = null
    private var sourceEditorField: EditText? = null
    private var exportText: String? = null
    private val audioManager by lazy { getSystemService(Context.AUDIO_SERVICE) as AudioManager }
    private val focusListener = AudioManager.OnAudioFocusChangeListener { change ->
        if (change == AudioManager.AUDIOFOCUS_LOSS || change == AudioManager.AUDIOFOCUS_LOSS_TRANSIENT) {
            mainHandler.post { channel?.invokeMethod("audioFocusPause", null) }
        }
    }
    private val noisyReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == AudioManager.ACTION_AUDIO_BECOMING_NOISY) {
                channel?.invokeMethod("audioFocusPause", null)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "nova/android")
        channel?.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "editSourceText" -> editSourceText(call, result)
                    "protect", "unprotect" -> crypto(call, result)
                    "getBrightness" -> {
                        val value = window.attributes.screenBrightness
                        result.success(if (value >= 0) value.toDouble() else Settings.System.getInt(contentResolver, Settings.System.SCREEN_BRIGHTNESS, 128) / 255.0)
                    }
                    "setBrightness" -> {
                        val value = (call.arguments as Number).toFloat().coerceIn(-1f, 1f)
                        window.attributes = window.attributes.apply { screenBrightness = value }
                        result.success(null)
                    }
                    "getVolume" -> result.success(volume())
                    "setVolume" -> {
                        val maximum = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                        val value = (call.arguments as Number).toDouble().coerceIn(0.0, 100.0)
                        audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, (maximum * value / 100).toInt(), 0)
                        result.success(null)
                    }
                    "setKeepScreenOn" -> {
                        if (call.arguments == true) window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        else window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        result.success(null)
                    }
                    "setFullscreen" -> {
                        val args = call.arguments
                        val enabled = if (args is Map<*, *>) args["enabled"] == true else args == true
                        val landscape = if (args is Map<*, *>) args["landscape"] != false else true
                        setFullscreen(enabled, landscape)
                        result.success(null)
                    }
                    "getPipSupported" -> result.success(pipSupported())
                    "isEmulator" -> result.success(isEmulator())
                    "setPipEnabled" -> {
                        pipEnabled = call.arguments == true
                        updatePipParams()
                        result.success(null)
                    }
                    "enterPip" -> result.success(enterPip())
                    "setPlaybackActive" -> {
                        setPlaybackActive(call.arguments == true)
                        result.success(null)
                    }
                    "exportDocument" -> {
                        if (exportResult != null) {
                            result.error("document_busy", "Un export est déjà ouvert.", null)
                        } else {
                            val args = call.arguments as Map<*, *>
                            val text = args["text"] as String
                            require(text.length < 2 * 1024 * 1024)
                            val name = (args["name"] as? String ?: "nova-settings.json").take(100).replace(Regex("[/\\\\]"), "_")
                            exportResult = result
                            exportText = text
                            @Suppress("DEPRECATION")
                            startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE)
                                type = "application/json"
                                putExtra(Intent.EXTRA_TITLE, name)
                            }, 910)
                        }
                    }
                    "getDiagnostics" -> {
                        val location = IntArray(2)
                        window.decorView.getLocationOnScreen(location)
                        result.success(mapOf(
                        "activityInstance" to instanceId,
                        "configurationChanges" to configurationChanges,
                        "widthDp" to resources.configuration.screenWidthDp,
                        "heightDp" to resources.configuration.screenHeightDp,
                        "multiWindow" to inMultiWindow(),
                        "inPip" to (Build.VERSION.SDK_INT >= 26 && isInPictureInPictureMode),
                        "keepScreenOn" to ((window.attributes.flags and WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON) != 0),
                        "windowXPx" to location[0], "windowYPx" to location[1],
                        "windowWidthPx" to window.decorView.width, "windowHeightPx" to window.decorView.height,
                        "isEmulator" to isEmulator()
                        ))
                    }
                    else -> result.notImplemented()
                }
            } catch (_: Exception) {
                // Never return raw native errors, tokens or media locations.
                result.error("android_operation_failed", "Cette opération Android est indisponible.", null)
            }
        }
    }

    private fun editSourceText(call: MethodCall, result: MethodChannel.Result) {
        if (sourceEditorResult != null) {
            result.error("source_editor_busy", "Un champ est déjà en cours de saisie.", null)
            return
        }
        val args = call.arguments as Map<*, *>
        val initial = args["value"] as? String ?: ""
        val isUrl = args["url"] == true
        val secret = args["secret"] == true
        val search = args["search"] == true
        val limit = (args["maxLength"] as? Number)?.toInt()?.coerceIn(1, 16384) ?: 4096
        val editor = object : EditText(this) {
            override fun onKeyPreIme(keyCode: Int, event: KeyEvent): Boolean {
                if (search && keyCode == KeyEvent.KEYCODE_BACK) {
                    if (event.action == KeyEvent.ACTION_UP) finishSourceEditor(text.toString())
                    return true
                }
                return super.onKeyPreIme(keyCode, event)
            }
        }.apply {
            inputType = InputType.TYPE_CLASS_TEXT or when {
                secret -> InputType.TYPE_TEXT_VARIATION_PASSWORD
                isUrl -> InputType.TYPE_TEXT_VARIATION_URI
                else -> InputType.TYPE_TEXT_FLAG_NO_SUGGESTIONS
            }
            setSingleLine(true)
            setHorizontallyScrolling(true)
            filters = arrayOf(InputFilter.LengthFilter(limit.coerceAtLeast(initial.length)))
            imeOptions = EditorInfo.IME_ACTION_DONE or EditorInfo.IME_FLAG_NO_EXTRACT_UI
            setText(initial)
            setSelection(text.length)
            setSelectAllOnFocus(false)
            contentDescription = args["title"] as? String ?: "Modifier le champ"
        }
        val padding = (24 * resources.displayMetrics.density).toInt()
        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(padding, padding / 2, padding, padding / 2)
            addView(editor, LinearLayout.LayoutParams(-1, -2))
        }
        val dialog = AlertDialog.Builder(this, android.R.style.Theme_Material_Dialog_Alert)
            .setTitle(args["title"] as? String ?: "Modifier le champ")
            .setView(content)
            .setPositiveButton("Valider") { _, _ -> finishSourceEditor(editor.text.toString()) }
            .setNegativeButton("Annuler") { _, _ -> finishSourceEditor(null) }
            .create()
        sourceEditor = dialog
        sourceEditorField = editor
        sourceEditorResult = result
        editor.setOnEditorActionListener { _, action, event ->
            if (action == EditorInfo.IME_ACTION_DONE ||
                (event?.keyCode == KeyEvent.KEYCODE_ENTER && event.action == KeyEvent.ACTION_UP)) {
                finishSourceEditor(editor.text.toString())
                true
            } else false
        }
        dialog.setCanceledOnTouchOutside(false)
        dialog.setOnCancelListener { finishSourceEditor(if (search) editor.text.toString() else null) }
        dialog.setOnDismissListener { finishSourceEditor(null) }
        try {
            dialog.show()
            dialog.window?.setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_STATE_ALWAYS_VISIBLE or WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE)
            editor.requestFocus()
            editor.post {
                if (sourceEditor === dialog && !destroyed) {
                    (getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager)
                        .showSoftInput(editor, InputMethodManager.SHOW_IMPLICIT)
                }
            }
        } catch (_: Exception) {
            finishSourceEditor(null)
        }
    }

    private fun finishSourceEditor(value: String?) {
        val result = sourceEditorResult ?: return
        val dialog = sourceEditor
        val editor = sourceEditorField
        sourceEditorResult = null
        sourceEditor = null
        sourceEditorField = null
        if (editor != null) {
            (getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager)
                .hideSoftInputFromWindow(editor.windowToken, 0)
        }
        dialog?.dismiss()
        result.success(value)
    }

    private fun volume(): Double {
        val maximum = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC).coerceAtLeast(1)
        return audioManager.getStreamVolume(AudioManager.STREAM_MUSIC) * 100.0 / maximum
    }

    @Deprecated("Activity result bridge for the Flutter channel")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != 910) { super.onActivityResult(requestCode, resultCode, data); return }
        val result = exportResult
        val text = exportText
        exportResult = null
        exportText = null
        val uri = data?.data
        if (resultCode != RESULT_OK || uri == null || text == null) { result?.success(false); return }
        cryptoExecutor.execute {
            try {
                contentResolver.openOutputStream(uri, "wt")?.use { it.write(text.toByteArray(Charsets.UTF_8)) }
                    ?: throw IllegalStateException()
                mainHandler.post { result?.success(true) }
            } catch (_: Exception) {
                mainHandler.post { result?.error("export_failed", "L’export n’a pas pu être enregistré.", null) }
            }
        }
    }

    private fun setFullscreen(enabled: Boolean, landscape: Boolean) {
        fullscreen = enabled
        fullscreenLandscape = landscape
        applyOrientationPolicy(resources.configuration)
        if (Build.VERSION.SDK_INT >= 30) {
            window.insetsController?.apply {
                systemBarsBehavior = WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
                if (enabled) hide(WindowInsets.Type.systemBars()) else show(WindowInsets.Type.systemBars())
            }
        } else {
            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility = if (enabled)
                View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY or View.SYSTEM_UI_FLAG_FULLSCREEN or
                View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or View.SYSTEM_UI_FLAG_LAYOUT_STABLE or
                View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                else View.SYSTEM_UI_FLAG_LAYOUT_STABLE
        }
    }

    private fun applyOrientationPolicy(config: Configuration) {
        val wanted = if (fullscreen && fullscreenLandscape && !inMultiWindow() && config.smallestScreenWidthDp < 600)
            ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE else ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
        if (requestedOrientation != wanted) requestedOrientation = wanted
    }

    private fun pipSupported() = Build.VERSION.SDK_INT >= 26 &&
        packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)
    private fun isEmulator() = Build.FINGERPRINT.startsWith("generic") ||
        Build.MODEL.contains("sdk_gphone") || Build.MODEL.contains("Emulator") ||
        Build.HARDWARE == "ranchu" || Build.HARDWARE == "goldfish"
    private fun inMultiWindow() = Build.VERSION.SDK_INT >= 24 && isInMultiWindowMode
    private fun pipParams(): PictureInPictureParams {
        val builder = PictureInPictureParams.Builder().setAspectRatio(Rational(16, 9))
        if (Build.VERSION.SDK_INT >= 31) builder.setAutoEnterEnabled(pipEnabled && playbackActive).setSeamlessResizeEnabled(true)
        return builder.build()
    }
    private fun updatePipParams() {
        if (!destroyed && pipSupported()) setPictureInPictureParams(pipParams())
    }
    private fun enterPip(): Boolean {
        if (!pipSupported() || !pipEnabled || !playbackActive) return false
        channel?.invokeMethod("pipChanged", true)
        val entered = try { enterPictureInPictureMode(pipParams()) } catch (_: Exception) { false }
        if (!entered) channel?.invokeMethod("pipChanged", false)
        return entered
    }
    override fun onUserLeaveHint() {
        if (Build.VERSION.SDK_INT < 31 && pipEnabled && playbackActive) enterPip()
        super.onUserLeaveHint()
    }
    override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean, newConfig: Configuration) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        channel?.invokeMethod("pipChanged", isInPictureInPictureMode)
        if (isInPictureInPictureMode) window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }
    override fun onPictureInPictureUiStateChanged(pipState: PictureInPictureUiState) {
        super.onPictureInPictureUiStateChanged(pipState)
        if (Build.VERSION.SDK_INT >= 35 && pipState.isTransitioningToPip) channel?.invokeMethod("pipChanged", true)
    }
    override fun onResume() {
        super.onResume()
        // Reconcile an early PiP transition notification if Android cancels it.
        channel?.invokeMethod("pipChanged", Build.VERSION.SDK_INT >= 26 && isInPictureInPictureMode)
        channel?.invokeMethod("volumeChanged", volume())
    }
    override fun onKeyUp(keyCode: Int, event: KeyEvent): Boolean {
        val handled = super.onKeyUp(keyCode, event)
        if (keyCode == KeyEvent.KEYCODE_VOLUME_UP || keyCode == KeyEvent.KEYCODE_VOLUME_DOWN || keyCode == KeyEvent.KEYCODE_VOLUME_MUTE) {
            mainHandler.post { channel?.invokeMethod("volumeChanged", volume()) }
        }
        return handled
    }
    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        configurationChanges++
        applyOrientationPolicy(newConfig)
        // Flutter receives Jetpack WindowManager display features and dimensions.
        // No engine or media instance is created in this callback.
    }
    override fun onMultiWindowModeChanged(isInMultiWindowMode: Boolean, newConfig: Configuration) {
        super.onMultiWindowModeChanged(isInMultiWindowMode, newConfig)
        applyOrientationPolicy(newConfig)
    }

    private fun setPlaybackActive(active: Boolean) {
        if (active == playbackActive) return
        playbackActive = active
        if (active) {
            if (Build.VERSION.SDK_INT >= 26) {
                val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                    .setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MOVIE).build())
                    .setOnAudioFocusChangeListener(focusListener).build()
                focusRequest = request
                if (audioManager.requestAudioFocus(request) != AudioManager.AUDIOFOCUS_REQUEST_GRANTED) {
                    channel?.invokeMethod("audioFocusPause", null)
                }
            } else {
                @Suppress("DEPRECATION")
                audioManager.requestAudioFocus(focusListener, AudioManager.STREAM_MUSIC, AudioManager.AUDIOFOCUS_GAIN)
            }
            if (!noisyRegistered) {
                val filter = IntentFilter(AudioManager.ACTION_AUDIO_BECOMING_NOISY)
                if (Build.VERSION.SDK_INT >= 33) registerReceiver(noisyReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
                else registerReceiver(noisyReceiver, filter)
                noisyRegistered = true
            }
        } else {
            if (Build.VERSION.SDK_INT >= 26) focusRequest?.let { audioManager.abandonAudioFocusRequest(it) }
            else {
                @Suppress("DEPRECATION")
                audioManager.abandonAudioFocus(focusListener)
            }
            focusRequest = null
            if (noisyRegistered) { unregisterReceiver(noisyReceiver); noisyRegistered = false }
            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }
        updatePipParams()
    }

    private fun secretKey(): SecretKey {
        val alias = "nova.iptv.catalog.aes.v1"
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (store.getKey(alias, null) as? SecretKey)?.let { return it }
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").apply {
            init(KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setRandomizedEncryptionRequired(true).setKeySize(256).build())
        }.generateKey()
    }
    private fun crypto(call: MethodCall, result: MethodChannel.Result) {
        cryptoExecutor.execute {
            try {
                val cipher = Cipher.getInstance("AES/GCM/NoPadding")
                val transformed: Any = if (call.method == "protect") {
                    val text = call.arguments as String
                    require(text.length <= 2 * 1024 * 1024)
                    val plain = text.toByteArray(Charsets.UTF_8)
                    try {
                        cipher.init(Cipher.ENCRYPT_MODE, secretKey())
                        byteArrayOf(1, cipher.iv.size.toByte()) + cipher.iv + cipher.doFinal(plain)
                    } finally { plain.fill(0) }
                } else {
                    val encoded = call.arguments as ByteArray
                    require(encoded.size in 30..(8 * 1024 * 1024) && encoded[0] == 1.toByte())
                    val length = encoded[1].toInt() and 255
                    require(length == 12 && encoded.size >= 2 + length + 16)
                    cipher.init(Cipher.DECRYPT_MODE, secretKey(), GCMParameterSpec(128, encoded.copyOfRange(2, 2 + length)))
                    val plain = cipher.doFinal(encoded, 2 + length, encoded.size - 2 - length)
                    try { plain.toString(Charsets.UTF_8) } finally { plain.fill(0) }
                }
                mainHandler.post { result.success(transformed) }
            } catch (_: Exception) {
                mainHandler.post { result.error("protected_storage_failed", "Le stockage protégé Android est indisponible.", null) }
            }
        }
    }

    override fun onDestroy() {
        destroyed = true
        finishSourceEditor(null)
        channel?.setMethodCallHandler(null)
        channel = null
        setPlaybackActive(false)
        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        cryptoExecutor.shutdown()
        super.onDestroy()
    }
}
