package com.apexparty.yeniapex

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ActivityInfo
import android.graphics.Color
import android.graphics.PorterDuff
import android.content.res.ColorStateList
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.ImageButton
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.SeekBar
import android.widget.TextView
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.util.Formatter
import java.util.Locale

class NativeVideoPlayerPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
    companion object {
        // 🔥 Singleton Cache Instance
        private var simpleCache: androidx.media3.datasource.cache.SimpleCache? = null
    }

    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var activity: Activity? = null
    
    // Core Player & UI
    private var player: ExoPlayer? = null
    private var textureView: android.view.TextureView? = null
    private var controlsView: FrameLayout? = null
    
    // UI Elements
    private var playPauseButton: ImageButton? = null
    private var fullscreenButton: ImageButton? = null
    private var seekBar: SeekBar? = null
    private var volumeSeekBar: SeekBar? = null
    private var currentTimeText: TextView? = null
    private var durationText: TextView? = null
    private var titleText: TextView? = null
    
    // State
    private var videoTitle: String = "Apex Party"
    private var isOwner: Boolean = false
    private var currentVideoUrl: String? = null
    private var savedTopMargin: Int = 0
    private var savedHeight: Int = 0 
    private var isFullscreen: Boolean = false
    
    // Timer for UI updates
    private val handler = Handler(Looper.getMainLooper())
    private val updateProgressAction = object : Runnable {
        override fun run() {
            updateProgress()
            if (player?.isPlaying == true) {
                handler.postDelayed(this, 1000)
            }
        }
    }
    
    // Broadcast receiver
    private val videoControlReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            val action = intent?.getStringExtra("action") ?: return
            when (action) {
                "play" -> player?.play()
                "pause" -> player?.pause()
                "seek" -> player?.seekTo(intent.getLongExtra("position", 0))
            }
        }
    }
    
    private fun getDrawableId(name: String): Int {
        val id = context.resources.getIdentifier(name, "drawable", context.packageName)
        return if (id != 0) id else android.R.drawable.ic_media_play
    }
    
    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.apex/native_video_player")
        channel.setMethodCallHandler(this)
        
        val filter = IntentFilter("com.apexparty.yeniapex.VIDEO_CONTROL")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(videoControlReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            context.registerReceiver(videoControlReceiver, filter)
        }
    }
    
    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "loadVideo" -> loadVideo(call, result)
            "play" -> { player?.play(); result.success(null) }
            "pause" -> { player?.pause(); result.success(null) }
            "seekTo" -> {
                player?.seekTo(call.argument<Int>("position")?.toLong() ?: 0L)
                result.success(null)
            }
            "stop" -> { stopVideo(); result.success(null) }
            "getCurrentPosition" -> result.success(player?.currentPosition ?: 0L)
            "getDuration" -> result.success(player?.duration ?: 0L)
            "isPlaying" -> result.success(player?.isPlaying ?: false)
            "setVolume" -> {
                val volume = call.argument<Double>("volume")?.toFloat() ?: 1.0f
                player?.volume = volume.coerceIn(0f, 1f)
                result.success(null)
            }
            "toggleFullscreen" -> {
                activity?.runOnUiThread { toggleFullscreen() }
                result.success(null)
            }
            "hidePlayer" -> {
                activity?.runOnUiThread { hidePlayer() }
                result.success(null)
            }
            "showPlayer" -> {
                activity?.runOnUiThread { showPlayer() }
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }
    
    private fun loadVideo(call: MethodCall, result: Result) {
        val url = call.argument<String>("url") ?: run { result.error("INVALID_URL", "URL is required", null); return }
        
        currentVideoUrl = url
        videoTitle = call.argument<String>("title") ?: "Apex Party"
        android.util.Log.d("NativeVideoPlayer", "Received Title: '$videoTitle'")
        
        isOwner = call.argument<Boolean>("isOwner") ?: false
        savedTopMargin = call.argument<Int>("topMargin") ?: 0
        val startPosition = call.argument<Int>("startPosition")?.toLong() ?: 0L
        
        // Calculate initial height (in Portrait)
        savedHeight = (context.resources.displayMetrics.heightPixels * 0.35).toInt()
        
        activity?.runOnUiThread {
            try {
                releasePlayer()
                
                // 1. TextureView
                val newTextureView = android.view.TextureView(context).apply {
                    layoutParams = FrameLayout.LayoutParams(
                        FrameLayout.LayoutParams.MATCH_PARENT,
                        savedHeight
                    ).apply { topMargin = savedTopMargin }
                    visibility = View.VISIBLE
                    alpha = 0f
                }
                
                // 2. Controls
                val newControlsView = FrameLayout(context).apply {
                    layoutParams = FrameLayout.LayoutParams(
                        FrameLayout.LayoutParams.MATCH_PARENT,
                        savedHeight
                    ).apply { topMargin = savedTopMargin }
                    visibility = View.VISIBLE
                }

                // Title
                titleText = TextView(context).apply {
                    text = videoTitle
                    setTextColor(Color.WHITE)
                    textSize = 16f
                    setPadding(40, 40, 40, 0)
                    setShadowLayer(5f, 0f, 0f, Color.BLACK)
                    layoutParams = FrameLayout.LayoutParams(
                        FrameLayout.LayoutParams.WRAP_CONTENT,
                        FrameLayout.LayoutParams.WRAP_CONTENT
                    ).apply { gravity = Gravity.TOP or Gravity.START }
                }
                newControlsView.addView(titleText)

                // Play/Pause
                val playBtn = ImageButton(context).apply {
                    setImageResource(getDrawableId("ic_custom_play"))
                    background = null
                    setColorFilter(Color.WHITE)
                    scaleType = ImageView.ScaleType.FIT_CENTER
                    layoutParams = FrameLayout.LayoutParams(250, 250).apply { gravity = Gravity.CENTER }
                    
                    if (isOwner) {
                        setOnClickListener {
                            player?.let { if (it.isPlaying) it.pause() else it.play() }
                        }
                    } else {
                        visibility = View.GONE
                    }
                }
                playPauseButton = playBtn
                newControlsView.addView(playBtn)
                
                // Bottom Bar
                val bottomBar = LinearLayout(context).apply {
                    orientation = LinearLayout.HORIZONTAL
                    gravity = Gravity.CENTER_VERTICAL
                    setBackgroundColor(Color.TRANSPARENT)
                    setPadding(20, 10, 20, 10)
                    layoutParams = FrameLayout.LayoutParams(
                        FrameLayout.LayoutParams.MATCH_PARENT,
                        FrameLayout.LayoutParams.WRAP_CONTENT
                    ).apply { gravity = Gravity.BOTTOM }
                }
                
                currentTimeText = TextView(context).apply {
                    text = "00:00"
                    setTextColor(Color.WHITE)
                    textSize = 12f
                    setShadowLayer(4f, 0f, 0f, Color.BLACK)
                }
                bottomBar.addView(currentTimeText)
                
                // Seek Bar (Video)
                seekBar = SeekBar(context).apply {
                    layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
                    progressDrawable.setColorFilter(Color.WHITE, PorterDuff.Mode.SRC_IN)
                    thumb.setColorFilter(Color.WHITE, PorterDuff.Mode.SRC_IN)
                    
                    if (isOwner) {
                        setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
                            override fun onProgressChanged(s: SeekBar?, p: Int, fromUser: Boolean) {
                                if (fromUser) currentTimeText?.text = formatTime(p.toLong())
                            }
                            override fun onStartTrackingTouch(s: SeekBar?) {
                                // Pause while seeking
                                player?.pause()
                            }
                            override fun onStopTrackingTouch(s: SeekBar?) {
                                s?.let { 
                                    player?.seekTo(it.progress.toLong()) 
                                    player?.play() // Resume
                                }
                            }
                        })
                    } else {
                        setOnTouchListener { _, _ -> true }
                    }
                }
                bottomBar.addView(seekBar)
                
                durationText = TextView(context).apply {
                    text = "00:00"
                    setTextColor(Color.WHITE)
                    textSize = 12f
                    setPadding(10, 0, 10, 0)
                    setShadowLayer(4f, 0f, 0f, Color.BLACK)
                }
                bottomBar.addView(durationText)
                
                // Volume Bar (Little one)
                volumeSeekBar = SeekBar(context).apply {
                    layoutParams = LinearLayout.LayoutParams(200, LinearLayout.LayoutParams.WRAP_CONTENT) // Fixed width ~70dp
                    max = 100
                    progress = 100 // Default 100%
                    progressDrawable.setColorFilter(Color.LTGRAY, PorterDuff.Mode.SRC_IN)
                    thumb.setColorFilter(Color.WHITE, PorterDuff.Mode.SRC_IN)
                    // thumb.scaleX = 0.7f // Make thumb smaller? 
                    // Android default thumb is big. Maybe standard is fine.

                    setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
                        override fun onProgressChanged(s: SeekBar?, p: Int, fromUser: Boolean) {
                            player?.volume = p / 100f
                        }
                        override fun onStartTrackingTouch(s: SeekBar?) {}
                        override fun onStopTrackingTouch(s: SeekBar?) {}
                    })
                }
                bottomBar.addView(volumeSeekBar)
                
                // Fullscreen
                fullscreenButton = ImageButton(context).apply {
                    setImageResource(getDrawableId("ic_custom_fullscreen"))
                    background = null
                    setColorFilter(Color.WHITE)
                    layoutParams = LinearLayout.LayoutParams(100, 100)
                    setOnClickListener { toggleFullscreen() }
                }
                bottomBar.addView(fullscreenButton)
                
                newControlsView.addView(bottomBar)
                
                newTextureView.setOnClickListener {
                    if (newControlsView.visibility == View.VISIBLE) newControlsView.visibility = View.GONE 
                    else { newControlsView.visibility = View.VISIBLE; newControlsView.bringToFront() }
                }
                
                // 3. Player with Cache Limiting
                // 🔥 SINGLETON CACHE FIX: Cache instance must be unique per process
                if (simpleCache == null) {
                    val cacheDir = java.io.File(context.cacheDir, "exoplayer")
                    simpleCache = androidx.media3.datasource.cache.SimpleCache(
                        cacheDir,
                        androidx.media3.datasource.cache.LeastRecentlyUsedCacheEvictor(50 * 1024 * 1024), // 50 MB max
                        androidx.media3.database.StandaloneDatabaseProvider(context)
                    )
                }
                
                val cacheDataSourceFactory = androidx.media3.datasource.cache.CacheDataSource.Factory()
                    .setCache(simpleCache!!)
                    .setUpstreamDataSourceFactory(
                        androidx.media3.datasource.DefaultHttpDataSource.Factory()
                            .setUserAgent("Mozilla/5.0")
                            .setAllowCrossProtocolRedirects(true)
                    )
                    .setFlags(androidx.media3.datasource.cache.CacheDataSource.FLAG_IGNORE_CACHE_ON_ERROR)
                
                player = ExoPlayer.Builder(context)
                    .setMediaSourceFactory(
                        androidx.media3.exoplayer.source.DefaultMediaSourceFactory(context)
                            .setDataSourceFactory(cacheDataSourceFactory)
                    )
                    .build().apply {
                    addListener(object : Player.Listener {
                        override fun onPlaybackStateChanged(state: Int) {
                            if (state == Player.STATE_READY) {
                                newTextureView.animate().alpha(1f).setDuration(300).start()
                                val dur = duration
                                seekBar?.max = dur.toInt()
                                durationText?.text = formatTime(dur)
                                channel.invokeMethod("onReady", mapOf("duration" to dur))
                            }
                            if (state == Player.STATE_ENDED) {
                                channel.invokeMethod("onEnded", null)
                                playPauseButton?.setImageResource(getDrawableId("ic_custom_play"))
                            }
                        }
                        override fun onIsPlayingChanged(isPlaying: Boolean) {
                            updateVideoService(isPlaying)
                            channel.invokeMethod("onPlaybackState", mapOf("playing" to isPlaying))
                            activity?.runOnUiThread {
                                if (isPlaying) {
                                    playPauseButton?.setImageResource(getDrawableId("ic_custom_pause"))
                                    handler.post(updateProgressAction)
                                } else {
                                    playPauseButton?.setImageResource(getDrawableId("ic_custom_play"))
                                    handler.removeCallbacks(updateProgressAction)
                                }
                            }
                        }
                    })
                }

                newTextureView.surfaceTextureListener = object : android.view.TextureView.SurfaceTextureListener {
                    override fun onSurfaceTextureAvailable(s: android.graphics.SurfaceTexture, w: Int, h: Int) { player?.setVideoTextureView(newTextureView) }
                    override fun onSurfaceTextureSizeChanged(s: android.graphics.SurfaceTexture, w: Int, h: Int) {}
                    override fun onSurfaceTextureDestroyed(s: android.graphics.SurfaceTexture): Boolean = true
                    override fun onSurfaceTextureUpdated(s: android.graphics.SurfaceTexture) {}
                }

                val rootView = activity?.findViewById<FrameLayout>(android.R.id.content)
                rootView?.addView(newTextureView)
                rootView?.addView(newControlsView)
                newTextureView.bringToFront()
                newControlsView.bringToFront()

                textureView = newTextureView
                controlsView = newControlsView

                val isDash = url.contains(".mpd")
                val isHls = url.contains(".m3u8", ignoreCase = true)
                val mediaItem = when {
                    isDash -> MediaItem.Builder().setUri(Uri.parse(url)).setMimeType(MimeTypes.APPLICATION_MPD).build()
                    isHls -> MediaItem.Builder().setUri(Uri.parse(url)).setMimeType(MimeTypes.APPLICATION_M3U8).build()
                    else -> MediaItem.fromUri(Uri.parse(url))
                }
                player?.setMediaItem(mediaItem)
                player?.seekTo(startPosition)
                player?.prepare()
                player?.playWhenReady = true

                startVideoService()
                result.success(null)

            } catch (e: Exception) {
                android.util.Log.e("NativeVideoPlayer", "Load error", e)
                result.error("LOAD_ERROR", e.message, null)
            }
        }
    }
    
    private fun updateProgress() {
        player?.let {
            val pos = it.currentPosition
            seekBar?.progress = pos.toInt()
            currentTimeText?.text = formatTime(pos)
        }
    }
    
    private fun formatTime(ms: Long): String {
        val totalSeconds = ms / 1000
        val seconds = totalSeconds % 60
        val minutes = (totalSeconds / 60) % 60
        val hours = totalSeconds / 3600
        return if (hours > 0) String.format("%d:%02d:%02d", hours, minutes, seconds) 
               else String.format("%02d:%02d", minutes, seconds)
    }
    
    private fun toggleFullscreen() {
        isFullscreen = !isFullscreen
        
        val tParams = textureView?.layoutParams as? FrameLayout.LayoutParams ?: return
        val cParams = controlsView?.layoutParams as? FrameLayout.LayoutParams ?: return
        
        if (isFullscreen) {
            activity?.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE
            
            tParams.height = FrameLayout.LayoutParams.MATCH_PARENT
            tParams.width = FrameLayout.LayoutParams.MATCH_PARENT
            tParams.topMargin = 0
            
            cParams.height = FrameLayout.LayoutParams.MATCH_PARENT
            cParams.width = FrameLayout.LayoutParams.MATCH_PARENT
            cParams.topMargin = 0
        } else {
            activity?.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
            
            // Restore SAVED Height (Portrait)
            tParams.height = savedHeight
            tParams.width = FrameLayout.LayoutParams.MATCH_PARENT
            tParams.topMargin = savedTopMargin
            
            cParams.height = savedHeight
            cParams.width = FrameLayout.LayoutParams.MATCH_PARENT
            cParams.topMargin = savedTopMargin
        }
        
        textureView?.layoutParams = tParams
        controlsView?.layoutParams = cParams
        
        textureView?.requestLayout()
        controlsView?.requestLayout()
        
        textureView?.bringToFront()
        controlsView?.bringToFront()
    }
    
    private fun releasePlayer() {
        handler.removeCallbacks(updateProgressAction)
        player?.release()
        player = null
        textureView?.let { (it.parent as? ViewGroup)?.removeView(it) }; textureView = null
        controlsView?.let { (it.parent as? ViewGroup)?.removeView(it) }; controlsView = null
        playPauseButton = null
        seekBar = null
        volumeSeekBar = null
    }
    
    // Service methods (Unchanged)
    private fun startVideoService() {
        context.startService(Intent(context, VideoPlaybackService::class.java).apply {
            action = VideoPlaybackService.ACTION_START
            putExtra(VideoPlaybackService.EXTRA_VIDEO_TITLE, videoTitle)
            putExtra(VideoPlaybackService.EXTRA_IS_OWNER, isOwner)
        })
    }
    private fun stopVideoService() {
        context.startService(Intent(context, VideoPlaybackService::class.java).apply { action = VideoPlaybackService.ACTION_STOP })
    }
    private fun stopVideo() { stopVideoService(); releasePlayer() }
    private fun updateVideoService(isPlaying: Boolean) {
        context.startService(Intent(context, VideoPlaybackService::class.java).apply {
            action = if (isPlaying) VideoPlaybackService.ACTION_PLAY else VideoPlaybackService.ACTION_PAUSE
        })
    }
    
    // 🚫 Hide player (for bottom sheets)
    private fun hidePlayer() {
        textureView?.visibility = View.GONE
        controlsView?.visibility = View.GONE
        android.util.Log.d("NativeVideoPlayer", "🙈 Player hidden")
    }
    
    // ✅ Show player
    private fun showPlayer() {
        textureView?.visibility = View.VISIBLE
        controlsView?.visibility = View.VISIBLE
        android.util.Log.d("NativeVideoPlayer", "👀 Player shown")
    }
    
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        try { context.unregisterReceiver(videoControlReceiver) } catch (e: Exception) {}
        releasePlayer()
        stopVideoService()
    }
    override fun onAttachedToActivity(binding: ActivityPluginBinding) { activity = binding.activity }
    override fun onDetachedFromActivityForConfigChanges() { activity = null }
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) { activity = binding.activity }
    override fun onDetachedFromActivity() { activity = null }
}
