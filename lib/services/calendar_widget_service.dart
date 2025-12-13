import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class CalendarWidgetService {
  static const MethodChannel _channel = MethodChannel(
    'com.makeitsimple.we_plan/calendar_widget',
  );

  // Singleton instance
  static final CalendarWidgetService _instance =
      CalendarWidgetService._internal();

  factory CalendarWidgetService() {
    return _instance;
  }

  CalendarWidgetService._internal();

  /// Check if the widget needs synchronization
  Future<bool> needsSync() async {
    try {
      // Widget sync is only supported on Android
      if (kIsWeb || !defaultTargetPlatform.isAndroid) {
        return false;
      }

      final bool needsSync = await _channel.invokeMethod('checkForWidgetSync');
      return needsSync;
    } on PlatformException catch (e) {
      debugPrint('Error checking widget sync: ${e.message}');
      return false;
    }
  }

  /// Update the calendar widget with event data
  Future<bool> updateWidget({
    required String eventTitle,
    Map<String, bool>?
        eventDays, // Map of date keys to whether they have events
    Map<String, String>? eventTitles, // Map of date keys to event titles
  }) async {
    try {
      // Skip for web platform or non-Android platforms
      if (kIsWeb || !defaultTargetPlatform.isAndroid) {
        return false;
      }

      // Create a map with all data to pass to the native side
      final Map<String, dynamic> data = {'eventTitle': eventTitle};

      // Add event days data if provided
      if (eventDays != null) {
        data['eventDays'] = eventDays;
      }

      // Add event titles data if provided
      if (eventTitles != null) {
        data['eventTitles'] = eventTitles;
      }

      final bool result = await _channel.invokeMethod(
        'updateCalendarWidget',
        data,
      );
      return result;
    } on PlatformException catch (e) {
      debugPrint('Error updating widget: ${e.message}');
      return false;
    }
  }
}

// Extension to check for Android platform
extension TargetPlatformExtension on TargetPlatform {
  bool get isAndroid => this == TargetPlatform.android;
}
