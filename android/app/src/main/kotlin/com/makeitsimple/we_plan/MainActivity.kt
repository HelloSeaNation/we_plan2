package com.makeitsimple.we_plan

import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import es.antonborri.home_widget.HomeWidgetPlugin

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.makeitsimple.we_plan/calendar_widget"
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Set up method channel to communicate with Flutter
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "updateCalendarWidget" -> {
                    try {
                        // Get event data from Flutter
                        val eventTitle = call.argument<String>("eventTitle") ?: "No upcoming events"
                        
                        // Get event days data if provided
                        val eventDays = call.argument<Map<String, Boolean>>("eventDays")
                        
                        // Get event titles for specific dates if provided
                        val eventTitles = call.argument<Map<String, String>>("eventTitles")
                        
                        // Store the event data in SharedPreferences
                        updateWidgetData(eventTitle, eventDays, eventTitles)
                        
                        // Force widget update
                        CalendarWidgetProvider.forceWidgetUpdate(this)
                        
                        // Also update the WePlan widget
                        WePlanWidgetProvider.forceWidgetUpdate(this)
                        
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("UPDATE_WIDGET_ERROR", e.message, null)
                    }
                }
                "checkForWidgetSync" -> {
                    // Check if widget needs sync
                    val needsSync = checkIfWidgetNeedsSync()
                    result.success(needsSync)
                }
                "refreshWidget" -> {
                    try {
                        // Manually trigger a widget update
                        Log.d("MainActivity", "Received request to refresh widget from Flutter")
                        
                        // Mark the widget as needing sync
                        val syncPrefs = getSharedPreferences("WidgetSyncPrefs", Context.MODE_PRIVATE)
                        with(syncPrefs.edit()) {
                            putBoolean("needsSync", true)
                            apply()
                        }
                        
                        // Force update both widgets
                        WePlanWidgetProvider.forceWidgetUpdate(this)
                        CalendarWidgetProvider.forceWidgetUpdate(this)
                        
                        Log.d("MainActivity", "Widget refresh completed")
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("MainActivity", "Error refreshing widget: ${e.message}")
                        result.error("REFRESH_WIDGET_ERROR", e.message, null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Check if we need to sync widget data when app starts
        if (checkIfWidgetNeedsSync()) {
            // Force widget updates on app start if needed
            WePlanWidgetProvider.forceWidgetUpdate(this)
        }
    }
    
    private fun updateWidgetData(
        eventTitle: String, 
        eventDays: Map<String, Boolean>?, 
        eventTitles: Map<String, String>?
    ) {
        val prefs = getSharedPreferences("CalendarWidgetPrefs", Context.MODE_PRIVATE)
        val editor = prefs.edit()
        
        // Update event title
        editor.putString("nextEventTitle", eventTitle)
        
        // Update event days data if provided
        eventDays?.forEach { (dateKey, hasEvents) ->
            editor.putBoolean("has_events_$dateKey", hasEvents)
        }
        
        // Update event titles for specific dates if provided
        eventTitles?.forEach { (dateKey, title) ->
            editor.putString("event_title_$dateKey", title)
        }
        
        editor.apply()
        
        // Clear the sync flag
        val syncPrefs = getSharedPreferences("WidgetSyncPrefs", Context.MODE_PRIVATE)
        with(syncPrefs.edit()) {
            putBoolean("needsSync", false)
            apply()
        }
    }
    
    private fun checkIfWidgetNeedsSync(): Boolean {
        val prefs = getSharedPreferences("WidgetSyncPrefs", Context.MODE_PRIVATE)
        return prefs.getBoolean("needsSync", false)
    }
}
