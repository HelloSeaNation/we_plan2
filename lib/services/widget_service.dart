import 'dart:io' as io;
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';

class WidgetService {
  static const String _titleKey = 'title';
  static const String _contentKey = 'content';
  static const String _widgetName = 'WePlanWidgetProvider';

  // Check if widget is supported on this platform
  static bool get _isSupported {
    // Widgets are only supported on mobile platforms (Android/iOS)
    if (kIsWeb) return false;
    if (!kIsWeb && io.Platform.isLinux) return false;
    if (!kIsWeb && io.Platform.isWindows) return false;
    if (!kIsWeb && io.Platform.isMacOS) return false;
    return true;
  }

  // Initialize the widget
  static Future<void> initializeWidget() async {
    try {
      // Skip for unsupported platforms
      if (!_isSupported) return;

      await HomeWidget.setAppGroupId('group.com.makeitsimple.we_plan');
      await updateWidget();
    } catch (e) {
      print('Error initializing widget: $e');
    }
  }

  // Update widget with new data
  static Future<void> updateWidget({
    String? title,
    String? content,
    Map<String, List<String>>? eventsByDate,
  }) async {
    try {
      // Skip for unsupported platforms
      if (!_isSupported) return;

      if (title != null) {
        await HomeWidget.saveWidgetData(_titleKey, title);
      }
      if (content != null) {
        await HomeWidget.saveWidgetData(_contentKey, content);
      }
      if (eventsByDate != null) {
        await HomeWidget.saveWidgetData('events_by_date', eventsByDate);
      }

      await HomeWidget.updateWidget(
        androidName: _widgetName,
        iOSName: _widgetName,
      );
    } catch (e) {
      print('Error updating widget: $e');
    }
  }

  // Get current widget data
  static Future<Map<String, dynamic>> getWidgetData() async {
    try {
      // Return empty data for unsupported platforms
      if (!_isSupported) {
        return {
          'title': 'WePlan',
          'content': 'No data available',
          'events_by_date': {},
        };
      }

      final content = await HomeWidget.getWidgetData<String>(_contentKey) ??
          'No data available';
      final eventsByDate =
          await HomeWidget.getWidgetData<Map<String, List<String>>>(
                  'events_by_date') ??
              {};

      return {
        'content': content,
        'events_by_date': eventsByDate,
      };
    } catch (e) {
      print('Error getting widget data: $e');
      return {
        'title': 'WePlan',
        'content': 'No data available',
        'events_by_date': {},
      };
    }
  }

  // Get today's and upcoming events for the widget
  static Future<void> updateWidgetEvents(
      List<String> todayEvents, List<String> nextEvents) async {
    // Skip for unsupported platforms
    if (!_isSupported) return;

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final eventsByDate = {
      today: todayEvents,
      'next_events': nextEvents,
    };

    final content = [
      ...todayEvents,
      if (nextEvents.isNotEmpty) '\nUpcoming Events:',
      ...nextEvents,
    ].join('\n');

    await updateWidget(
      content: content.isEmpty ? 'No events scheduled' : content,
      eventsByDate: eventsByDate,
    );
  }
}
