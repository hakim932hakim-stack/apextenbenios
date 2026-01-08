package com.apexparty.yeniapex

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat

class ForegroundAudioService : Service() {

    companion object {
        const val ACTION_START = "ACTION_START"
        const val ACTION_STOP = "ACTION_STOP"
        
        private const val TAG = "ForegroundAudioService"
        private var isServiceRunning = false

        fun isRunning(): Boolean = isServiceRunning
    }

    private var wakeLock: PowerManager.WakeLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> startForegroundService()
            ACTION_STOP -> stopForegroundService()
        }
        return START_NOT_STICKY
    }

    private fun startForegroundService() {
        if (isServiceRunning) return
        isServiceRunning = true

        val channelId = "apex_audio_channel"
        val channelName = "Arka Plan Ses"

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                channelName,
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                lightColor = Color.BLUE
                lockscreenVisibility = Notification.VISIBILITY_PRIVATE
                setSound(null, null)
                enableVibration(false)
            }
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .createNotificationChannel(channel)
        }

        val notificationIntent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, notificationIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val notification = NotificationCompat.Builder(this, channelId)
            .setContentTitle("APEX")
            .setContentText("Mikrofon arka planda kullanılabilir 🎤")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setSilent(true)
            .build()

        startForeground(2, notification) // ID 2 (VideoPlaybackService ID 1 kullanıyor)

        // 🔥 CRITICAL: Wake lock - TIMEOUT YOK! (Süresiz acquire)
        // Timeout koyarsak 10 dakika sonra otomatik release oluyor!
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "ApexHubs::AudioWakeLock"
        )
        wakeLock?.acquire() // ✅ Süresiz - manuel release edilene kadar aktif
        
        Log.d(TAG, "✅ Foreground audio service started with INFINITE wake lock")
    }

    private fun stopForegroundService() {
        isServiceRunning = false

        wakeLock?.let {
            if (it.isHeld) it.release()
        }
        wakeLock = null

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }

        (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancel(2)
        stopSelf()
        
        Log.d(TAG, "❌ Foreground audio service stopped")
    }

    override fun onDestroy() {
        isServiceRunning = false
        wakeLock?.let { if (it.isHeld) it.release() }
        super.onDestroy()
    }
}
