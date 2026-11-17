package com.staticradio.app

import android.app.*
import android.content.Context
import android.content.Intent
import android.graphics.*
import android.os.Build
import android.os.IBinder
import android.support.v4.media.MediaMetadataCompat
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import androidx.core.app.NotificationCompat

class RadioLockscreenService : Service() {

    companion object {
        const val CHANNEL_ID = "static_radio_lockscreen_v3"
        const val NOTIFICATION_ID = 1001

        const val ACTION_PREV = "com.staticradio.app.ACTION_PREV"
        const val ACTION_NEXT = "com.staticradio.app.ACTION_NEXT"
        const val ACTION_TALK = "com.staticradio.app.ACTION_TALK"

        const val EXTRA_TICKER = "extra_ticker"
        const val EXTRA_FREQ = "extra_freq"
        const val EXTRA_IS_TRANSMITTING = "extra_is_transmitting"
        const val EXTRA_IS_BUSY = "extra_is_busy"

        var instance: RadioLockscreenService? = null
            private set
    }

    private var mediaSession: MediaSessionCompat? = null
    private var currentTicker = "SQUAD"
    private var currentFreq = "140.345 MHz"
    private var isTransmitting = false
    private var isBusy = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        instance = this
        createNotificationChannel()
        initMediaSession()
    }

    private fun initMediaSession() {
        mediaSession = MediaSessionCompat(this, "StaticRadioSession").apply {
            isActive = true
            setCallback(object : MediaSessionCompat.Callback() {
                override fun onSkipToPrevious() {
                    MainActivity.sendLockscreenAction("onPrevChannel")
                }

                override fun onSkipToNext() {
                    MainActivity.sendLockscreenAction("onNextChannel")
                }

                override fun onPlay() {
                    MainActivity.sendLockscreenAction("onTalkToggle")
                }

                override fun onPause() {
                    MainActivity.sendLockscreenAction("onTalkToggle")
                }

                override fun onCustomAction(action: String?, extras: android.os.Bundle?) {
                    when (action) {
                        ACTION_PREV -> MainActivity.sendLockscreenAction("onPrevChannel")
                        ACTION_NEXT -> MainActivity.sendLockscreenAction("onNextChannel")
                        ACTION_TALK -> MainActivity.sendLockscreenAction("onTalkToggle")
                    }
                }
            })
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        intent?.let {
            if (it.hasExtra(EXTRA_TICKER)) currentTicker = it.getStringExtra(EXTRA_TICKER) ?: currentTicker
            if (it.hasExtra(EXTRA_FREQ)) currentFreq = it.getStringExtra(EXTRA_FREQ) ?: currentFreq
            if (it.hasExtra(EXTRA_IS_TRANSMITTING)) isTransmitting = it.getBooleanExtra(EXTRA_IS_TRANSMITTING, false)
            if (it.hasExtra(EXTRA_IS_BUSY)) isBusy = it.getBooleanExtra(EXTRA_IS_BUSY, false)
        }

        val notification = buildNotification()
        startForeground(NOTIFICATION_ID, notification)
        return START_STICKY
    }

    fun updateState(ticker: String, freq: String, transmitting: Boolean, busy: Boolean) {
        currentTicker = ticker
        currentFreq = freq
        isTransmitting = transmitting
        isBusy = busy
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(NOTIFICATION_ID, buildNotification())
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Static Radio Media Controller",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Spotify-style radio controller for lockscreen"
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                setShowBadge(true)
            }
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    private fun generateRadioArtwork(ticker: String, freq: String, isTx: Boolean, isBusy: Boolean): Bitmap {
        val size = 512
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)

        // Matte black chassis
        val bgPaint = Paint().apply {
            isAntiAlias = true
            color = Color.parseColor("#0F1218")
        }
        val rect = RectF(0f, 0f, size.toFloat(), size.toFloat())
        canvas.drawRoundRect(rect, 48f, 48f, bgPaint)

        // Accent theme color
        val accentColor = when {
            isTx -> Color.parseColor("#E63946")
            isBusy -> Color.parseColor("#FFB703")
            else -> Color.parseColor("#52B788")
        }

        // Glowing outer bezel
        val borderPaint = Paint().apply {
            isAntiAlias = true
            style = Paint.Style.STROKE
            strokeWidth = 14f
            color = accentColor
        }
        canvas.drawRoundRect(RectF(18f, 18f, (size - 18).toFloat(), (size - 18).toFloat()), 38f, 38f, borderPaint)

        // Concentric radio frequency rings
        val ringPaint = Paint().apply {
            isAntiAlias = true
            style = Paint.Style.STROKE
            strokeWidth = 2.5f
            color = Color.argb(45, 255, 255, 255)
        }
        for (r in listOf(130f, 170f, 210f)) {
            canvas.drawCircle(size / 2f, size / 2f, r, ringPaint)
        }

        // Header: STATIC RADIO
        val headerPaint = Paint().apply {
            isAntiAlias = true
            color = Color.argb(180, 255, 255, 255)
            textSize = 28f
            textAlign = Paint.Align.CENTER
            typeface = Typeface.create(Typeface.MONOSPACE, Typeface.BOLD)
            letterSpacing = 0.25f
        }
        canvas.drawText("STATIC RADIO", size / 2f, 110f, headerPaint)

        // Central Ticker
        val tickerPaint = Paint().apply {
            isAntiAlias = true
            color = accentColor
            textSize = 88f
            textAlign = Paint.Align.CENTER
            typeface = Typeface.create(Typeface.MONOSPACE, Typeface.BOLD)
            letterSpacing = 0.15f
        }
        canvas.drawText(ticker, size / 2f, 280f, tickerPaint)

        // Frequency
        val freqPaint = Paint().apply {
            isAntiAlias = true
            color = Color.argb(220, 255, 255, 255)
            textSize = 34f
            textAlign = Paint.Align.CENTER
            typeface = Typeface.create(Typeface.MONOSPACE, Typeface.NORMAL)
            letterSpacing = 0.1f
        }
        canvas.drawText(freq, size / 2f, 345f, freqPaint)

        // Status Tag
        val statusText = when {
            isTx -> "● TRANSMITTING"
            isBusy -> "● OCCUPIED"
            else -> "● LIVE CARRIER"
        }
        val statusPaint = Paint().apply {
            isAntiAlias = true
            color = accentColor
            textSize = 24f
            textAlign = Paint.Align.CENTER
            typeface = Typeface.create(Typeface.MONOSPACE, Typeface.BOLD)
            letterSpacing = 0.1f
        }
        canvas.drawText(statusText, size / 2f, 430f, statusPaint)

        return bitmap
    }

    private fun buildNotification(): Notification {
        val launchIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val launchPendingIntent = PendingIntent.getActivity(
            this, 0, launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val prevIntent = Intent(this, RadioLockscreenReceiver::class.java).apply { action = ACTION_PREV }
        val prevPending = PendingIntent.getBroadcast(
            this, 1, prevIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val nextIntent = Intent(this, RadioLockscreenReceiver::class.java).apply { action = ACTION_NEXT }
        val nextPending = PendingIntent.getBroadcast(
            this, 2, nextIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val talkIntent = Intent(this, RadioLockscreenReceiver::class.java).apply { action = ACTION_TALK }
        val talkPending = PendingIntent.getBroadcast(
            this, 3, talkIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val artwork = generateRadioArtwork(currentTicker, currentFreq, isTransmitting, isBusy)

        // Update MediaSession with album art and metadata for Spotify-style lockscreen promotion
        val playbackState = PlaybackStateCompat.Builder()
            .setActions(
                PlaybackStateCompat.ACTION_PLAY or
                PlaybackStateCompat.ACTION_PAUSE or
                PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS or
                PlaybackStateCompat.ACTION_SKIP_TO_NEXT
            )
            .setState(
                if (isTransmitting) PlaybackStateCompat.STATE_PLAYING else PlaybackStateCompat.STATE_PAUSED,
                PlaybackStateCompat.PLAYBACK_POSITION_UNKNOWN,
                1.0f
            )
            .build()
        mediaSession?.setPlaybackState(playbackState)

        val metadata = MediaMetadataCompat.Builder()
            .putString(MediaMetadataCompat.METADATA_KEY_TITLE, currentTicker)
            .putString(MediaMetadataCompat.METADATA_KEY_ARTIST, "STATIC RADIO • $currentFreq")
            .putString(MediaMetadataCompat.METADATA_KEY_ALBUM, if (isTransmitting) "TRANSMITTING" else "STANDBY")
            .putBitmap(MediaMetadataCompat.METADATA_KEY_ALBUM_ART, artwork)
            .putBitmap(MediaMetadataCompat.METADATA_KEY_ART, artwork)
            .build()
        mediaSession?.setMetadata(metadata)

        val statusText = when {
            isTransmitting -> "🔴 Transmitting on $currentFreq"
            isBusy -> "🟡 Channel Occupied ($currentFreq)"
            else -> "🟢 Monitoring $currentFreq"
        }

        val talkButtonText = when {
            isTransmitting -> "⏹ STOP"
            isBusy -> "🔒 BUSY"
            else -> "🎙️ TRANSMIT"
        }

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(currentTicker)
            .setContentText(statusText)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setLargeIcon(artwork)
            .setContentIntent(launchPendingIntent)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .addAction(android.R.drawable.ic_media_previous, "◀ PREV", prevPending)
            .addAction(
                if (isTransmitting) android.R.drawable.ic_media_pause else android.R.drawable.ic_btn_speak_now,
                talkButtonText,
                talkPending
            )
            .addAction(android.R.drawable.ic_media_next, "NEXT ▶", nextPending)
            .setStyle(
                androidx.media.app.NotificationCompat.MediaStyle()
                    .setMediaSession(mediaSession?.sessionToken)
                    .setShowActionsInCompactView(0, 1, 2)
            )
            .build()
    }

    override fun onDestroy() {
        mediaSession?.release()
        mediaSession = null
        instance = null
        super.onDestroy()
    }
}
