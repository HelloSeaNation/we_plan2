package com.makeitsimple.we_plan

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import com.makeitsimple.we_plan.R
import es.antonborri.home_widget.HomeWidgetPlugin
import kotlinx.coroutines.*

class WePlanBackgroundService : Service() {
    private val serviceScope = CoroutineScope(Dispatchers.Default + Job())
    private var isRunning = false

    override fun onCreate() {
        super.onCreate()
        startForeground()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (!isRunning) {
            isRunning = true
            startBackgroundTask()
        }
        return START_STICKY
    }

    private fun startForeground() {
        // Create a notification channel for Android O and above
        val channelId = "we_plan_widget_service"
        val channelName = "WePlan Widget Service"
        val notificationManager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                channelName,
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "WePlan Widget Background Service"
                setShowBadge(false)
            }
            notificationManager.createNotificationChannel(channel)
        }

        // Create a notification
        val notification = NotificationCompat.Builder(this, channelId)
            .setContentTitle("WePlan Widget")
            .setContentText("Widget service is running")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .build()

        startForeground(1, notification)
    }

    private fun startBackgroundTask() {
        serviceScope.launch {
            while (isRunning) {
                try {
                    // Use the new forceWidgetUpdate method for more consistent refreshing
                    WePlanWidgetProvider.forceWidgetUpdate(this@WePlanBackgroundService)
                    
                    // Wait for 15 minutes before next update
                    delay(15 * 60 * 1000L)
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        isRunning = false
        serviceScope.cancel()
    }

    override fun onBind(intent: Intent?): IBinder? = null
} 