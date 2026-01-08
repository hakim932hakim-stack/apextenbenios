package com.apexparty.yeniapex

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class VideoServicePlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    
    private val videoControlReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            val action = intent?.getStringExtra("action") ?: return
            
            when (action) {
                "play" -> {
                    channel.invokeMethod("onPlay", null)
                }
                "pause" -> {
                    channel.invokeMethod("onPause", null)
                }
            }
        }
    }
    
    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.apex/video_service")
        channel.setMethodCallHandler(this)
        
        // Register broadcast receiver
        val filter = IntentFilter("com.apexparty.yeniapex.VIDEO_CONTROL")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(videoControlReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            context.registerReceiver(videoControlReceiver, filter)
        }
    }
    
    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "startVideoService" -> {
                val title = call.argument<String>("title") ?: "APEX Video"
                val isOwner = call.argument<Boolean>("isOwner") ?: false
                val isPlaying = call.argument<Boolean>("isPlaying") ?: false
                
                android.util.Log.d("VideoServicePlugin", "🔥 startVideoService called - title: $title, isOwner: $isOwner, isPlaying: $isPlaying")
                
                val intent = Intent(context, VideoPlaybackService::class.java).apply {
                    action = VideoPlaybackService.ACTION_START
                    putExtra(VideoPlaybackService.EXTRA_VIDEO_TITLE, title)
                    putExtra(VideoPlaybackService.EXTRA_IS_OWNER, isOwner)
                    putExtra(VideoPlaybackService.EXTRA_IS_PLAYING, isPlaying)
                }
                
                try {
                    context.startService(intent)
                    android.util.Log.d("VideoServicePlugin", "✅ Service start intent sent successfully!")
                    result.success(true)
                } catch (e: Exception) {
                    android.util.Log.e("VideoServicePlugin", "❌ Failed to start service: ${e.message}", e)
                    result.error("SERVICE_ERROR", "Failed to start service: ${e.message}", null)
                }
            }
            
            "stopVideoService" -> {
                val intent = Intent(context, VideoPlaybackService::class.java).apply {
                    action = VideoPlaybackService.ACTION_STOP
                }
                context.startService(intent)
                result.success(true)
            }
            
            "updatePlaybackState" -> {
                val isPlaying = call.argument<Boolean>("isPlaying") ?: false
                val title = call.argument<String>("title")
                
                val intent = Intent(context, VideoPlaybackService::class.java).apply {
                    action = VideoPlaybackService.ACTION_UPDATE_STATE
                    putExtra(VideoPlaybackService.EXTRA_IS_PLAYING, isPlaying)
                    if (title != null) {
                        putExtra(VideoPlaybackService.EXTRA_VIDEO_TITLE, title)
                    }
                }
                
                context.startService(intent)
                result.success(true)
            }
            
            "isServiceRunning" -> {
                result.success(VideoPlaybackService.isRunning())
            }
            
            else -> {
                result.notImplemented()
            }
        }
    }
    
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        try {
            context.unregisterReceiver(videoControlReceiver)
        } catch (e: Exception) {
            // Receiver not registered
        }
    }
}
