package com.makeitsimple.we_plan

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import android.app.PendingIntent
import android.os.Build
import android.content.ComponentName
import android.content.SharedPreferences
import android.graphics.Color
import android.view.Gravity
import android.view.View
import android.widget.GridLayout
import android.widget.TextView
import java.text.SimpleDateFormat
import java.util.*
import android.app.AlarmManager
import android.util.Log
import android.graphics.Typeface
import com.makeitsimple.we_plan.R

/**
 * Implementation of App Widget functionality.
 * This widget displays a calendar with upcoming events.
 */
class CalendarWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        // There may be multiple widgets active, so update all of them
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
        
        // Schedule the next update at midnight
        scheduleNextMidnightUpdate(context)
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        // When widget is first added, schedule the midnight update
        scheduleNextMidnightUpdate(context)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        
        when (intent.action) {
            REFRESH_ACTION -> {
                val appWidgetManager = AppWidgetManager.getInstance(context)
                val appWidgetIds = appWidgetManager.getAppWidgetIds(
                    ComponentName(context, CalendarWidgetProvider::class.java)
                )
                onUpdate(context, appWidgetManager, appWidgetIds)
            }
            MIDNIGHT_UPDATE_ACTION -> {
                // This is called when the midnight alarm triggers
                Log.d("CalendarWidget", "Midnight update triggered")
                val appWidgetManager = AppWidgetManager.getInstance(context)
                val appWidgetIds = appWidgetManager.getAppWidgetIds(
                    ComponentName(context, CalendarWidgetProvider::class.java)
                )
                onUpdate(context, appWidgetManager, appWidgetIds)
                
                // Schedule the next midnight update
                scheduleNextMidnightUpdate(context)
            }
            Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED -> {
                // Re-schedule alarms after device reboot or app update
                Log.d("CalendarWidget", "Boot completed or package replaced, rescheduling updates")
                scheduleNextMidnightUpdate(context)
                
                // Also trigger an immediate update
                val appWidgetManager = AppWidgetManager.getInstance(context)
                val appWidgetIds = appWidgetManager.getAppWidgetIds(
                    ComponentName(context, CalendarWidgetProvider::class.java)
                )
                onUpdate(context, appWidgetManager, appWidgetIds)
            }
        }
    }

    companion object {
        const val REFRESH_ACTION = "com.makeitsimple.we_plan.REFRESH_WIDGET"
        const val MIDNIGHT_UPDATE_ACTION = "com.makeitsimple.we_plan.MIDNIGHT_UPDATE"
        private const val DAY_CELL_ID_PREFIX = 1000 // Base ID for day cells
        private const val MIDNIGHT_UPDATE_REQUEST_CODE = 0
        
        // Method to schedule the next midnight update
        private fun scheduleNextMidnightUpdate(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            
            // Create a calendar for midnight tonight
            val midnight = Calendar.getInstance().apply {
                add(Calendar.DAY_OF_YEAR, 1) // tomorrow
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 5) // Add a few seconds to ensure it's after midnight
                set(Calendar.MILLISECOND, 0)
            }
            
            // Create a pending intent for the alarm
            val intent = Intent(context, CalendarWidgetProvider::class.java).apply {
                action = MIDNIGHT_UPDATE_ACTION
            }
            
            val pendingIntent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.getBroadcast(
                    context,
                    MIDNIGHT_UPDATE_REQUEST_CODE,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
            } else {
                PendingIntent.getBroadcast(
                    context,
                    MIDNIGHT_UPDATE_REQUEST_CODE,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT
                )
            }
            
            // Schedule the alarm
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                // For Marshmallow and above, use setExactAndAllowWhileIdle to ensure it fires even in Doze mode
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    midnight.timeInMillis,
                    pendingIntent
                )
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
                // For KitKat to Lollipop
                alarmManager.setExact(
                    AlarmManager.RTC_WAKEUP,
                    midnight.timeInMillis,
                    pendingIntent
                )
            } else {
                // For older versions
                alarmManager.set(
                    AlarmManager.RTC_WAKEUP,
                    midnight.timeInMillis,
                    pendingIntent
                )
            }
            
            Log.d("CalendarWidget", "Scheduled next midnight update for: ${SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault()).format(midnight.time)}")
        }
        
        // Method to force a widget update from outside the widget provider
        fun forceWidgetUpdate(context: Context) {
            val intent = Intent(context, CalendarWidgetProvider::class.java)
            intent.action = REFRESH_ACTION
            context.sendBroadcast(intent)
        }

        // Method to update a single widget
        internal fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val views = RemoteViews(context.packageName, R.layout.calendar_widget)
            
            // Set up a click intent to launch the main activity
            val intent = Intent(context, MainActivity::class.java)
            val pendingIntent = PendingIntent.getActivity(context, 0, intent, PendingIntent.FLAG_IMMUTABLE)
            views.setOnClickPendingIntent(R.id.calendar_grid, pendingIntent)
            
            // Also set click intent on the entire widget
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)
            
            // Set up current month and year
            val calendar = Calendar.getInstance()
            val monthFormat = SimpleDateFormat("MMMM yyyy", Locale.getDefault())
            views.setTextViewText(R.id.widget_month, monthFormat.format(calendar.time))
            
            // Get current date for today's highlight
            val todayDate = calendar.get(Calendar.DAY_OF_MONTH)
            val todayMonth = calendar.get(Calendar.MONTH)
            val todayYear = calendar.get(Calendar.YEAR)
            
            // Set today's date prominently
            val todayDateFormat = SimpleDateFormat("EEEE, MMMM d", Locale.getDefault())
            // Use getIdentifier to avoid unresolved references
            val todayDateId = context.resources.getIdentifier("today_date", "id", context.packageName)
            if (todayDateId != 0) {
                views.setTextViewText(todayDateId, todayDateFormat.format(calendar.time))
            } else {
                Log.e("CalendarWidget", "today_date view not found")
            }
            
            // Get events from storage
            val prefs = context.getSharedPreferences("CalendarWidgetPrefs", Context.MODE_PRIVATE)
            
            // Get today's events specifically
            val todayDateKey = formatDateKey(todayYear, todayMonth, todayDate)
            val todayEventTitle = prefs.getString("event_title_$todayDateKey", null)
            
            // Get the event_title and no_events_text IDs using getIdentifier
            val eventTitleId = R.id.event_title // This ID should exist
            val noEventsTextId = context.resources.getIdentifier("no_events_text", "id", context.packageName)
            
            // Update event information
            if (todayEventTitle != null && todayEventTitle.isNotEmpty()) {
                views.setTextViewText(eventTitleId, todayEventTitle)
                views.setViewVisibility(eventTitleId, View.VISIBLE)
                
                // Only try to use no_events_text if the ID was found
                if (noEventsTextId != 0) {
                    views.setTextViewText(noEventsTextId, "")
                    views.setViewVisibility(noEventsTextId, View.GONE)
                }
            } else {
                // No events today
                if (noEventsTextId != 0) {
                    // If no_events_text ID exists, use it
                    views.setTextViewText(noEventsTextId, "No events today")
                    views.setViewVisibility(noEventsTextId, View.VISIBLE)
                    views.setTextViewText(eventTitleId, "")
                    views.setViewVisibility(eventTitleId, View.GONE)
                } else {
                    // Otherwise fallback to using the event_title view
                    views.setTextViewText(eventTitleId, "No events today")
                    views.setViewVisibility(eventTitleId, View.VISIBLE)
                }
            }
            
            // Set last updated time
            val dateFormat = SimpleDateFormat("MM/dd HH:mm", Locale.getDefault())
            views.setTextViewText(R.id.last_updated, "Updated: ${dateFormat.format(Date())}")
            
            // Clear all day cells first
            clearAllDayCells(context, views)
            
            // Update the calendar days
            populateCalendarDays(context, views, calendar, prefs)
            
            // Instruct the widget manager to update the widget
            appWidgetManager.updateAppWidget(appWidgetId, views)
            
            // Log today's date for debugging
            Log.d("CalendarWidget", "Widget updated with today's date: $todayDate/$todayMonth/$todayYear")
        }
        
        // Helper method to clear all day cells
        private fun clearAllDayCells(context: Context, views: RemoteViews) {
            // For each day cell in the calendar grid
            for (row in 1..6) {
                for (col in 0..6) {
                    val dayViewId = context.resources.getIdentifier(
                        "day_${row}_${col}", "id", context.packageName
                    )
                    if (dayViewId != 0) {
                        // Clear any text
                        views.setTextViewText(dayViewId, "")
                        // Reset text color
                        views.setTextColor(dayViewId, Color.WHITE)
                        // Reset text size
                        views.setFloat(dayViewId, "setTextSize", 14f)
                    }
                }
            }
        }
        
        // Helper method to populate the calendar days
        private fun populateCalendarDays(
            context: Context, 
            views: RemoteViews, 
            calendar: Calendar,
            prefs: SharedPreferences
        ) {
            // First, make a copy of the calendar to avoid modifying the original
            val calCopy = calendar.clone() as Calendar
            
            // Get the current month days
            val currentMonth = calCopy.get(Calendar.MONTH)
            val currentYear = calCopy.get(Calendar.YEAR)
            val currentDay = calCopy.get(Calendar.DAY_OF_MONTH)
            
            // Get the first day of the month
            val firstDayOfMonth = Calendar.getInstance()
            firstDayOfMonth.set(Calendar.YEAR, currentYear)
            firstDayOfMonth.set(Calendar.MONTH, currentMonth)
            firstDayOfMonth.set(Calendar.DAY_OF_MONTH, 1)

            // Get the day of the week for the first day of the month
            val firstDayOfWeek = firstDayOfMonth.get(Calendar.DAY_OF_WEEK)

            // Calculate the offset for Monday as the first day of the week
            val offset = if (firstDayOfWeek == Calendar.SUNDAY) 6 else firstDayOfWeek - 2
            
            // Get the maximum days in the month
            val maxDaysInMonth = calCopy.getActualMaximum(Calendar.DAY_OF_MONTH)
            
            // Start from day 1 and fill in the calendar
            var dayOfMonth = 1
            
            // Create a view for each day of the month
            // Loop through 6 rows (maximum possible rows in a month view)
            for (row in 1..6) {
                // Loop through each day of the week
                for (col in 0..6) {
                    // Get the day view ID
                    val dayViewId = context.resources.getIdentifier(
                        "day_${row}_${col}", "id", context.packageName
                    )
                    
                    if (dayViewId != 0) {
                        // Calculate if this position should have a day number
                        if ((row == 1 && col < offset) || dayOfMonth > maxDaysInMonth) {
                            // Empty cell
                            views.setTextViewText(dayViewId, "")
                        } else {
                            // Format the day number text
                            val dateKey = formatDateKey(currentYear, currentMonth, dayOfMonth)
                            val hasEvents = prefs.getBoolean("has_events_$dateKey", false)
                            val eventTitle = if (hasEvents) {
                                prefs.getString("event_title_$dateKey", "") ?: ""
                            } else {
                                ""
                            }
                            
                            // Create a combined display text that includes day number and event title
                            val displayText = if (eventTitle.isNotEmpty()) {
                                "$dayOfMonth\n$eventTitle"
                            } else {
                                dayOfMonth.toString()
                            }
                            
                            // Set the combined day and event text
                            views.setTextViewText(dayViewId, displayText)
                            
                            // Highlight current day with a more prominent style
                            if (dayOfMonth == currentDay) {
                                // Use a brighter, more noticeable color for today
                                views.setTextColor(dayViewId, Color.parseColor("#FF5722")) // Bright orange
                                // Make today's date slightly larger than other dates
                                views.setFloat(dayViewId, "setTextSize", 16f)
                                // Set text style to bold for today
                                views.setInt(dayViewId, "setTypeface", Typeface.BOLD)
                                
                                // Set background for today's cell if possible
                                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                                    views.setInt(dayViewId, "setBackgroundResource", R.drawable.today_background)
                                }
                            } else if (hasEvents) {
                                // If the day has events, use a different style
                                views.setTextColor(dayViewId, Color.parseColor("#FF2196F3")) // Blue for event days
                                views.setFloat(dayViewId, "setTextSize", 12f)
                                // Normal weight for other days with events
                                views.setInt(dayViewId, "setTypeface", Typeface.NORMAL)
                            } else {
                                // Regular day style
                                views.setTextColor(dayViewId, Color.parseColor("#FFCCCCCC")) // Regular days
                                views.setFloat(dayViewId, "setTextSize", 12f)
                                // Normal weight for regular days
                                views.setInt(dayViewId, "setTypeface", Typeface.NORMAL)
                            }
                            
                            dayOfMonth++
                        }
                    }
                }
            }
        }
        
        // Helper method to format date as a key for SharedPreferences
        private fun formatDateKey(year: Int, month: Int, day: Int): String {
            return "$year-${month+1}-$day" // Month is 0-indexed in Calendar
        }
    }
} 