package com.makeitsimple.we_plan

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import com.makeitsimple.we_plan.R
import es.antonborri.home_widget.HomeWidgetPlugin
import java.text.SimpleDateFormat
import java.util.*

class WePlanWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == AppWidgetManager.ACTION_APPWIDGET_UPDATE) {
            // We don't need to explicitly reload data, getData will get the latest
            
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val appWidgetIds = intent.getIntArrayExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS)
                ?: appWidgetManager.getAppWidgetIds(intent.component)
                
            appWidgetIds.forEach { appWidgetId ->
                updateWidget(context, appWidgetManager, appWidgetId)
            }
        } else if (intent.action == "OPEN_APP_ACTION") {
            // Launch the app when open icon is clicked
            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)?.apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
            launchIntent?.let { context.startActivity(it) }
        }
    }

    private fun updateWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        // Get the latest data
        val widgetData = HomeWidgetPlugin.getData(context)
        val views = RemoteViews(context.packageName, R.layout.widget_layout).apply {
            // Set current day and date
            val dayFormat = SimpleDateFormat("EEE", Locale.getDefault())
            val dateFormat = SimpleDateFormat("d", Locale.getDefault())
            val now = Date()
            setTextViewText(R.id.widget_day, dayFormat.format(now))
            setTextViewText(R.id.widget_date, dateFormat.format(now))
            
            // Update widget content
            setTextViewText(R.id.widget_content, widgetData.getString("content", "No data available"))
            
            // Create intent to update widget only (don't launch app)
            val updateIntent = Intent(context, WePlanWidgetProvider::class.java).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, intArrayOf(appWidgetId))
            }
            
            // Create a pending intent for updating the widget
            val updatePendingIntent = android.app.PendingIntent.getBroadcast(
                context,
                appWidgetId,
                updateIntent,
                android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
            )
            
            // Set the update intent to the widget layout (except the open icon)
            setOnClickPendingIntent(R.id.widget_layout, updatePendingIntent)
            
            // Create intent to launch the app
            val openAppIntent = Intent(context, WePlanWidgetProvider::class.java).apply {
                action = "OPEN_APP_ACTION"
            }
            
            // Create a pending intent for launching the app
            val openAppPendingIntent = android.app.PendingIntent.getBroadcast(
                context,
                appWidgetId + 1000, // Use a different request code to avoid conflicts
                openAppIntent,
                android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
            )
            
            // Set the open app intent to the open icon
            setOnClickPendingIntent(R.id.widget_open_app, openAppPendingIntent)
        }

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        // Start the background service
        val serviceIntent = Intent(context, WePlanBackgroundService::class.java)
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            context.startForegroundService(serviceIntent)
        } else {
            context.startService(serviceIntent)
        }
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        // Stop the background service when the last widget is disabled
        context.stopService(Intent(context, WePlanBackgroundService::class.java))
    }
    
    companion object {
        // Helper method to force widget update from other components
        fun forceWidgetUpdate(context: Context) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(android.content.ComponentName(context, WePlanWidgetProvider::class.java))
            
            // Send broadcast to update widgets
            val updateIntent = Intent(context, WePlanWidgetProvider::class.java).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, appWidgetIds)
            }
            context.sendBroadcast(updateIntent)
        }
    }
} 