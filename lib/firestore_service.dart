import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'device_fingerprint.dart';
import 'main.dart';
import 'platform/platform.dart';

class FirestoreService {
  static FirebaseFirestore? _instance;
  static String? _sharedCollectionId;
  static const MethodChannel _channel =
      MethodChannel('com.makeitsimple.we_plan/calendar_widget');

  /// Number of months after event date before auto-deletion
  static const int expirationMonths = 6;

  static FirebaseFirestore get instance {
    _instance ??= FirebaseFirestore.instanceFor(
      app: Firebase.app(),
      databaseId: 'we-plan',
    );
    return _instance!;
  }

  static String get shareCode =>
      _sharedCollectionId?.replaceFirst('shared_', '') ?? '';

  static Future<void> initialize({String? shareCode}) async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      _sharedCollectionId = shareCode != null
          ? 'shared_$shareCode'
          : 'shared_${DateTime.now().millisecondsSinceEpoch}';

      print(
        "FirestoreService initialized with collection: $_sharedCollectionId",
      );
    } catch (e) {
      print("Error initializing FirestoreService: $e");
      rethrow;
    }
  }

  /// Calculate expiration date (event date + 6 months)
  static DateTime _calculateExpiresAt(DateTime eventDate) {
    return DateTime(
      eventDate.year,
      eventDate.month + expirationMonths,
      eventDate.day,
    );
  }

  static Future<void> addEvent({
    required String title,
    required String description,
    required DateTime date,
    String? fingerprint,
    String? deviceName,
    int? colorValue,
    int? startTimeHour,
    int? startTimeMinute,
    int? endTimeHour,
    int? endTimeMinute,
  }) async {
    // Calculate expiration date (event date + 6 months)
    final expiresAt = _calculateExpiresAt(date);

    try {
      final fingerprint = await DeviceFingerprint.generate();
      final prefs = await SharedPreferences.getInstance();
      final deviceName =
          prefs.getString('device_name') ?? fingerprint.substring(0, 8);
      final colorValue = prefs.getInt('color_value') ?? Colors.blue.value;

      await instance.collection(_sharedCollectionId!).add({
        'title': title,
        'description': description,
        'date': date.toIso8601String(),
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(expiresAt), // TTL field for auto-deletion
        'fingerprint': fingerprint,
        'device_name': deviceName,
        'color_value': colorValue,
        'platform': Platform.instance.operatingSystem,
        'start_time_hour': startTimeHour,
        'start_time_minute': startTimeMinute,
        'end_time_hour': endTimeHour,
        'end_time_minute': endTimeMinute,
      });

      // Update widget after adding an event
      await _updateWidget();
    } catch (e) {
      // Fallback if permissions are denied
      final fallbackName = 'Device-${DateTime.now().millisecondsSinceEpoch}';
      await instance.collection(_sharedCollectionId!).add({
        'title': title,
        'description': description,
        'date': date.toIso8601String(),
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(expiresAt), // TTL field for auto-deletion
        'fingerprint':
            'permission-denied-${DateTime.now().millisecondsSinceEpoch}',
        'platform': Platform.instance.operatingSystem,
        'device_name': fallbackName,
        'start_time_hour': startTimeHour,
        'start_time_minute': startTimeMinute,
        'end_time_hour': endTimeHour,
        'end_time_minute': endTimeMinute,
      });

      // Update widget even in fallback case
      await _updateWidget();
    }
  }

  static Future<String> _getAndroidFingerprint() async {
    final androidInfo = await DeviceInfoPlugin().androidInfo;

    // Use only allowed identifiers
    return sha256
        .convert(
          utf8.encode(
            '${androidInfo.model}-'
            '${androidInfo.version.sdkInt}-'
            '${androidInfo.hardware}-'
            '${androidInfo.device}-'
            '${androidInfo.board}-'
            '${androidInfo.bootloader}',
          ),
        )
        .toString();
  }

  static Future<void> editEvent({
    required String oldTitle,
    required String oldDescription,
    required String newTitle,
    required String newDescription,
    required DateTime date,
  }) async {
    final fingerprint = await DeviceFingerprint.generate();

    final query = await instance
        .collection(_sharedCollectionId!)
        .where('title', isEqualTo: oldTitle)
        .where('description', isEqualTo: oldDescription)
        .where('date', isEqualTo: date.toIso8601String())
        .get();

    for (final doc in query.docs) {
      await doc.reference.update({
        'title': newTitle,
        'description': newDescription,
        'lastModified': FieldValue.serverTimestamp(),
        'modifiedBy': fingerprint, // Track who modified
      });
    }

    // Update widget after editing an event
    await _updateWidget();
  }

  static Stream<QuerySnapshot> getEventsStream(DateTime day) {
    return instance
        .collection(_sharedCollectionId!)
        .where("date", isEqualTo: day.toIso8601String())
        .orderBy("createdAt")
        .snapshots();
  }

  static Future<List<Map<String, dynamic>>> getEventsForDay(
    DateTime day,
  ) async {
    try {
      // Use range query to handle different date string formats
      // Query from start of day to end of day
      final startOfDay = DateTime(day.year, day.month, day.day);
      final endOfDay = DateTime(day.year, day.month, day.day, 23, 59, 59, 999);

      final snapshot = await instance
          .collection(_sharedCollectionId!)
          .where("date", isGreaterThanOrEqualTo: startOfDay.toIso8601String())
          .where("date", isLessThanOrEqualTo: endOfDay.toIso8601String())
          .withConverter<Map<String, dynamic>>(
            fromFirestore: (snapshot, _) =>
                snapshot.data()!..['id'] = snapshot.id,
            toFirestore: (data, _) => data,
          )
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print("Error fetching events: $e");
      rethrow;
    }
  }

  static Future<void> deleteEvent({
    required String title,
    required String description,
    required DateTime date,
  }) async {
    try {
      final snapshot = await instance
          .collection(_sharedCollectionId!)
          .where("title", isEqualTo: title)
          .where("description", isEqualTo: description)
          .where("date", isEqualTo: date.toIso8601String())
          .get();

      for (final doc in snapshot.docs) {
        await doc.reference.delete();
      }

      // Update widget after deleting an event
      await _updateWidget();
    } catch (e) {
      print("Error deleting event: $e");
      rethrow;
    }
  }

  static Future<String?> getShareCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('shareCode');
  }

  static Future<void> updateAllEventColors(int newColorValue) async {
    try {
      final shareCode = await getShareCode();
      if (shareCode == null) return;

      // Get the current device's fingerprint
      final fingerprint = await DeviceFingerprint.generate();

      // Get reference to the events collection for this shared calendar
      final eventsRef = FirebaseFirestore.instance
          .collection('shared_calendars')
          .doc(shareCode)
          .collection('events');

      // Query only events with this device's fingerprint
      final querySnapshot =
          await eventsRef.where('fingerprint', isEqualTo: fingerprint).get();

      // Batch update all matching events
      if (querySnapshot.docs.isNotEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        for (final doc in querySnapshot.docs) {
          batch.update(doc.reference, {'color_value': newColorValue});
        }
        await batch.commit();
        debugPrint('Updated color for ${querySnapshot.docs.length} events');
      }
    } catch (e) {
      debugPrint('Error updating event colors: $e');
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> getEventsForRange(
    DateTime start,
    DateTime end,
  ) async {
    try {
      final snapshot = await instance
          .collection(_sharedCollectionId!)
          .where("date", isGreaterThanOrEqualTo: start.toIso8601String())
          .where("date", isLessThanOrEqualTo: end.toIso8601String())
          .withConverter<Map<String, dynamic>>(
            fromFirestore: (snapshot, _) =>
                snapshot.data()!..['id'] = snapshot.id,
            toFirestore: (data, _) => data,
          )
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print("Error fetching events: $e");
      rethrow;
    }
  }

  static Future validateShareCode(String shareCode) async {
    try {
      final snapshot =
          await instance.collection('shared_$shareCode').limit(1).get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print("Error validating share code: $e");
      return false;
    }
  }

  // Method to update the Android widget
  static Future<void> _updateWidget() async {
    try {
      if (Platform.instance.isAndroid) {
        await _channel.invokeMethod('refreshWidget');
        debugPrint('Widget refresh requested from Dart');
      }
    } catch (e) {
      debugPrint('Error updating widget: $e');
    }
  }

  /// Migrate existing events to add expiresAt field for TTL auto-deletion
  /// This should be called once during app startup
  static Future<void> migrateEventsWithExpiration() async {
    if (_sharedCollectionId == null) {
      debugPrint('FirestoreService not initialized, skipping migration');
      return;
    }

    try {
      // Check if migration already done
      final prefs = await SharedPreferences.getInstance();
      final migrationKey = 'ttl_migration_${_sharedCollectionId}';
      if (prefs.getBool(migrationKey) == true) {
        debugPrint('TTL migration already completed for $_sharedCollectionId');
        return;
      }

      debugPrint('Starting TTL migration for $_sharedCollectionId...');

      // Get all events without expiresAt field
      final snapshot = await instance
          .collection(_sharedCollectionId!)
          .get();

      int migratedCount = 0;
      final batch = instance.batch();

      for (final doc in snapshot.docs) {
        final data = doc.data();

        // Skip if already has expiresAt
        if (data['expiresAt'] != null) continue;

        // Parse event date
        final dateStr = data['date'] as String?;
        if (dateStr == null) continue;

        try {
          final eventDate = DateTime.parse(dateStr);
          final expiresAt = _calculateExpiresAt(eventDate);

          batch.update(doc.reference, {
            'expiresAt': Timestamp.fromDate(expiresAt),
          });
          migratedCount++;
        } catch (e) {
          debugPrint('Error parsing date for doc ${doc.id}: $e');
        }
      }

      // Commit batch update
      if (migratedCount > 0) {
        await batch.commit();
        debugPrint('✅ Migrated $migratedCount events with expiresAt field');
      } else {
        debugPrint('No events needed migration');
      }

      // Mark migration as complete
      await prefs.setBool(migrationKey, true);

    } catch (e) {
      debugPrint('Error during TTL migration: $e');
    }
  }
}
