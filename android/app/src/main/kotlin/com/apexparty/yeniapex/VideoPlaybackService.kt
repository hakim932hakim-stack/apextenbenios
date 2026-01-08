package com.apexparty.yeniapex

import android.app.*
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Build
import android.os.IBinder
import android.support.v4.media.MediaMetadataCompat
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import androidx.core.app.NotificationCompat
import androidx.media.session.MediaButtonReceiver

class VideoPlaybackService : Service() {
    
    companion object {
        const val ACTION_START = "ACTION_START_VIDEO"
        const val ACTION_STOP = "ACTION_STOP_VIDEO"
        const val ACTION_PLAY = "ACTION_PLAY"
        const val ACTION_PAUSE = "ACTION_PAUSE"
        const val ACTION_UPDATE_STATE = "ACTION_UPDATE_STATE"
        
        const val EXTRA_VIDEO_TITLE = "EXTRA_VIDEO_TITLE"
        const val EXTRA_IS_OWNER = "EXTRA_IS_OWNER"
        const val EXTRA_IS_PLAYING = "EXTRA_IS_PLAYING"
        
        private const val NOTIFICATION_ID = 1001
        private const val CHANNEL_ID = "apex_video_playback"
        
        private var isServiceRunning = false
        
        fun isRunning(): Boolean = isServiceRunning
    }
    
    private lateinit var mediaSession: MediaSessionCompat
    private var videoTitle: String = "APEX Video Player"
    private var isPlaying = false
    private var isOwner = false
    
    override fun onCreate() {
        super.onCreate()
        
        android.util.Log.d("VideoPlaybackService", "🎬 onCreate() called")
        
        // Create MediaSession
        mediaSession = MediaSessionCompat(this, "ApexVideoPlayer").apply {
            setFlags(
                MediaSessionCompat.FLAG_HANDLES_MEDIA_BUTTONS or
                MediaSessionCompat.FLAG_HANDLES_TRANSPORT_CONTROLS
            )
            
            setCallback(object : MediaSessionCompat.Callback() {
                override fun onPlay() {
                    if (isOwner) sendControlBroadcast("play")
                }
                
                override fun onPause() {
                    if (isOwner) sendControlBroadcast("pause")
                }
                
                override fun onStop() {
                    stopService()
                }
            })
            
            isActive = true
        }
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        android.util.Log.d("VideoPlaybackService", "📡 onStartCommand() - action: ${intent?.action}")
        
        when (intent?.action) {
            ACTION_START -> {
                android.util.Log.d("VideoPlaybackService", "🚀 ACTION_START received")
                videoTitle = intent.getStringExtra(EXTRA_VIDEO_TITLE) ?: "APEX Video Player"
                isOwner = intent.getBooleanExtra(EXTRA_IS_OWNER, false)
                isPlaying = intent.getBooleanExtra(EXTRA_IS_PLAYING, false)
                startForegroundService()
            }
            ACTION_STOP -> stopService()
            ACTION_PLAY -> {
                isPlaying = true
                updateNotification()
                if (isOwner) sendControlBroadcast("play")
            }
            ACTION_PAUSE -> {
                isPlaying = false
                updateNotification()
                if (isOwner) sendControlBroadcast("pause")
            }
            ACTION_UPDATE_STATE -> {
                isPlaying = intent.getBooleanExtra(EXTRA_IS_PLAYING, isPlaying)
                videoTitle = intent.getStringExtra(EXTRA_VIDEO_TITLE) ?: videoTitle
                updateNotification()
            }
            else -> MediaButtonReceiver.handleIntent(mediaSession, intent)
        }
        return START_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        // Uygulama kapatılsa bile servis çalışmaya devam etsin (Foreground Service olduğu için)
        // Burda stopSelf() ÇAĞIRMIYORUZ.
        android.util.Log.d("VideoPlaybackService", "🧹 onTaskRemoved() called - Service continues")
    }
    
