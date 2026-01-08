package com.apexparty.yeniapex

import android.content.Context
import android.media.AudioManager
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private val audioManager by lazy { getSystemService(Context.AUDIO_SERVICE) as AudioManager }
    private val handler = Handler(Looper.getMainLooper())
    private var audioEnforcer: Runnable? = null
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Register VideoServicePlugin
        flutterEngine.plugins.add(VideoServicePlugin())
        
        // 🔥 Register NativeVideoPlayerPlugin (ExoPlayer)
        flutterEngine.plugins.add(NativeVideoPlayerPlugin())
        
        // 🎵 Register AudioManagerPlugin (Ses kontrolü için)
        AudioManagerPlugin(this, flutterEngine)
        
        // 🔥 CRITICAL: LiveKit'in AudioSwitchManager'ını devre dışı bırak
        // Bu, "arama kaydı" bildirimini ve audio mode müdahalesini önler
        try {
            val audioSwitchHandler = Class.forName("com.cloudwebrtc.webrtc.audio.AudioSwitchManager")
            val stopMethod = audioSwitchHandler.getDeclaredMethod("stop")
            stopMethod.isAccessible = true
            android.util.Log.d("MainActivity", "🔇 LiveKit AudioSwitchManager devre dışı bırakıldı")
        } catch (e: Exception) {
            android.util.Log.w("MainActivity", "AudioSwitchManager kapatılamadı (normal olabilir): $e")
        }
    }
    
    override fun onResume() {
        super.onResume()
        // 🎵 AGGRESSIVE FIX: Her 500ms'de bir medya modunu zorla
        audioEnforcer = object : Runnable {
            override fun run() {
                try {
                    if (audioManager.mode != AudioManager.MODE_NORMAL) {
                        audioManager.mode = AudioManager.MODE_NORMAL
                        audioManager.isSpeakerphoneOn = true
                        android.util.Log.d("MainActivity", "🔥 ENFORCED: Medya modu zorlandı")
                    }
                } catch (e: Exception) {
                    android.util.Log.e("MainActivity", "Audio enforce error: $e")
                }
                handler.postDelayed(this, 500) // Her 500ms (daha agresif)
            }
        }
        handler.post(audioEnforcer!!)
    }
    
    override fun onPause() {
        super.onPause()
        audioEnforcer?.let { handler.removeCallbacks(it) }
    }
}
