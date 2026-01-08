package com.apexparty.yeniapex

import android.content.Context
import android.media.AudioManager
import android.media.AudioFocusRequest
import android.os.Build
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class AudioManagerPlugin(private val context: Context, flutterEngine: FlutterEngine) {
    private val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.apex/audio_manager")
    private val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private var audioFocusRequest: AudioFocusRequest? = null
    
    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "setMediaMode" -> {
                    setMediaAudioMode()
                    result.success(null)
                }
                "setCommunicationMode" -> {
                    setCommunicationAudioMode()
                    result.success(null)
                }
                "setSpeakerOn" -> {
                    val enable = call.argument<Boolean>("enable") ?: true
                    setSpeakerphoneOn(enable)
                    result.success(null)
                }
                "requestAudioFocus" -> {
                    requestAudioFocus()
                    result.success(null)
                }
                "abandonAudioFocus" -> {
                    abandonAudioFocus()
                    result.success(null)
                }
                "startAudioService" -> {
                    startForegroundAudioService()
                    result.success(null)
                }
                "stopAudioService" -> {
                    stopForegroundAudioService()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
    
    private fun startForegroundAudioService() {
        val intent = android.content.Intent(context, ForegroundAudioService::class.java).apply {
            action = ForegroundAudioService.ACTION_START
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(intent)
        } else {
            context.startService(intent)
        }
    }
    
    private fun stopForegroundAudioService() {
        val intent = android.content.Intent(context, ForegroundAudioService::class.java).apply {
            action = ForegroundAudioService.ACTION_STOP
        }
        context.startService(intent)
    }
    
    /**
     * 🎵 MEDYA MODU (Video oynatma için)
     * - Hoparlör varsayılan
     * - Yüksek ses seviyesi
     * - Yankı önleme YOK (gerekirse manuel)
     */
    /**
     * 🎵 MEDYA MODU (Video oynatma için)
     * - Hoparlör varsayılan
     * - Yüksek ses seviyesi
     * - Yankı önleme YOK (gerekirse manuel)
     */
    private fun setMediaAudioMode() {
        // LiveKit'in audio modunu eziyoruz
        audioManager.mode = AudioManager.MODE_NORMAL
        audioManager.isSpeakerphoneOn = true
        android.util.Log.d("AudioManager", "✅ Media Mode Active")
    }
    
    /**
     * 📞 İLETİŞİM MODU (Sesli arama için - LiveKit varsayılanı)
     * - Kulaklık varsayılan
     * - Düşük ses
     * - Yankı önleme AÇIK
     */
    private fun setCommunicationAudioMode() {
        audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
        android.util.Log.d("AudioManager", "📞 COMMUNICATION MODE aktif (standart arama)")
    }
    
    /**
     * 🔊 Hoparlörü zorla aç/kapat
     */
    private fun setSpeakerphoneOn(enable: Boolean) {
        audioManager.isSpeakerphoneOn = enable
        android.util.Log.d("AudioManager", if (enable) "🔊 Hoparlör AÇIK" else "🔇 Hoparlör KAPALI")
    }
    
    /**
     * 🎧 Audio Focus (Medya odaklı)
     */
    private fun requestAudioFocus() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            audioFocusRequest = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                .setAudioAttributes(
                    android.media.AudioAttributes.Builder()
                        .setUsage(android.media.AudioAttributes.USAGE_MEDIA) // 🔥 MEDYA MODU
                        .setContentType(android.media.AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build()
                )
                .build()
            audioManager.requestAudioFocus(audioFocusRequest!!)
        } else {
            @Suppress("DEPRECATION")
            audioManager.requestAudioFocus(
                null,
                AudioManager.STREAM_MUSIC,
                AudioManager.AUDIOFOCUS_GAIN
            )
        }
        android.util.Log.d("AudioManager", "🎧 Audio Focus istendi (MEDIA)")
    }
    
    private fun abandonAudioFocus() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            audioFocusRequest?.let { audioManager.abandonAudioFocusRequest(it) }
        } else {
            @Suppress("DEPRECATION")
            audioManager.abandonAudioFocus(null)
        }
    }
}
