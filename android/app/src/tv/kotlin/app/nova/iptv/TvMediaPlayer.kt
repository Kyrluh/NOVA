package app.nova.iptv

import android.app.ActivityManager
import android.content.Context
import android.graphics.Color
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaLibraryInfo
import androidx.media3.common.MimeTypes
import androidx.media3.common.PlaybackException
import androidx.media3.common.PlaybackParameters
import androidx.media3.common.Player
import androidx.media3.common.TrackSelectionOverride
import androidx.media3.common.Tracks
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DefaultDataSource
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.datasource.DataSource
import androidx.media3.datasource.DataSpec
import androidx.media3.datasource.TransferListener
import androidx.media3.exoplayer.DefaultLoadControl
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.analytics.AnalyticsListener
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.ui.AspectRatioFrameLayout
import androidx.media3.ui.PlayerView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import java.io.Closeable
import java.io.File
import java.util.UUID
import java.io.ByteArrayOutputStream

/** TV decoder and native SurfaceView only; Flutter owns navigation and profiles. */
@UnstableApi
class TvMediaPlayer(
    private val context: Context,
    engine: FlutterEngine,
) : Closeable, MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(engine.dartExecutor.binaryMessenger, "nova/tv_player")
    private val sessions = mutableMapOf<Int, Session>()
    private val handler = Handler(Looper.getMainLooper())
    private var closed = false

    init {
        channel.setMethodCallHandler(this)
        engine.platformViewsController.registry.registerViewFactory(
            "nova/tv_video",
            object : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
                override fun create(viewContext: Context, viewId: Int, args: Any?): PlatformView {
                    val values = args as? Map<*, *>
                    val session = sessions[(values?.get("id") as? Number)?.toInt()]
                    return NativeVideoView(viewContext, session, values?.get("fit") as? String)
                }
            },
        )
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (closed) {
            result.error("player_closed", "Le lecteur TV est fermé.", null)
            return
        }
        try {
            val id = (call.argument<Number>("id") ?: error("id")).toInt()
            if (call.method == "create") {
                sessions.getOrPut(id) { Session(id) }
                result.success(null)
                return
            }
            if (call.method == "dispose") {
                sessions.remove(id)?.close()
                result.success(null)
                return
            }
            val session = sessions[id] ?: error("session")
            when (call.method) {
                "open" -> session.open(call)
                "play" -> session.player.play()
                "pause" -> session.player.pause()
                "stop" -> session.stop(call)
                "seek" -> {
                    val position = (call.argument<Number>("positionMs") ?: 0).toLong().coerceAtLeast(0)
                    if (session.player.isCurrentMediaItemSeekable) session.player.seekTo(position)
                }
                "rate" -> session.player.playbackParameters = PlaybackParameters(
                    (call.argument<Number>("value") ?: 1).toFloat().coerceIn(.25f, 3f),
                )
                "volume" -> session.player.volume =
                    (call.argument<Number>("value") ?: 100).toFloat().coerceIn(0f, 100f) / 100f
                "audio" -> session.select(C.TRACK_TYPE_AUDIO, call.argument<String>("idTrack") ?: "auto")
                "subtitle" -> session.select(C.TRACK_TYPE_TEXT, call.argument<String>("idTrack") ?: "no")
                "externalSubtitle" -> session.externalSubtitle(call)
                "resize" -> session.resize(call.argument<String>("fit"))
                else -> {
                    result.notImplemented()
                    return
                }
            }
            session.sendState()
            result.success(null)
        } catch (_: Exception) {
            // Provider URLs and codec exceptions can contain credentials.
            result.error("tv_player_operation_failed", "Cette commande du lecteur TV est indisponible.", null)
        }
    }

    override fun close() {
        if (closed) return
        closed = true
        channel.setMethodCallHandler(null)
        sessions.values.toList().forEach { it.close() }
        sessions.clear()
        handler.removeCallbacksAndMessages(null)
    }

    private inner class Session(val id: Int) : Closeable, Player.Listener, AnalyticsListener {
        private val http = DefaultHttpDataSource.Factory()
            .setUserAgent("NOVA-IPTV-TV")
            .setAllowCrossProtocolRedirects(true)
            .setConnectTimeoutMs(10_000)
            .setReadTimeoutMs(15_000)
        private val dataSource = DefaultDataSource.Factory(context, http)
        private val activityManager = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        private val smallHeap = activityManager.isLowRamDevice || activityManager.memoryClass <= 192
        private val loadControl = DefaultLoadControl.Builder()
            .setBufferDurationsMs(4_000, 20_000, 800, 2_000)
            .setTargetBufferBytes((if (smallHeap) 12 else 24) * 1024 * 1024)
            .setPrioritizeTimeOverSizeThresholds(false)
            .setBackBuffer(0, false)
            .build()
        val player: ExoPlayer = ExoPlayer.Builder(
            context,
            DefaultRenderersFactory(context).setEnableDecoderFallback(true),
        )
            .setLoadControl(loadControl)
            .setMediaSourceFactory(DefaultMediaSourceFactory(DataSource.Factory {
                val sourceGeneration = generation
                FormatHintDataSource(dataSource.createDataSource()) { uri, mime ->
                    handler.post {
                        if (!disposed && generation == sourceGeneration && requestedUri == uri) formatHint = mime
                    }
                }
            }))
            .build()
            .apply {
                setAudioAttributes(
                    AudioAttributes.Builder().setUsage(C.USAGE_MEDIA).setContentType(C.AUDIO_CONTENT_TYPE_MOVIE).build(),
                    false,
                )
                addListener(this@Session)
                addAnalyticsListener(this@Session)
            }
        @Volatile private var generation = 0
        private var disposed = false
        private var changing = false
        private var requestedUri: String? = null
        private var formatHint: String? = null
        private var formatRetried = false
        private var live = false
        private var firstFrame = false
        private var videoDecoder: String? = null
        private var audioDecoder: String? = null
        private var lastDiagnostics: Map<String, Any?>? = null
        private var tracksReady = false
        private var applyingSelections = false
        private val pendingSelections = mutableMapOf<Int, String>()
        private var view: PlayerView? = null
        private var fit = "contain"
        private val subtitleFiles = mutableListOf<File>()
        private val ticker = object : Runnable {
            override fun run() {
                if (disposed || closed) return
                sendState()
                if (player.playWhenReady && player.playbackState != Player.STATE_IDLE && player.playbackState != Player.STATE_ENDED) {
                    handler.postDelayed(this, 500)
                }
            }
        }

        fun open(call: MethodCall) {
            val uri = call.argument<String>("uri") ?: error("uri")
            require(uri.length <= 32_768)
            val headers = call.argument<Map<String, String>>("headers") ?: emptyMap()
            val start = (call.argument<Number>("startMs") ?: 0).toLong().coerceAtLeast(0)
            changing = true
            try {
                generation = (call.argument<Number>("generation") ?: 0).toInt()
                requestedUri = uri
                formatHint = null
                formatRetried = false
                live = call.argument<Boolean>("isLive") == true
                firstFrame = false
                videoDecoder = null
                audioDecoder = null
                lastDiagnostics = null
                pendingSelections.clear()
                tracksReady = false
                player.stop()
                clearSubtitleFiles()
                http.setDefaultRequestProperties(headers)
                player.trackSelectionParameters = player.trackSelectionParameters.buildUpon()
                    .clearOverrides()
                    .setTrackTypeDisabled(C.TRACK_TYPE_AUDIO, false)
                    .setTrackTypeDisabled(C.TRACK_TYPE_TEXT, true)
                    .build()
                val item = MediaItem.fromUri(uri)
                if (live) {
                    // Leave HLS/DASH at their default live edge, rather than
                    // forcing position zero at the start of a DVR window.
                    player.setMediaItem(item)
                } else {
                    player.setMediaItem(item, start)
                }
                player.prepare()
                player.playWhenReady = false
                sendTracks()
            } finally {
                changing = false
            }
            sendDiagnostics()
        }

        fun stop(call: MethodCall) {
            generation = (call.argument<Number>("generation") ?: generation).toInt()
            pendingSelections.clear()
            tracksReady = false
            player.stop()
            player.clearMediaItems()
            clearSubtitleFiles()
        }

        fun attach(target: PlayerView) {
            PlayerView.switchTargetView(player, view, target)
            view = target
            resize(fit)
        }

        fun detach(target: PlayerView) {
            if (view === target) {
                target.player = null
                view = null
            }
        }

        fun resize(value: String?) {
            fit = value ?: "contain"
            view?.resizeMode = when (fit) {
                "cover" -> AspectRatioFrameLayout.RESIZE_MODE_ZOOM
                "fill" -> AspectRatioFrameLayout.RESIZE_MODE_FILL
                else -> AspectRatioFrameLayout.RESIZE_MODE_FIT
            }
        }

        override fun onEvents(player: Player, events: Player.Events) {
            if (!changing) {
                sendState()
                sendDiagnostics()
                handler.removeCallbacks(ticker)
                if (player.playWhenReady && player.playbackState != Player.STATE_IDLE && player.playbackState != Player.STATE_ENDED) {
                    handler.postDelayed(ticker, 500)
                }
            }
        }

        override fun onTracksChanged(tracks: Tracks) {
            tracksReady = tracks.groups.isNotEmpty()
            if (!changing) {
                applyPendingSelections()
                sendTracks()
            }
        }

        override fun onPlayerError(error: PlaybackException) {
            // setMediaItem clears the previous playback error. Do not report a
            // callback queued by a source that has already been replaced.
            if (changing || player.playerError !== error) return
            if (retryDetectedFormat(error)) return
            send("error", mapOf("code" to error.errorCode))
        }

        override fun onRenderedFirstFrame() {
            firstFrame = true
            sendDiagnostics()
        }

        override fun onVideoDecoderInitialized(eventTime: AnalyticsListener.EventTime, decoderName: String, initializedTimestampMs: Long, initializationDurationMs: Long) {
            videoDecoder = decoderName
            sendDiagnostics()
        }

        override fun onAudioDecoderInitialized(eventTime: AnalyticsListener.EventTime, decoderName: String, initializedTimestampMs: Long, initializationDurationMs: Long) {
            audioDecoder = decoderName
            sendDiagnostics()
        }

        private fun sendDiagnostics() {
            if (disposed || changing) return
            val values = mapOf(
                "engine" to "Media3", "engineVersion" to MediaLibraryInfo.VERSION,
                "videoCodec" to player.videoFormat?.sampleMimeType,
                "audioCodec" to player.audioFormat?.sampleMimeType,
                "videoDecoder" to videoDecoder, "audioDecoder" to audioDecoder,
                "firstFrame" to firstFrame,
            )
            if (values == lastDiagnostics) return
            lastDiagnostics = values
            send("diagnostics", values)
        }

        /** Reinterpret a manifest detected on the existing connection once.
         * No extra probe request, engine switch, or retry for HTTP failures. */
        private fun retryDetectedFormat(error: PlaybackException): Boolean {
            val mime = formatHint ?: return false
            if (formatRetried || error.errorCode != PlaybackException.ERROR_CODE_PARSING_CONTAINER_UNSUPPORTED) return false
            val item = player.currentMediaItem ?: return false
            if (item.localConfiguration?.mimeType == mime) return false
            formatRetried = true
            val position = if (live) C.TIME_UNSET else player.currentPosition.coerceAtLeast(0)
            val playing = player.playWhenReady
            changing = true
            try {
                tracksReady = false
                player.setMediaItem(item.buildUpon().setMimeType(mime).build(), position)
                player.prepare()
                player.playWhenReady = playing
            } finally {
                changing = false
            }
            sendState()
            return true
        }

        private fun selected(type: Int): String {
            if (player.trackSelectionParameters.disabledTrackTypes.contains(type)) return "no"
            for ((groupIndex, group) in player.currentTracks.groups.withIndex()) {
                if (group.type != type) continue
                for (trackIndex in 0 until group.length) {
                    if (group.isTrackSelected(trackIndex)) return trackId(groupIndex, group, trackIndex)
                }
            }
            return "auto"
        }

        fun select(type: Int, idTrack: String) {
            if (idTrack == "auto" || idTrack == "no") {
                pendingSelections.remove(type)
                player.trackSelectionParameters = player.trackSelectionParameters.buildUpon()
                    .clearOverridesOfType(type).setTrackTypeDisabled(type, idTrack == "no").build()
            } else {
                if (idTrack != "external") {
                    val parts = idTrack.split(':')
                    require(parts.size == 2 && parts.all { (it.toIntOrNull() ?: -1) >= 0 })
                } else {
                    require(type == C.TRACK_TYPE_TEXT)
                }
                pendingSelections[type] = idTrack
                applyPendingSelections()
            }
        }

        private fun applyPendingSelections() {
            if (!tracksReady || changing || applyingSelections || pendingSelections.isEmpty()) return
            applyingSelections = true
            try {
                val builder = player.trackSelectionParameters.buildUpon()
                var changed = false
                for ((type, idTrack) in pendingSelections.toMap()) {
                    val selection = if (idTrack == "external") {
                        externalTrack()
                    } else {
                        val parts = idTrack.split(':')
                        player.currentTracks.groups.getOrNull(parts[0].toInt())?.let { it to parts[1].toInt() }
                    } ?: continue
                    val (group, index) = selection
                    if (group.type != type || index !in 0 until group.length || !group.isTrackSupported(index)) continue
                    builder.clearOverridesOfType(type).setTrackTypeDisabled(type, false)
                        .setOverrideForType(TrackSelectionOverride(group.mediaTrackGroup, index))
                    pendingSelections.remove(type)
                    changed = true
                }
                if (changed) player.trackSelectionParameters = builder.build()
            } finally {
                applyingSelections = false
            }
        }

        private fun externalTrack(): Pair<Tracks.Group, Int>? {
            for (group in player.currentTracks.groups) {
                if (group.type != C.TRACK_TYPE_TEXT) continue
                for (index in 0 until group.length) {
                    if (group.getTrackFormat(index).id?.contains("nova-external") == true) return group to index
                }
            }
            return null
        }

        private fun trackId(groupIndex: Int, group: Tracks.Group, trackIndex: Int): String =
            if (group.type == C.TRACK_TYPE_TEXT && group.getTrackFormat(trackIndex).id?.contains("nova-external") == true) {
                "external"
            } else {
                "$groupIndex:$trackIndex"
            }

        private fun tracks(type: Int): List<Map<String, Any?>> = buildList {
            for ((groupIndex, group) in player.currentTracks.groups.withIndex()) {
                if (group.type != type) continue
                for (trackIndex in 0 until group.length) {
                    if (!group.isTrackSupported(trackIndex)) continue
                    val format = group.getTrackFormat(trackIndex)
                    add(mapOf(
                        "id" to trackId(groupIndex, group, trackIndex),
                        "title" to format.label,
                        "language" to format.language,
                        "codec" to (format.codecs ?: format.sampleMimeType),
                    ))
                }
            }
        }

        private fun sendTracks() = send("tracks", mapOf(
            "audio" to tracks(C.TRACK_TYPE_AUDIO),
            "subtitles" to tracks(C.TRACK_TYPE_TEXT),
        ))

        fun sendState() {
            if (disposed || changing) return
            val duration = player.duration.takeIf { it != C.TIME_UNSET && it >= 0 } ?: 0
            val size = player.videoSize
            send("state", mapOf(
                "playing" to (player.playWhenReady && player.playbackState != Player.STATE_ENDED && player.playbackState != Player.STATE_IDLE),
                "buffering" to (player.playbackState == Player.STATE_BUFFERING),
                "completed" to (player.playbackState == Player.STATE_ENDED),
                "positionMs" to player.currentPosition.coerceAtLeast(0),
                "durationMs" to duration,
                "bufferedMs" to player.bufferedPosition.coerceAtLeast(0),
                "rate" to player.playbackParameters.speed.toDouble(),
                "volume" to (player.volume * 100).toDouble(),
                "width" to size.width,
                "height" to size.height,
                "audioTrack" to selected(C.TRACK_TYPE_AUDIO),
                "subtitleTrack" to selected(C.TRACK_TYPE_TEXT),
            ))
        }

        private fun send(type: String, values: Map<String, Any?>) {
            if (disposed || closed) return
            channel.invokeMethod("event", values + mapOf("id" to id, "generation" to generation, "type" to type))
        }

        fun externalSubtitle(call: MethodCall) {
            val data = call.argument<String>("data")
            val title = call.argument<String>("title")?.take(160) ?: "Sous-titres externes"
            val suppliedUri = call.argument<String>("uri")
            val subtitleUri = if (data != null) {
                require(data.length <= 2 * 1024 * 1024)
                val file = File(context.cacheDir, "nova-sub-${UUID.randomUUID()}.srt")
                file.writeText(data)
                subtitleFiles.add(file)
                Uri.fromFile(file)
            } else {
                require(!suppliedUri.isNullOrBlank())
                Uri.parse(suppliedUri)
            }
            val item = player.currentMediaItem ?: error("media")
            val position = player.currentPosition
            val playing = player.playWhenReady
            val parameters = player.trackSelectionParameters
            val audio = selected(C.TRACK_TYPE_AUDIO)
            val mime = when {
                title.endsWith(".vtt", true) || suppliedUri?.substringBefore('?')?.endsWith(".vtt", true) == true || data?.trimStart()?.startsWith("WEBVTT") == true -> MimeTypes.TEXT_VTT
                title.endsWith(".ass", true) || title.endsWith(".ssa", true) || data?.trimStart()?.startsWith("[Script Info]") == true -> MimeTypes.TEXT_SSA
                else -> MimeTypes.APPLICATION_SUBRIP
            }
            val config = MediaItem.SubtitleConfiguration.Builder(subtitleUri)
                .setId("nova-external")
                .setMimeType(mime).setLabel(title).setSelectionFlags(C.SELECTION_FLAG_DEFAULT).build()
            val existing = item.localConfiguration?.subtitleConfigurations.orEmpty()
                .filterNot { it.id == "nova-external" }
            tracksReady = false
            pendingSelections[C.TRACK_TYPE_TEXT] = "external"
            if (audio != "auto" && audio != "no") pendingSelections[C.TRACK_TYPE_AUDIO] = audio
            player.setMediaItem(item.buildUpon().setSubtitleConfigurations(existing + config).build(), position)
            player.trackSelectionParameters = parameters.buildUpon()
                .clearOverridesOfType(C.TRACK_TYPE_TEXT)
                .setTrackTypeDisabled(C.TRACK_TYPE_TEXT, false).build()
            player.prepare()
            player.playWhenReady = playing
        }

        override fun close() {
            if (disposed) return
            disposed = true
            handler.removeCallbacks(ticker)
            view?.player = null
            view = null
            player.removeListener(this)
            player.removeAnalyticsListener(this)
            player.release()
            clearSubtitleFiles()
        }

        private fun clearSubtitleFiles() {
            subtitleFiles.forEach { it.delete() }
            subtitleFiles.clear()
        }
    }

    /** Inspect only a small prefix already read by the extractor. */
    private class FormatHintDataSource(
        private val upstream: DataSource,
        private val onHint: (String, String) -> Unit,
    ) : DataSource {
        private var requestUri = ""
        private var found = false
        private val prefix = ByteArrayOutputStream(1024)
        override fun addTransferListener(listener: TransferListener) = upstream.addTransferListener(listener)
        override fun getUri(): Uri? = upstream.uri
        override fun getResponseHeaders(): Map<String, List<String>> = upstream.responseHeaders
        override fun open(dataSpec: DataSpec): Long {
            requestUri = dataSpec.uri.toString()
            found = false
            prefix.reset()
            val length = upstream.open(dataSpec)
            val type = upstream.responseHeaders.entries.firstOrNull { it.key.equals("Content-Type", true) }
                ?.value?.firstOrNull()?.substringBefore(';')?.trim()?.lowercase()
            val mime = when (type) {
                "application/vnd.apple.mpegurl", "application/x-mpegurl", "audio/mpegurl", "audio/x-mpegurl" -> MimeTypes.APPLICATION_M3U8
                "application/dash+xml" -> MimeTypes.APPLICATION_MPD
                else -> null
            }
            if (mime != null) report(mime)
            return length
        }
        override fun read(buffer: ByteArray, offset: Int, length: Int): Int {
            val count = upstream.read(buffer, offset, length)
            if (!found && count > 0 && prefix.size() < 1024) {
                prefix.write(buffer, offset, minOf(count, 1024 - prefix.size()))
                val text = prefix.toString("UTF-8").removePrefix("\uFEFF").trimStart()
                if (text.startsWith("#EXTM3U")) report(MimeTypes.APPLICATION_M3U8)
                else if (text.startsWith("<MPD") || (text.startsWith("<?xml") && Regex("<MPD(?:\\s|>)").containsMatchIn(text))) report(MimeTypes.APPLICATION_MPD)
            }
            return count
        }
        private fun report(mime: String) {
            found = true
            onHint(requestUri, mime)
        }
        override fun close() = upstream.close()
    }

    private inner class NativeVideoView(
        viewContext: Context,
        private val session: Session?,
        fit: String?,
    ) : PlatformView {
        private val nativeView = PlayerView(viewContext).apply {
            useController = false
            setUseArtwork(false)
            setShutterBackgroundColor(Color.BLACK)
            setShowBuffering(PlayerView.SHOW_BUFFERING_NEVER)
            isFocusable = false
            isFocusableInTouchMode = false
            descendantFocusability = ViewGroup.FOCUS_BLOCK_DESCENDANTS
            layoutParams = FrameLayout.LayoutParams(-1, -1)
            videoSurfaceView?.apply {
                isFocusable = false
                isFocusableInTouchMode = false
            }
        }

        init {
            session?.resize(fit)
            session?.attach(nativeView)
        }

        override fun getView(): View = nativeView
        override fun dispose() { session?.detach(nativeView) }
    }
}
