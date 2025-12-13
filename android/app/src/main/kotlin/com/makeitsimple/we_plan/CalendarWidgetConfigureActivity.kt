package com.makeitsimple.we_plan

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.view.View
import android.widget.Button
import android.widget.EditText
import android.widget.TextView
import android.widget.Toast
import android.content.SharedPreferences
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import com.makeitsimple.we_plan.R

/**
 * The configuration screen for the CalendarWidget AppWidget.
 */
class CalendarWidgetConfigureActivity : Activity() {
    private var appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID

    public override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setResult(RESULT_CANCELED)
        setContentView(R.layout.calendar_widget_configure)

        // Find the widget id from the intent
        val intent = intent
        val extras = intent.extras
        if (extras != null) {
            appWidgetId = extras.getInt(
                AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID
            )
        }

        // If this activity was started with an invalid widget ID, finish
        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }

        // Set up the "Add Widget" button
        val addButton = findViewById<Button>(R.id.add_button)
        addButton.setOnClickListener { 
            // Configure widget and return success
            configureWidget()
            
            // Make sure we pass back the original appWidgetId
            val resultValue = Intent()
            resultValue.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            setResult(RESULT_OK, resultValue)
            finish()
        }
    }

    private fun configureWidget() {
        // Create shared preferences for this widget
        val prefs = getSharedPreferences("CalendarWidgetPrefs", Context.MODE_PRIVATE)
        with(prefs.edit()) {
            putString("nextEventTitle", "Checking your events...")
            apply()
        }

        // Update the widget
        val appWidgetManager = AppWidgetManager.getInstance(this)
        CalendarWidgetProvider.updateAppWidget(this, appWidgetManager, appWidgetId)
        
        // Schedule a sync with the MainActivity to fetch actual events
        // This is a workaround since we can't directly access Flutter data here
        scheduleDataSync()
    }

    private fun scheduleDataSync() {
        // We'll store a flag in SharedPreferences that MainActivity will check on launch
        val prefs = getSharedPreferences("WidgetSyncPrefs", Context.MODE_PRIVATE)
        with(prefs.edit()) {
            putBoolean("needsSync", true)
            putLong("lastSyncRequest", System.currentTimeMillis())
            apply()
        }
        
        // Optionally, start the main activity
        Toast.makeText(this, "Widget added! Open app to sync calendar data.", Toast.LENGTH_SHORT).show()
    }
} 