    private fun startForegroundService() {
        android.util.Log.d("VideoPlaybackService", "🔥 startForegroundService() - title: $videoTitle, isOwner: $isOwner, isPlaying: $isPlaying")
        
        isServiceRunning = true
        createNotificationChannel()
        val notification = buildNotification()
        
        android.util.Log.d("VideoPlaybackService", "📢 Calling startForeground() with notification")
        startForeground(NOTIFICATION_ID, notification)
        
        updatePlaybackState(isPlaying)
        
        android.util.Log.d("VideoPlaybackService", "✅ Foreground service started successfully!")
    }
    
    private fun stopService() {
        isServiceRunning = false
        mediaSession.isActive = false
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        
        try {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.cancel(NOTIFICATION_ID)
        } catch (e: Exception) {
            // Ignore
        }
        
        stopSelf()
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Video Playback",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                lightColor = Color.BLUE
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                setSound(null, null)
                enableVibration(false)
            }
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }
    
    private fun buildNotification(): Notification {
        val notificationIntent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, notificationIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        
        // Normal kullanıcı için basit notification
        if (!isOwner) {
            return NotificationCompat.Builder(this, CHANNEL_ID)
                .setContentTitle(videoTitle)
                .setContentText("APEX'te video izleniyor")
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentIntent(pendingIntent)
                .setOngoing(true)
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setSilent(true)
                .build()
        }
        
        // Owner için media controls ile notification
        val style = androidx.media.app.NotificationCompat.MediaStyle()
            .setMediaSession(mediaSession.sessionToken)
            .setShowActionsInCompactView(0, 1)
        
        val playPauseAction = if (isPlaying) {
            NotificationCompat.Action(
                android.R.drawable.ic_media_pause,
                "Pause",
                createPendingIntent(ACTION_PAUSE)
            )
        } else {
            NotificationCompat.Action(
                android.R.drawable.ic_media_play,
                "Play",
                createPendingIntent(ACTION_PLAY)
            )
        }
        
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(videoTitle)
            .setContentText("APEX Video Player")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setStyle(style)
            .setContentIntent(pendingIntent)
            .addAction(playPauseAction)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .build()
    }
    
    private fun createPendingIntent(action: String): PendingIntent {
        val intent = Intent(this, VideoPlaybackService::class.java).apply {
            this.action = action
        }
        return PendingIntent.getService(
            this, action.hashCode(), intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
    }
    
    private fun updatePlaybackState(isPlaying: Boolean) {
        val state = if (isPlaying) {
            PlaybackStateCompat.STATE_PLAYING
        } else {
            PlaybackStateCompat.STATE_PAUSED
        }
        
        val actions = if (isOwner) {
            PlaybackStateCompat.ACTION_PLAY or
            PlaybackStateCompat.ACTION_PAUSE or
            PlaybackStateCompat.ACTION_STOP
        } else {
            0L
        }
        
        val playbackState = PlaybackStateCompat.Builder()
            .setState(state, PlaybackStateCompat.PLAYBACK_POSITION_UNKNOWN, 1.0f)
            .setActions(actions)
            .build()
        
        mediaSession.setPlaybackState(playbackState)
        
        val metadata = MediaMetadataCompat.Builder()
            .putString(MediaMetadataCompat.METADATA_KEY_TITLE, videoTitle)
            .putString(MediaMetadataCompat.METADATA_KEY_ARTIST, "APEX")
            .build()
        
        mediaSession.setMetadata(metadata)
    }
    
    private fun updateNotification() {
        updatePlaybackState(isPlaying)
        val notification = buildNotification()
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(NOTIFICATION_ID, notification)
    }
    
    private fun sendControlBroadcast(action: String) {
        val intent = Intent("com.apexparty.yeniapex.VIDEO_CONTROL").apply {
            putExtra("action", action)
        }
        sendBroadcast(intent)
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
    

    
    override fun onDestroy() {
        isServiceRunning = false
        
        try {
            mediaSession.release()
        } catch (e: Exception) {
            // Ignore
        }
        
        try {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.cancel(NOTIFICATION_ID)
        } catch (e: Exception) {
            // Ignore
        }
        
        super.onDestroy()
    }
}
