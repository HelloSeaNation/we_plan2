import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:table_calendar/table_calendar.dart';
import 'device_fingerprint.dart';
import 'firestore_service.dart';
import 'offline_action.dart';
import 'share_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'share_setup_screen.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'package:permission_handler/permission_handler.dart';
import 'settings_page.dart';
import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'event_model.dart';
import 'services/calendar_widget_service.dart';
import 'services/widget_service.dart';
import 'services/kiosk_service.dart';
import 'dart:convert';
import 'platform/platform.dart';
import 'package:flutter/foundation.dart';
import 'utils/responsive.dart';
import 'widgets/responsive_layout.dart';
import 'widgets/centered_container.dart';

String dateText(DateTime date) {
  return normalizeDate(date).toString();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive
  await Hive.initFlutter();
  Hive.registerAdapter(CachedEventAdapter());
  await Hive.openBox<CachedEvent>('events');

  // Load preferences
  final prefs = await SharedPreferences.getInstance();
  final shareCode = prefs.getString('shareCode');
  final isFirstTime = prefs.getBool('first_time') ?? true;

  // Register adapters for offline actions
  Hive.registerAdapter(ActionTypeAdapter());
  Hive.registerAdapter(OfflineActionAdapter());
  await Hive.openBox<OfflineAction>('actionQueue');

  // Initialize Firebase
  await FirestoreService.initialize(shareCode: shareCode);

  // Initialize widget service (will be skipped on web automatically)
  await WidgetService.initializeWidget();

  runApp(
    MaterialApp(
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        // Responsive text themes
        textTheme: const TextTheme(
          // Adjust headline sizes based on device
          headlineLarge: TextStyle(
            fontSize: kIsWeb ? 32 : 24,
            fontWeight: FontWeight.bold,
          ),
          // Make body text slightly larger on web
          bodyLarge: TextStyle(fontSize: kIsWeb ? 16 : 14),
          bodyMedium: TextStyle(fontSize: kIsWeb ? 14 : 12),
        ),
        // Responsive dialog theme
        dialogTheme: DialogThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 8,
        ),
        // Responsive button theme
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(
              horizontal: kIsWeb ? 24 : 16,
              vertical: kIsWeb ? 16 : 12,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        // Add a subtle background color for web/desktop
        scaffoldBackgroundColor: kIsWeb ? Color(0xFFF5F7FA) : null,
      ),
      builder: (context, child) {
        // For web/desktop, only apply centered container on very large screens
        // For tablet-sized screens (like Raspberry Pi), use full width
        final screenWidth = MediaQuery.of(context).size.width;
        if (kIsWeb && screenWidth > 1400) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0),
            child: CenteredContainer(
              maxWidth: 1400,
              padding: EdgeInsets.zero,
              child: child!,
            ),
          );
        }
        return child!;
      },
      home: isFirstTime
          ? const SettingsPage(isFirstTime: true)
          : shareCode == null
          ? const ShareSetupScreen(isFirstTime: false)
          : const MyHomePage(title: '', isFirstLoad: true),
      debugShowCheckedModeBanner: false,
    ),
  );
}

class Event {
  final String id;
  final String title;
  final String description;
  final String? fingerprint;
  final String? deviceName;
  final Color? color;
  final bool isFirstLoad;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;

  Event({
    required this.id,
    required this.title,
    required this.description,
    this.fingerprint,
    this.deviceName,
    this.color,
    this.isFirstLoad = false,
    this.startTime,
    this.endTime,
  });

  // Format time for display
  String get timeString {
    if (startTime == null) return '';
    final start = _formatTime(startTime!);
    if (endTime == null) return start;
    return '$start - ${_formatTime(endTime!)}';
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  @override
  String toString() => title;
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title, this.isFirstLoad = false});
  final String title;
  final bool isFirstLoad;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class DeletedEventInfo {
  final Event event;
  final DateTime day;
  final int index;

  DeletedEventInfo({
    required this.event,
    required this.day,
    required this.index,
  });
}

class _MyHomePageState extends State<MyHomePage> {
  final CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final Map<String, List<Event>> _events = {};
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final Connectivity _connectivity = Connectivity();
  StreamSubscription? _connectivitySubscription;
  bool _isOnline = true;
  DeletedEventInfo? _lastDeletedEventInfo;
  Timer? _deleteTimer;
  Color _themeColor = Colors.blue;
  final CalendarWidgetService _widgetService = CalendarWidgetService();
  static const String _cachedEventsKey = 'cached_events';
  static const String _lastSyncTimestampKey = 'last_sync_timestamp';
  bool _isFirstLoad = true;

  // Events panel visibility (for tablet/desktop sliding panel)
  bool _isEventsPanelVisible = false;

  // Kiosk mode state
  final KioskService _kioskService = KioskService();
  bool _isKioskEnabled = false;
  bool _hideDeleteEdit = false;
  bool _isScreensaverActive = false;
  String _screensaverImageUrl = '';
  bool _useImageFolder = false;
  String _currentSlideshowImage = '';

  @override
  void dispose() {
    _deleteTimer?.cancel();
    _connectivitySubscription?.cancel();
    _titleController.dispose();
    _descController.dispose();
    _kioskService.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _initConnectivity();
    _loadThemeColor();
    _initKioskMode();
    // Create a normalized today date to avoid time component issues
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    setState(() {
      _selectedDay = today;
      _focusedDay = today;
    });
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
      results,
    ) {
      if (results.isNotEmpty) {
        _updateConnectionStatus(results.first);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _checkAndRequestPermissions();

      try {
        // First load the month data for the calendar markers
        if (mounted) {
          await _fetchEventsForVisibleMonth(_focusedDay);

          // Check if widget needs sync and update it
          await _syncWidgetIfNeeded();
        }
      } finally {
        // Dismiss loading indicator
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      }
      // await _onDaySelected(_selectedDay!, _focusedDay);

      // _onDaySelected(today, today);
    });
  }

  // Create a separate method for day selection logic
  Future<void> _onDaySelected(DateTime selectedDay, DateTime focusedDay) async {
    HapticFeedback.selectionClick();
    _onUserActivity(); // Reset kiosk timers
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
      // Show the events panel on tablet/desktop when a day is selected
      final isLargeScreen =
          Responsive.isDesktop(context) || Responsive.isTablet(context);
      if (isLargeScreen) {
        _isEventsPanelVisible = true;
      }
    });
    await _fetchEventsFromFirestore(_selectedDay!);
  }

  // Initialize kiosk mode
  Future<void> _initKioskMode() async {
    await _kioskService.initialize();
    setState(() {
      _isKioskEnabled = _kioskService.isEnabled;
      _hideDeleteEdit = _kioskService.hideDeleteEdit;
      _screensaverImageUrl = _kioskService.screensaverImageUrl;
      _useImageFolder = _kioskService.useFolder;
      _currentSlideshowImage = _kioskService.currentImagePath;
    });

    // Register callbacks
    _kioskService.registerInactivityCallback(_onKioskInactivityTimeout);
    _kioskService.registerScreensaverCallbacks(
      onActivate: _onScreensaverActivate,
      onDeactivate: _onScreensaverDeactivate,
    );
    _kioskService.registerImageChangeCallback(_onSlideshowImageChange);

    // Start timers if kiosk mode is enabled
    if (_isKioskEnabled) {
      _kioskService.startTimers();
    }
  }

  // Called when slideshow image changes
  void _onSlideshowImageChange() {
    if (!mounted) return;
    setState(() {
      _currentSlideshowImage = _kioskService.currentImagePath;
    });
  }

  // Called when user interacts with the app
  void _onUserActivity() {
    if (_isKioskEnabled) {
      _kioskService.onUserActivity();
    }
  }

  // Called when kiosk inactivity timeout is reached
  void _onKioskInactivityTimeout() {
    if (!mounted) return;

    // Return to today's date
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    setState(() {
      _selectedDay = today;
      _focusedDay = today;
    });

    _fetchEventsFromFirestore(today);
    _fetchEventsForVisibleMonth(today);

    debugPrint('Kiosk: Auto-returned to today');
  }

  // Screensaver callbacks
  void _onScreensaverActivate() {
    if (!mounted) return;
    setState(() => _isScreensaverActive = true);
  }

  void _onScreensaverDeactivate() {
    if (!mounted) return;
    setState(() => _isScreensaverActive = false);
  }

  // Reload kiosk settings (called after returning from settings)
  Future<void> _reloadKioskSettings() async {
    await _kioskService.initialize();
    setState(() {
      _isKioskEnabled = _kioskService.isEnabled;
      _hideDeleteEdit = _kioskService.hideDeleteEdit;
      _screensaverImageUrl = _kioskService.screensaverImageUrl;
      _useImageFolder = _kioskService.useFolder;
      _currentSlideshowImage = _kioskService.currentImagePath;
    });

    if (_isKioskEnabled) {
      _kioskService.startTimers();
    } else {
      _kioskService.stopTimers();
      _isScreensaverActive = false;
    }
  }

  Future<String> _getDeviceName() async {
    final prefs = await SharedPreferences.getInstance();
    final fingerprint = await DeviceFingerprint.generate();
    return prefs.getString('device_name') ??
        'Device-${fingerprint.substring(0, 6)}';
  }

  Future<Color> _getDeviceColor() async {
    final prefs = await SharedPreferences.getInstance();
    final colorValue = prefs.getInt('color_value');
    return colorValue != null ? Color(colorValue) : Colors.blue;
  }

  Future<void> _navigateToSettings() async {
    final fingerprint = await DeviceFingerprint.generate();
    final currentName = await _getDeviceName();
    final currentColor = await _getDeviceColor();

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsPage(
          currentDeviceName: currentName,
          deviceFingerprint: fingerprint,
          currentColor: currentColor,
        ),
      ),
    );

    if (result != null) {
      // Reload theme color when returning from settings
      await _loadThemeColor();

      // Reload kiosk settings if they changed
      if (result['kioskSettingsChanged'] == true) {
        await _reloadKioskSettings();
      }

      setState(() {
        // This will refresh the UI with the new color
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Settings saved!')));
    }
  }

  Future<void> _checkAndRequestPermissions() async {
    if (Platform.instance.isAndroid && !kIsWeb) {
      final status = await Permission.phone.status;
      if (!status.isGranted) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Device Identification'),
            content: const Text(
              'To help prevent duplicate entries, we need to identify your device. '
              'This requires the Phone permission to read basic device information.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Deny'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await Platform.instance.requestPermissions();
                },
                child: const Text('Allow'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _loadThemeColor() async {
    final prefs = await SharedPreferences.getInstance();
    final colorValue = prefs.getInt('color_value');
    if (colorValue != null) {
      setState(() {
        _themeColor = Color(colorValue);
      });
    }
  }

  Future<void> _initConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      if (results.isNotEmpty) {
        _updateConnectionStatus(results.first);
      }

      // Load from cache first
      await _loadEventsFromCache();

      if (mounted && _isOnline) {
        // Only fetch from Firestore if it's first load or cache is old
        if (_isFirstLoad) {
          await _fetchEventsForVisibleMonth(_focusedDay);
          await _saveEventsToCache();
          _isFirstLoad = false;
        }
      }
    } catch (e) {
      debugPrint("Connectivity error: $e");
      setState(() => _isOnline = false);
    }
  }

  Future<void> _syncQueuedActions() async {
    final queue = Hive.box<OfflineAction>('actionQueue');

    for (int i = 0; i < queue.length; i++) {
      final action = queue.getAt(i);
      try {
        switch (action!.type) {
          case ActionType.add:
            await FirestoreService.addEvent(
              title: action.data['title'],
              description: action.data['description'],
              date: DateTime.parse(action.data['date']),
              fingerprint: action.data['fingerprint'],
              deviceName: action.data['deviceName'],
              colorValue: action.data['colorValue'],
            );
            break;
          case ActionType.edit:
            await FirestoreService.editEvent(
              oldTitle: action.data['oldTitle'],
              oldDescription: action.data['oldDescription'],
              newTitle: action.data['newTitle'],
              newDescription: action.data['newDescription'],
              date: DateTime.parse(action.data['date']),
            );
            break;
          case ActionType.delete:
            await FirestoreService.deleteEvent(
              title: action.data['title'],
              description: action.data['description'],
              date: DateTime.parse(action.data['date']),
            );
            break;
          default:
            break;
        }
        queue.deleteAt(i);
        i--;
      } catch (e) {
        debugPrint("Failed to sync offline action: $e");
      }
    }
  }

  Future<void> _refreshHiveCacheFromFirestore() async {
    final start = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final end = DateTime(_focusedDay.year, _focusedDay.month + 1, 0);

    try {
      final firestoreEvents = await FirestoreService.getEventsForRange(
        start,
        end,
      );
      final eventsBox = Hive.box<CachedEvent>('events');

      // Remove all local events in this range
      final keysToDelete = eventsBox.keys.where((key) {
        final event = eventsBox.get(key);
        if (event == null) return false;
        final date = DateFormat('yyyy-MM-dd').parse(event.date);
        return date.isAfter(start.subtract(const Duration(days: 1))) &&
            date.isBefore(end.add(const Duration(days: 1)));
      }).toList();

      for (final key in keysToDelete) {
        await eventsBox.delete(key);
      }

      // Add fresh Firestore events
      for (final data in firestoreEvents) {
        final cached = CachedEvent(
          id: data['id'],
          title: data['title'],
          description: data['description'],
          date: data['date'],
          fingerprint: data['fingerprint'],
          deviceName: data['device_name'],
          colorValue: data['color_value'],
        );
        await eventsBox.put(cached.id, cached);
      }

      debugPrint('📦 Hive cache refreshed with latest Firestore data');
    } catch (e) {
      debugPrint('Failed to refresh cache from Firestore: $e');
    }
  }

  void _updateConnectionStatus(ConnectivityResult result) async {
    final isNowOnline = result != ConnectivityResult.none;

    if (isNowOnline != _isOnline) {
      setState(() {
        _isOnline = isNowOnline;
      });

      if (isNowOnline) {
        debugPrint('✅ Back online. Syncing data...');
        await _syncQueuedActions(); // your offline queue
        await _refreshHiveCacheFromFirestore(); // 🔥 NEW!
        await _fetchEventsForVisibleMonth(_focusedDay);
      } else {
        _showOfflineWarning();
      }
    }
  }

  void _showOfflineWarning() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          icon: const Icon(Icons.wifi_off_rounded, color: Colors.red, size: 36),
          title: const Text(
            'You\'re Offline',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Your device is not connected to the internet. You can still view existing events, but changes won\'t sync until you\'re back online.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                minimumSize: const Size(100, 40),
                textStyle: const TextStyle(fontWeight: FontWeight.w500),
                foregroundColor: _themeColor,
              ),
              child: const Text('Got it'),
            ),
          ],
          actionsPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      );
    });
  }

  List<Event> _getEventsForDay(DateTime day) {
    var x = _events[dateText(day)];
    return x ?? [];
  }

  void _showEditEventDialog(Event oldEvent) {
    final TextEditingController editTitleController = TextEditingController(
      text: oldEvent.title,
    );
    final TextEditingController editDescController = TextEditingController(
      text: oldEvent.description,
    );

    // Calculate responsive dialog width based on screen size
    final dialogWidth = Responsive.getResponsiveValue(
      context: context,
      mobile: Responsive.width(context) * 0.9,
      tablet: Responsive.width(context) * 0.7,
      desktop: Responsive.width(context) * 0.4,
    );

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Center(
        child: Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          // Set the width constraint for larger screens
          child: Container(
            width: dialogWidth,
            constraints: BoxConstraints(maxWidth: 600),
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Dialog title
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 24,
                          decoration: BoxDecoration(
                            color: _themeColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Edit Event',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Dialog content
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat(
                            'EEEE, MMMM d, yyyy',
                          ).format(_selectedDay!),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: editTitleController,
                          decoration: InputDecoration(
                            labelText: 'Event',
                            labelStyle: TextStyle(color: _themeColor),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: _themeColor,
                                width: 1.5,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: _themeColor,
                                width: 2,
                              ),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                            focusColor: _themeColor,
                          ),
                          maxLines: 3,
                          autofocus: true,
                          textCapitalization: TextCapitalization.sentences,
                          cursorColor: _themeColor,
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),

                  // Dialog actions
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                          label: const Text('Cancel'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final newTitle = editTitleController.text.trim();
                            final newDesc = editDescController.text.trim();

                            if (_selectedDay == null || newTitle.isEmpty)
                              return;

                            final newEvent = Event(
                              id: oldEvent.id,
                              title: newTitle,
                              description: newDesc,
                              fingerprint: oldEvent.fingerprint,
                              deviceName: oldEvent.deviceName,
                              color: oldEvent.color,
                            );

                            // Close the edit dialog
                            Navigator.pop(context);

                            // Update local UI
                            setState(() {
                              final index = _events[dateText(_selectedDay!)]!
                                  .indexWhere(
                                    (e) =>
                                        e.title == oldEvent.title &&
                                        e.description == oldEvent.description,
                                  );
                              if (index != -1) {
                                _events[dateText(_selectedDay!)]![index] =
                                    newEvent;
                              }
                            });

                            // Update Hive cache
                            final eventsBox = Hive.box<CachedEvent>('events');
                            final key = eventsBox.keys.firstWhere((k) {
                              final e = eventsBox.get(k);
                              return e?.title == oldEvent.title &&
                                  e?.description == oldEvent.description &&
                                  e?.date == dateText(_selectedDay!);
                            }, orElse: () => null);

                            if (key != null) {
                              final cached = eventsBox.get(key);
                              cached!
                                ..title = newTitle
                                ..description = newDesc;
                              await cached.save();
                            }

                            if (_isOnline) {
                              try {
                                await FirestoreService.editEvent(
                                  oldTitle: oldEvent.title,
                                  oldDescription: oldEvent.description,
                                  newTitle: newTitle,
                                  newDescription: newDesc,
                                  date: _selectedDay!,
                                );
                                Navigator.of(
                                  context,
                                ).pop(true); // Pass 'true' to indicate success
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to update event: $e'),
                                  ),
                                );
                              }
                            } else {
                              // Queue edit for later sync
                              final queue = Hive.box<OfflineAction>(
                                'actionQueue',
                              );
                              queue.add(
                                OfflineAction(
                                  type: ActionType.edit,
                                  data: {
                                    'oldTitle': oldEvent.title,
                                    'oldDescription': oldEvent.description,
                                    'newTitle': newTitle,
                                    'newDescription': newDesc,
                                    'date': _selectedDay!.toIso8601String(),
                                  },
                                ),
                              );

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Edit saved offline."),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.check),
                          label: const Text('Save'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _themeColor,
                            foregroundColor: Colors.white,
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAddEventDialog() {
    final formKey = GlobalKey<FormState>();
    TimeOfDay? startTime;
    TimeOfDay? endTime;

    // Calculate responsive dialog width based on screen size
    final dialogWidth = Responsive.getResponsiveValue(
      context: context,
      mobile: Responsive.width(context) * 0.9,
      tablet: Responsive.width(context) * 0.7,
      desktop: Responsive.width(context) * 0.4,
    );
    final isLargeScreen =
        Responsive.isDesktop(context) || Responsive.isTablet(context);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Center(
          child: Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
            ),
            // Set the width constraint for larger screens
            child: Container(
              width: dialogWidth,
              constraints: BoxConstraints(maxWidth: 600),
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Dialog title
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Icon(
                            Icons.event_available,
                            color: _themeColor,
                            size: isLargeScreen ? 28 : 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Add Event',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: isLargeScreen ? 20 : 16,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Dialog content
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Form(
                        key: formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat(
                                'EEEE, MMMM d, yyyy',
                              ).format(_selectedDay!),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: isLargeScreen ? 16 : 14,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _titleController,
                              style: TextStyle(
                                fontSize: isLargeScreen ? 18 : 16,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Event title',
                                labelStyle: TextStyle(
                                  fontSize: isLargeScreen ? 16 : 14,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: Colors.grey[50],
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: isLargeScreen ? 16 : 12,
                                ),
                              ),
                              validator: (value) =>
                                  value == null || value.isEmpty
                                  ? 'Please enter an event title'
                                  : null,
                              autofocus: true,
                              textCapitalization: TextCapitalization.sentences,
                            ),
                            const SizedBox(height: 16),
                            // Time selection row
                            Row(
                              children: [
                                Expanded(
                                  child: _buildTimeSelector(
                                    context: context,
                                    label: 'Start Time',
                                    time: startTime,
                                    isLargeScreen: isLargeScreen,
                                    onTap: () async {
                                      final picked = await showTimePicker(
                                        context: context,
                                        initialTime:
                                            startTime ?? TimeOfDay.now(),
                                      );
                                      if (picked != null) {
                                        setDialogState(
                                          () => startTime = picked,
                                        );
                                      }
                                    },
                                    onClear: () =>
                                        setDialogState(() => startTime = null),
                                  ),
                                ),
                                SizedBox(width: isLargeScreen ? 16 : 12),
                                Expanded(
                                  child: _buildTimeSelector(
                                    context: context,
                                    label: 'End Time',
                                    time: endTime,
                                    isLargeScreen: isLargeScreen,
                                    onTap: () async {
                                      final picked = await showTimePicker(
                                        context: context,
                                        initialTime:
                                            endTime ??
                                            startTime ??
                                            TimeOfDay.now(),
                                      );
                                      if (picked != null) {
                                        setDialogState(() => endTime = picked);
                                      }
                                    },
                                    onClear: () =>
                                        setDialogState(() => endTime = null),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Dialog actions
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: () => Navigator.pop(context),
                            icon: Icon(
                              Icons.close,
                              size: isLargeScreen ? 22 : 18,
                            ),
                            label: Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: isLargeScreen ? 16 : 14,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.grey[700],
                              padding: EdgeInsets.symmetric(
                                horizontal: isLargeScreen ? 20 : 16,
                                vertical: isLargeScreen ? 12 : 8,
                              ),
                            ),
                          ),
                          SizedBox(width: isLargeScreen ? 12 : 8),
                          ElevatedButton.icon(
                            onPressed: () {
                              if (formKey.currentState!.validate()) {
                                if (_selectedDay != null) {
                                  final newEvent = Event(
                                    title: _titleController.text,
                                    description: _descController.text,
                                    id: '',
                                    startTime: startTime,
                                    endTime: endTime,
                                  );
                                  _addEventToFirestore(newEvent);
                                  _titleController.clear();
                                  _descController.clear();
                                  Navigator.pop(context);
                                }
                              }
                            },
                            icon: Icon(
                              Icons.done,
                              size: isLargeScreen ? 22 : 18,
                            ),
                            label: Text(
                              'Save',
                              style: TextStyle(
                                fontSize: isLargeScreen ? 16 : 14,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _themeColor,
                              foregroundColor: Colors.white,
                              elevation: 2,
                              padding: EdgeInsets.symmetric(
                                horizontal: isLargeScreen ? 24 : 16,
                                vertical: isLargeScreen ? 12 : 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Helper widget for time selection
  Widget _buildTimeSelector({
    required BuildContext context,
    required String label,
    required TimeOfDay? time,
    required bool isLargeScreen,
    required VoidCallback onTap,
    required VoidCallback onClear,
  }) {
    final hasTime = time != null;
    final displayText = hasTime
        ? '${time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod}:${time.minute.toString().padLeft(2, '0')} ${time.period == DayPeriod.am ? 'AM' : 'PM'}'
        : 'Optional';

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(12),
      splashFactory: InkRipple.splashFactory,
      splashColor: _themeColor.withOpacity(0.3),
      highlightColor: _themeColor.withOpacity(0.1),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isLargeScreen ? 16 : 12,
          vertical: isLargeScreen ? 20 : 12,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey[50],
        ),
        child: Row(
          children: [
            Icon(
              Icons.access_time,
              size: isLargeScreen ? 24 : 18,
              color: hasTime ? _themeColor : Colors.grey[400],
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: isLargeScreen ? 12 : 10,
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    displayText,
                    style: TextStyle(
                      fontSize: isLargeScreen ? 16 : 14,
                      color: hasTime ? Colors.black87 : Colors.grey[400],
                      fontWeight: hasTime ? FontWeight.w500 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            if (hasTime)
              GestureDetector(
                onTap: onClear,
                child: Icon(Icons.close, size: 18, color: Colors.grey[400]),
              ),
          ],
        ),
      ),
    );
  }

  //Firestore methods
  Future<void> _addEventToFirestore(Event event) async {
    if (_selectedDay == null) return;

    final prefs = await SharedPreferences.getInstance();
    final deviceName = prefs.getString('device_name') ?? 'My Device';
    final colorValue = prefs.getInt('color_value') ?? Colors.blue.value;
    final fingerprint = await DeviceFingerprint.generate();

    final cachedEvent = CachedEvent(
      id: DateTime.now().millisecondsSinceEpoch
          .toString(), // temporary local ID
      title: event.title,
      description: event.description,
      date: dateText(_selectedDay!),
      fingerprint: fingerprint,
      deviceName: deviceName,
      colorValue: colorValue,
      startTimeHour: event.startTime?.hour,
      startTimeMinute: event.startTime?.minute,
      endTimeHour: event.endTime?.hour,
      endTimeMinute: event.endTime?.minute,
    );

    if (_isOnline) {
      try {
        await FirestoreService.addEvent(
          title: event.title,
          description: event.description,
          date: _selectedDay!,
          fingerprint: fingerprint,
          deviceName: deviceName,
          colorValue: colorValue,
          startTimeHour: event.startTime?.hour,
          startTimeMinute: event.startTime?.minute,
          endTimeHour: event.endTime?.hour,
          endTimeMinute: event.endTime?.minute,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Event added successfully!")),
        );
        await _fetchEventsFromFirestore(_selectedDay!);
        await _saveEventsToCache(); // Save to cache after adding
        await _updateWidgetWithLatestEvents();
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed to add event: $e")));
      }
    } else {
      // ✅ 1. Queue the action
      final queue = Hive.box<OfflineAction>('actionQueue');
      queue.add(
        OfflineAction(
          type: ActionType.add,
          data: {
            'title': event.title,
            'description': event.description,
            'date': _selectedDay!.toIso8601String(),
            'fingerprint': fingerprint,
            'deviceName': deviceName,
            'colorValue': colorValue,
          },
        ),
      );

      // ✅ 2. Add to Hive CachedEvent
      final eventsBox = Hive.box<CachedEvent>('events');
      await eventsBox.put(cachedEvent.id, cachedEvent);

      // ✅ 3. Add to UI state (_events map)
      final newEvent = Event(
        id: cachedEvent.id,
        title: cachedEvent.title,
        description: cachedEvent.description,
        fingerprint: cachedEvent.fingerprint,
        deviceName: cachedEvent.deviceName,
        color: Color(cachedEvent.colorValue ?? Colors.blue.value),
      );

      setState(() {
        if (_events[dateText(_selectedDay!)] != null) {
          _events[dateText(_selectedDay!)]!.add(newEvent);
        } else {
          _events[dateText(_selectedDay!)] = [newEvent];
        }
      });

      await _saveEventsToCache(); // Save to cache after adding offline
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Saved offline — will sync later.")),
      );

      // Force widget update even when offline
      await _updateWidgetWithLatestEvents();
    }

    // After successfully adding the event, update the widget
    // Note: This is redundant as we've already updated above, but keeping for safety
    await _updateWidgetWithLatestEvents();
  }

  Future<void> _fetchEventsFromFirestore(DateTime day) async {
    final eventsBox = Hive.box<CachedEvent>('events');

    if (!_isOnline) {
      final cachedEvents = eventsBox.values
          .where((e) => e.date == dateText(day))
          .map(
            (e) => Event(
              id: e.id,
              title: e.title,
              description: e.description,
              fingerprint: e.fingerprint,
              deviceName: e.deviceName,
              color: e.colorValue != null ? Color(e.colorValue!) : Colors.blue,
              startTime: e.startTimeHour != null && e.startTimeMinute != null
                  ? TimeOfDay(
                      hour: e.startTimeHour!,
                      minute: e.startTimeMinute!,
                    )
                  : null,
              endTime: e.endTimeHour != null && e.endTimeMinute != null
                  ? TimeOfDay(hour: e.endTimeHour!, minute: e.endTimeMinute!)
                  : null,
            ),
          )
          .toList();

      setState(() {
        _events[dateText(day)] = cachedEvents;
      });

      // ✅ Show offline snack ONCE (optional)
      if (_events.length == 1) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Offline mode'),
              duration: Duration(seconds: 2),
            ),
          );
        });
      }

      // Force widget update even when offline
      await _syncWidgetIfNeeded();
      return; // still return from this day's fetch
    }

    // 🔄 Otherwise fetch from Firestore
    try {
      final eventsData = await FirestoreService.getEventsForDay(day);
      final events = <Event>[];

      for (var data in eventsData) {
        final event = Event(
          id: data['id'],
          title: data['title'],
          description: data['description'],
          fingerprint: data['fingerprint'],
          deviceName: data['device_name'],
          color: data['color_value'] != null
              ? Color(data['color_value'])
              : Colors.blue,
          startTime:
              data['start_time_hour'] != null &&
                  data['start_time_minute'] != null
              ? TimeOfDay(
                  hour: data['start_time_hour'],
                  minute: data['start_time_minute'],
                )
              : null,
          endTime:
              data['end_time_hour'] != null && data['end_time_minute'] != null
              ? TimeOfDay(
                  hour: data['end_time_hour'],
                  minute: data['end_time_minute'],
                )
              : null,
        );
        events.add(event);

        final cached = CachedEvent(
          id: data['id'],
          title: data['title'],
          description: data['description'],
          date: dateText(day),
          fingerprint: data['fingerprint'],
          deviceName: data['device_name'],
          colorValue: data['color_value'],
          startTimeHour: data['start_time_hour'],
          startTimeMinute: data['start_time_minute'],
          endTimeHour: data['end_time_hour'],
          endTimeMinute: data['end_time_minute'],
        );
        await eventsBox.put(data['id'], cached);
      }

      setState(() {
        _events[dateText(day)] = events;
      });

      // Save to cache after fetching from Firestore
      await _saveEventsToCache();
      await _updateWidgetWithLatestEvents();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: ${e.toString()}")));
    }

    // After successfully fetching events, update the widget if needed
    await _syncWidgetIfNeeded();
  }

  Future<void> _deleteEventFromFirestore(Event event, int index) async {
    if (_selectedDay == null) return;

    // Store for undo
    _lastDeletedEventInfo = DeletedEventInfo(
      event: event,
      day: _selectedDay!,
      index: index,
    );

    // ✅ Update UI immediately
    setState(() {
      _events[dateText(_selectedDay!)]!.removeAt(index);
      if (_events[dateText(_selectedDay!)]!.isEmpty) {
        _events.remove(dateText(_selectedDay!));
      }
    });

    // Force widget update after deleting event
    await _updateWidgetWithLatestEvents();

    // ✅ Show snackbar
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("Event deleted"),
        action: SnackBarAction(label: "UNDO", onPressed: _undoDelete),
        duration: const Duration(seconds: 1),
        onVisible: () {
          if (_isOnline) {
            // 🔄 Delete from Firestore after delay if online
            _delayedDeleteFromFirestore(event);
          }
        },
      ),
    );

    // ✅ Queue for later if offline
    if (!_isOnline) {
      final queue = Hive.box<OfflineAction>('actionQueue');
      queue.add(
        OfflineAction(
          type: ActionType.delete,
          data: {
            'title': event.title,
            'description': event.description,
            'date': _selectedDay!.toIso8601String(),
          },
        ),
      );
      // 🧼 Also delete from local Hive cache so it doesn't reappear
      final eventsBox = Hive.box<CachedEvent>('events');
      final keysToDelete = eventsBox.keys.where((key) {
        final e = eventsBox.get(key);
        return e?.title == event.title &&
            e?.description == event.description &&
            e?.date == dateText(_selectedDay!);
      }).toList();

      for (final key in keysToDelete) {
        await eventsBox.delete(key);
      }
    }

    // After successfully deleting the event, update the widget
    // Note: This is redundant as we've already updated above, but keeping for safety
    await _updateWidgetWithLatestEvents();
  }

  void _delayedDeleteFromFirestore(Event event) {
    // Cancel any existing delete operation
    _deleteTimer?.cancel();

    // Start a new timer for deletion
    _deleteTimer = Timer(const Duration(seconds: 1), () async {
      try {
        if (_lastDeletedEventInfo?.event == event) {
          await FirestoreService.deleteEvent(
            title: event.title,
            description: event.description,
            date: _selectedDay!,
          );
          _lastDeletedEventInfo =
              null; // Clear reference after successful deletion
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Failed to delete event: $e")));
        }
      }
    });
  }

  // Undo deletion
  void _undoDelete() {
    if (_lastDeletedEventInfo == null) return;

    final info = _lastDeletedEventInfo!;

    setState(() {
      // If the day entry was completely removed, recreate it
      if (!_events.containsKey(info.day)) {
        _events[dateText(info.day)] = [];
      }

      // Insert the event back at its original position or at the end
      if (info.index < _events[dateText(info.day)]!.length) {
        _events[dateText(info.day)]!.insert(info.index, info.event);
      } else {
        _events[dateText(info.day)]!.add(info.event);
      }
    });

    // Update widget after undoing delete
    _updateWidgetWithLatestEvents();

    // Cancel the pending deletion
    _deleteTimer?.cancel();
    _lastDeletedEventInfo = null;
  }

  Future<void> _fetchEventsForVisibleMonth(DateTime focusedDay) async {
    final startDay = DateTime.utc(focusedDay.year, focusedDay.month, 1);
    final endDay = DateTime.utc(focusedDay.year, focusedDay.month + 1, 0);
    final eventsBox = Hive.box<CachedEvent>('events');

    // Step 1: Load from local cache first (instant UI update)
    final Map<String, List<Event>> cachedEventsMap = {};
    for (var day = startDay; !day.isAfter(endDay); day = day.add(const Duration(days: 1))) {
      final dayKey = dateText(day);
      final cachedEvents = eventsBox.values
          .where((e) => e.date == dayKey)
          .map((e) => Event(
                id: e.id,
                title: e.title,
                description: e.description,
                fingerprint: e.fingerprint,
                deviceName: e.deviceName,
                color: e.colorValue != null ? Color(e.colorValue!) : Colors.blue,
                startTime: e.startTimeHour != null && e.startTimeMinute != null
                    ? TimeOfDay(hour: e.startTimeHour!, minute: e.startTimeMinute!)
                    : null,
                endTime: e.endTimeHour != null && e.endTimeMinute != null
                    ? TimeOfDay(hour: e.endTimeHour!, minute: e.endTimeMinute!)
                    : null,
              ))
          .toList();
      if (cachedEvents.isNotEmpty) {
        cachedEventsMap[dayKey] = cachedEvents;
      }
    }

    // Update UI with cached data immediately
    if (cachedEventsMap.isNotEmpty) {
      setState(() {
        _events.addAll(cachedEventsMap);
      });
    }

    // Step 2: If offline, we're done
    if (!_isOnline) return;

    // Step 3: Fetch from Firestore using single range query
    try {
      final eventsData = await FirestoreService.getEventsForRange(startDay, endDay);
      final Map<String, List<Event>> fetchedEventsMap = {};

      for (var data in eventsData) {
        final dateStr = data['date'] as String;
        final eventDate = DateTime.parse(dateStr);
        final dayKey = dateText(eventDate);

        final event = Event(
          id: data['id'],
          title: data['title'],
          description: data['description'],
          fingerprint: data['fingerprint'],
          deviceName: data['device_name'],
          color: data['color_value'] != null ? Color(data['color_value']) : Colors.blue,
          startTime: data['start_time_hour'] != null && data['start_time_minute'] != null
              ? TimeOfDay(hour: data['start_time_hour'], minute: data['start_time_minute'])
              : null,
          endTime: data['end_time_hour'] != null && data['end_time_minute'] != null
              ? TimeOfDay(hour: data['end_time_hour'], minute: data['end_time_minute'])
              : null,
        );

        fetchedEventsMap.putIfAbsent(dayKey, () => []).add(event);

        // Update local cache
        final cached = CachedEvent(
          id: data['id'],
          title: data['title'],
          description: data['description'],
          date: dayKey,
          fingerprint: data['fingerprint'],
          deviceName: data['device_name'],
          colorValue: data['color_value'],
          startTimeHour: data['start_time_hour'],
          startTimeMinute: data['start_time_minute'],
          endTimeHour: data['end_time_hour'],
          endTimeMinute: data['end_time_minute'],
        );
        await eventsBox.put(data['id'], cached);
      }

      // Update UI with fresh data from Firestore
      setState(() {
        // Clear old events for this month range and add fresh ones
        for (var day = startDay; !day.isAfter(endDay); day = day.add(const Duration(days: 1))) {
          final dayKey = dateText(day);
          if (fetchedEventsMap.containsKey(dayKey)) {
            _events[dayKey] = fetchedEventsMap[dayKey]!;
          } else {
            _events.remove(dayKey);
          }
        }
      });

      await _saveEventsToCache();
      await _updateWidgetWithLatestEvents();
    } catch (e) {
      debugPrint("Error fetching events for month: $e");
    }
  }

  void _showEventDetails(Event event) {
    // Calculate responsive dialog width based on screen size
    final dialogWidth = Responsive.getResponsiveValue(
      context: context,
      mobile: Responsive.width(context) * 0.9,
      tablet: Responsive.width(context) * 0.7,
      desktop: Responsive.width(context) * 0.4,
    );

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Center(
        child: Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          // Set the width constraint for larger screens
          child: Container(
            width: dialogWidth,
            constraints: BoxConstraints(maxWidth: 600),
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Dialog title
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 24,
                          decoration: BoxDecoration(
                            color: event.color ?? _themeColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Event Details',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Dialog content
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title section
                        Text(
                          event.title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Description if available
                        if (event.description.isNotEmpty) ...[
                          const Divider(),
                          Text(
                            'Description',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            event.description,
                            style: TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Created by section
                        if (event.fingerprint != null) ...[
                          Row(
                            children: [
                              Text(
                                event.deviceName ??
                                    "Device ${event.fingerprint!.substring(0, 6)}",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Dialog actions
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Only show Edit button when not in kiosk mode with delete/edit hidden
                        if (!(_isKioskEnabled && _hideDeleteEdit))
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.edit),
                              label: const Text('Edit'),
                              onPressed: () {
                                Navigator.pop(context);
                                _showEditEventDialog(event);
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _themeColor,
                                side: BorderSide(
                                  color: _themeColor,
                                  width: 1.5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                        if (!(_isKioskEnabled && _hideDeleteEdit))
                          const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.close),
                            label: const Text('Close'),
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _themeColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Add method for widget synchronization
  Future<void> _syncWidgetIfNeeded() async {
    try {
      bool needsSync = await _widgetService.needsSync();
      if (needsSync) {
        await _updateWidgetWithLatestEvents();
      }
    } catch (e) {
      debugPrint('Error syncing widget: $e');
    }
  }

  // Add method to update widget with latest events
  Future<void> _updateWidgetWithLatestEvents() async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final todayEvents = _events[dateText(today)] ?? [];

      // Get today's event titles
      final eventTitles = todayEvents.map((e) => e.title).toList();

      // Update the widget with today's events
      await WidgetService.updateWidgetEvents(eventTitles, []);

      // Also update the calendar widget with event days data
      final Map<String, bool> eventDays = {};
      final currentMonth = DateTime(now.year, now.month, 1);
      final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);

      // Loop through all days in the current month
      for (
        DateTime date = currentMonth;
        date.isBefore(lastDayOfMonth.add(const Duration(days: 1)));
        date = date.add(const Duration(days: 1))
      ) {
        final dateKey = dateText(date);
        final hasEvents = _events[dateKey]?.isNotEmpty ?? false;
        eventDays[dateKey] = hasEvents;
      }

      // Update the calendar widget
      await _widgetService.updateWidget(
        eventTitle: eventTitles.isEmpty
            ? 'No events today'
            : eventTitles.join('\n'),
        eventDays: eventDays,
      );
    } catch (e) {
      debugPrint('Error updating widget: $e');
    }
  }

  // Add new method to save events to cache
  Future<void> _saveEventsToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final eventsMap = _events.map(
        (key, value) => MapEntry(
          key,
          value
              .map(
                (e) => {
                  'id': e.id,
                  'title': e.title,
                  'description': e.description,
                  'fingerprint': e.fingerprint,
                  'deviceName': e.deviceName,
                  'colorValue': e.color?.value,
                },
              )
              .toList(),
        ),
      );

      await prefs.setString(_cachedEventsKey, jsonEncode(eventsMap));
      await prefs.setString(
        _lastSyncTimestampKey,
        DateTime.now().toIso8601String(),
      );
      debugPrint('✅ Events cached successfully');
    } catch (e) {
      debugPrint('❌ Error caching events: $e');
    }
  }

  // Add new method to load events from cache
  Future<void> _loadEventsFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedEvents = prefs.getString(_cachedEventsKey);

      if (cachedEvents != null) {
        final Map<String, dynamic> decodedEvents = jsonDecode(cachedEvents);
        final Map<String, List<Event>> loadedEvents = {};

        decodedEvents.forEach((key, value) {
          loadedEvents[key] = (value as List)
              .map(
                (e) => Event(
                  id: e['id'],
                  title: e['title'],
                  description: e['description'],
                  fingerprint: e['fingerprint'],
                  deviceName: e['deviceName'],
                  color: e['colorValue'] != null
                      ? Color(e['colorValue'])
                      : null,
                ),
              )
              .toList();
        });

        setState(() {
          _events.clear();
          _events.addAll(loadedEvents);
        });
        debugPrint('✅ Events loaded from cache');
        return;
      }
    } catch (e) {
      debugPrint('❌ Error loading cached events: $e');
    }
  }

  // Helper method for app bar buttons with better touch targets
  Widget _buildAppBarButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required double iconSize,
    required double fontSize,
  }) {
    return TextButton.icon(
      icon: Icon(icon, color: _themeColor, size: iconSize),
      label: Text(label, style: TextStyle(fontSize: fontSize)),
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: Colors.black87,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLargeScreen =
        Responsive.isDesktop(context) || Responsive.isTablet(context);
    final iconSize = isLargeScreen ? 24.0 : 20.0;
    final buttonFontSize = isLargeScreen ? 16.0 : 14.0;

    return GestureDetector(
      // Detect user activity for kiosk mode
      onTap: _onUserActivity,
      onPanDown: (_) => _onUserActivity(),
      onScaleStart: (_) => _onUserActivity(),
      behavior: HitTestBehavior.translucent,
      child: Stack(
        children: [
          Scaffold(
            appBar: AppBar(
              toolbarHeight: isLargeScreen ? 48 : 56,
              title: isLargeScreen
                  ? Row(
                      children: [
                        // App title/logo for tablet
                        Text(
                          'WePlan',
                          style: TextStyle(
                            fontSize: isLargeScreen ? 24 : 20,
                            fontWeight: FontWeight.bold,
                            color: _themeColor,
                          ),
                        ),
                        const SizedBox(width: 32),
                        // Menu options with larger touch targets
                        _buildAppBarButton(
                          icon: Icons.settings_outlined,
                          label: 'Settings',
                          onPressed: () => _navigateToSettings(),
                          iconSize: iconSize,
                          fontSize: buttonFontSize,
                        ),
                        const SizedBox(width: 8),
                        _buildAppBarButton(
                          icon: Icons.share_outlined,
                          label: 'Share',
                          onPressed: () async {
                            final prefs = await SharedPreferences.getInstance();
                            final shareCode = prefs.getString('shareCode');
                            if (shareCode != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ShareScreen(
                                    shareCode: shareCode,
                                    isFirstTimeUser: false,
                                  ),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'No share code found. Please setup sharing first.',
                                  ),
                                ),
                              );
                            }
                          },
                          iconSize: iconSize,
                          fontSize: buttonFontSize,
                        ),
                        const SizedBox(width: 8),
                        _buildAppBarButton(
                          icon: Icons.group_add_outlined,
                          label: 'Join',
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    ShareSetupScreen(isFirstTime: false),
                              ),
                            );
                          },
                          iconSize: iconSize,
                          fontSize: buttonFontSize,
                        ),
                      ],
                    )
                  : Text(widget.title),
              leading: isLargeScreen
                  ? null
                  : PopupMenuButton<String>(
                      icon: Icon(Icons.more_horiz),
                      onSelected: (value) async {
                        if (value == 'share') {
                          final prefs = await SharedPreferences.getInstance();
                          final shareCode = prefs.getString('shareCode');
                          if (shareCode != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ShareScreen(
                                  shareCode:
                                      shareCode, // This is passed to ShareScreen widget
                                  isFirstTimeUser:
                                      false, // Explicitly set to false
                                ),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'No share code found. Please setup sharing first.',
                                ),
                              ),
                            );
                          }
                        } else if (value == 'settings') {
                          await _navigateToSettings();
                        }
                      },
                      itemBuilder: (BuildContext context) => [
                        PopupMenuItem<String>(
                          value: 'settings',
                          child: Row(
                            children: [
                              Icon(
                                Icons.settings_outlined,
                                color: _themeColor,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              const Text('Settings'),
                            ],
                          ),
                        ),
                        PopupMenuItem<String>(
                          value: 'share',
                          child: Row(
                            children: [
                              Icon(
                                Icons.share_outlined,
                                color: _themeColor,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              const Text('Share Calendar'),
                            ],
                          ),
                        ),
                        PopupMenuItem<String>(
                          value: 'setup',
                          child: Row(
                            children: [
                              Icon(
                                Icons.group_add_outlined,
                                color: _themeColor,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              const Text('Create/Join Calendar'),
                            ],
                          ),
                          onTap: () {
                            Future.delayed(Duration.zero, () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      ShareSetupScreen(isFirstTime: false),
                                ),
                              );
                            });
                          },
                        ),
                      ],
                    ),
              actions: [
                // Connection status indicator
                if (!_isOnline)
                  Padding(
                    padding: EdgeInsets.only(right: isLargeScreen ? 16 : 8),
                    child: Icon(
                      Icons.wifi_off,
                      color: Colors.red,
                      size: isLargeScreen ? 28 : 24,
                    ),
                  ),
                // Add event button - larger for tablet
                Padding(
                  padding: EdgeInsets.only(right: isLargeScreen ? 16 : 8),
                  child: isLargeScreen
                      ? ElevatedButton.icon(
                          icon: Icon(Icons.add, size: 22),
                          label: Text(
                            'Add Event',
                            style: TextStyle(fontSize: 16),
                          ),
                          onPressed: _selectedDay != null
                              ? _showAddEventDialog
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _themeColor,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        )
                      : IconButton(
                          icon: Icon(Icons.add),
                          onPressed: _selectedDay != null
                              ? _showAddEventDialog
                              : null,
                        ),
                ),
              ],
            ),
            body: CenteredContainer(
              alignment: Alignment.topCenter,
              maxWidth: Responsive.width(context) > 1400
                  ? 1400
                  : double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.isMobile(context) ? 8 : 16,
                vertical: 8,
              ),
              // Add card-like appearance only on very large screens
              decoration: kIsWeb && Responsive.width(context) > 1400
                  ? BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    )
                  : null,
              child: OrientationBuilder(
                builder: (context, orientation) {
                  final isLargeScreen =
                      Responsive.isDesktop(context) ||
                      Responsive.isTablet(context);

                  // For tablet and desktop, calendar is full width with sliding events panel
                  if (isLargeScreen) {
                    final panelWidth = MediaQuery.of(context).size.width * 0.3;
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Calendar section - expands to fill available space
                        Expanded(child: _buildCalendarSection()),

                        // Sliding events panel from right
                        AnimatedContainer(
                          duration: Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          width: _isEventsPanelVisible ? panelWidth : 0,
                          child: ClipRect(
                            child: OverflowBox(
                              alignment: Alignment.centerLeft,
                              maxWidth: panelWidth,
                              child: Container(
                                width: panelWidth,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 10,
                                      offset: Offset(-2, 0),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    // Close button header
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          IconButton(
                                            icon: Icon(Icons.close, size: 24),
                                            onPressed: () {
                                              setState(() {
                                                _isEventsPanelVisible = false;
                                              });
                                            },
                                            tooltip: 'Close panel',
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Events section
                                    Expanded(child: _buildEventsSection()),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }
                  // For mobile, use stacked layout
                  else {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildCalendarSection(),
                        const SizedBox(height: 8.0),
                        Expanded(child: _buildEventsSection()),
                      ],
                    );
                  }
                },
              ),
            ),
          ),
          // Screensaver overlay
          if (_isScreensaverActive)
            GestureDetector(
              onTap: () {
                _onUserActivity();
              },
              onPanDown: (_) {
                _onUserActivity();
              },
              child: AnimatedOpacity(
                opacity: _isScreensaverActive ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 500),
                child: Container(
                  color: Colors.black,
                  child: _buildScreensaverContent(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Helper method to build screensaver content based on mode
  Widget _buildScreensaverContent() {
    // Check if using slideshow mode with folder/multiple images
    if (_useImageFolder && _currentSlideshowImage.isNotEmpty) {
      return _buildImageScreensaver(_currentSlideshowImage);
    }
    // Check if using single image mode
    if (!_useImageFolder && _screensaverImageUrl.isNotEmpty) {
      return _buildImageScreensaver(_screensaverImageUrl);
    }
    // Default screensaver (no image)
    return _buildDefaultScreensaver();
  }

  // Helper method to build screensaver with image
  Widget _buildImageScreensaver(String imageUrl) {
    // Determine if this is a local file path or network URL
    final isNetworkImage = imageUrl.startsWith('http');

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 800),
      child: isNetworkImage
          ? Image.network(
              imageUrl,
              key: ValueKey(imageUrl),
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Center(
                  child: CircularProgressIndicator(
                    color: Colors.white.withOpacity(0.6),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return _buildDefaultScreensaver();
              },
            )
          : Image.file(
              File(imageUrl),
              key: ValueKey(imageUrl),
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (context, error, stackTrace) {
                return _buildDefaultScreensaver();
              },
            ),
    );
  }

  // Helper method to build default screensaver (no image)
  Widget _buildDefaultScreensaver() {
    return Container(
      color: Colors.black,
      width: double.infinity,
      height: double.infinity,
    );
  }

  // Helper method to build the calendar section
  Widget _buildCalendarSection() {
    // Responsive values for tablet/desktop
    final isLargeScreen =
        Responsive.isDesktop(context) || Responsive.isTablet(context);

    // Calculate row height based on available screen height for tablet
    final screenHeight = Responsive.height(context);
    final availableHeight = screenHeight - 50; // Subtract header and padding
    final calculatedRowHeight = isLargeScreen
        ? (availableHeight / 7.5)
        : 65.0; // 6 rows + header
    final rowHeight = calculatedRowHeight.clamp(80.0, 140.0); // Min 60, max 120

    final fontSize = isLargeScreen ? 22.0 : 14.0;
    final eventFontSize = isLargeScreen ? 16.0 : 9.0;
    final headerFontSize = isLargeScreen ? 26.0 : 16.0;
    final daysOfWeekHeight = isLargeScreen ? 40.0 : 32.0;
    final cellBottomMargin = isLargeScreen ? (rowHeight - 30) : 41.0;
    final eventAreaTop = isLargeScreen ? 32.0 : 25.0;
    final eventAreaHeight = isLargeScreen ? (rowHeight - 38) : 32.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onHorizontalDragEnd: (details) {
            // Swipe right to go to previous month
            if (details.primaryVelocity! > 0) {
              HapticFeedback.lightImpact();
              setState(() {
                _focusedDay = DateTime(
                  _focusedDay.year,
                  _focusedDay.month - 1,
                  1,
                );
                _fetchEventsForVisibleMonth(_focusedDay);
              });
            }
            // Swipe left to go to next month
            else if (details.primaryVelocity! < 0) {
              HapticFeedback.lightImpact();
              setState(() {
                _focusedDay = DateTime(
                  _focusedDay.year,
                  _focusedDay.month + 1,
                  1,
                );
                _fetchEventsForVisibleMonth(_focusedDay);
              });
            }
          },
          child: TableCalendar(
            firstDay: DateTime.utc(2010, 10, 16),
            lastDay: DateTime.utc(2050, 3, 14),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            startingDayOfWeek: StartingDayOfWeek.monday,
            // Calendar styling
            calendarStyle: CalendarStyle(
              outsideDaysVisible: false,
              // Selection circle
              selectedDecoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _themeColor,
              ),
              // Today highlight - more visible
              todayDecoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _themeColor.withOpacity(0.3),
                border: Border.all(color: _themeColor, width: 2),
              ),
              //The highlight box decoration using Cell Margin to adjust the position and size
              cellPadding: EdgeInsets.zero,
              cellMargin: EdgeInsets.only(
                left: 8,
                top: 2,
                right: 8,
                bottom: cellBottomMargin,
              ),
              // Cell styling
              cellAlignment: Alignment.topCenter,
              // Table borders
              tableBorder: TableBorder.all(
                color: Colors.grey[200]!,
                width: 1,
                borderRadius: BorderRadius.circular(0),
              ),
              // Marker styling
              markersAutoAligned: false,
              markerSize: 6,
              markerMargin: EdgeInsets.only(top: 1),
              //Text styling
              defaultTextStyle: TextStyle(
                color: Color(0xFF5A5A5A),
                fontSize: fontSize,
              ),
              // Weekend dates - same size as weekday
              weekendTextStyle: TextStyle(
                color: Color(0xFF5A5A5A),
                fontSize: fontSize,
              ),
              selectedTextStyle: TextStyle(
                color: Color(0xFFFFFFFF),
                fontSize: fontSize,
              ),
              todayTextStyle: TextStyle(
                color: Color(0xFF170909),
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
              ),
              outsideTextStyle: TextStyle(
                color: Color(0x8CA384BA),
                fontSize: fontSize - 1,
              ),
            ),
            // Calendar configuration
            daysOfWeekHeight: daysOfWeekHeight,
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: TextStyle(
                fontSize: isLargeScreen ? 18.0 : 12.0,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
              weekendStyle: TextStyle(
                fontSize: isLargeScreen ? 18.0 : 12.0,
                fontWeight: FontWeight.w600,
                color: Colors.grey[500],
              ),
            ),
            rowHeight: rowHeight,
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: TextStyle(
                fontSize: headerFontSize,
                fontWeight: FontWeight.bold,
              ),
              leftChevronIcon: Icon(
                Icons.chevron_left,
                size: isLargeScreen ? 32 : 24,
              ),
              rightChevronIcon: Icon(
                Icons.chevron_right,
                size: isLargeScreen ? 32 : 24,
              ),
              headerPadding: EdgeInsets.symmetric(
                vertical: isLargeScreen ? 4 : 8,
              ),
            ),

            // Custom builder to show event titles
            calendarBuilders: CalendarBuilders(
              // Custom selected day builder - circle aligned with number
              selectedBuilder: (context, date, _) {
                return Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    width: isLargeScreen ? 36 : 28,
                    height: isLargeScreen ? 36 : 28,
                    margin: EdgeInsets.only(top: isLargeScreen ? 4 : 2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _themeColor,
                    ),
                    child: Center(
                      child: Text(
                        '${date.day}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: fontSize,
                        ),
                      ),
                    ),
                  ),
                );
              },
              // Custom today builder - circle aligned with number
              todayBuilder: (context, date, _) {
                return Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    width: isLargeScreen ? 36 : 28,
                    height: isLargeScreen ? 36 : 28,
                    margin: EdgeInsets.only(top: isLargeScreen ? 4 : 2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _themeColor.withOpacity(0.3),
                      border: Border.all(color: _themeColor, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        '${date.day}',
                        style: TextStyle(
                          color: Color(0xFF170909),
                          fontSize: fontSize,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              },
              markerBuilder: (context, date, events) {
                if (events.isEmpty) return Container();
                // Cast events to your Event type
                final eventsList = events as List<Event>;
                return Positioned(
                  bottom: 1,
                  left: 1,
                  right: 1,
                  top: eventAreaTop,
                  child: Container(
                    height: eventAreaHeight,
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: eventsList.length > 3 ? 3 : eventsList.length,
                      itemBuilder: (context, index) {
                        final event = eventsList[index];
                        return Container(
                          margin: EdgeInsets.only(
                            bottom: isLargeScreen ? 2 : 1,
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: isLargeScreen ? 6 : 3,
                            vertical: isLargeScreen ? 3 : 1,
                          ),
                          decoration: BoxDecoration(
                            color:
                                event.color?.withOpacity(0.75) ??
                                Colors.blue.withOpacity(0.35),
                            borderRadius: BorderRadius.circular(
                              isLargeScreen ? 6 : 4,
                            ),
                          ),
                          child: Text(
                            event.title,
                            style: TextStyle(
                              fontSize: eventFontSize,
                              fontWeight: isLargeScreen
                                  ? FontWeight.w500
                                  : FontWeight.normal,
                              color: Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),

            // Event handling
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
              _fetchEventsForVisibleMonth(focusedDay);
            },
            eventLoader: (day) => _getEventsForDay(day),
            onDaySelected: _onDaySelected,
          ),
        ),
      ],
    );
  }

  // Helper method to build the events section
  Widget _buildEventsSection() {
    final isLargeScreen =
        Responsive.isDesktop(context) || Responsive.isTablet(context);
    final titleFontSize = isLargeScreen ? 22.0 : 18.0;
    final eventTitleFontSize = isLargeScreen ? 18.0 : 16.0;
    final deviceFontSize = isLargeScreen ? 14.0 : 12.0;
    final emptyIconSize = isLargeScreen ? 90.0 : 70.0;
    final emptyTextSize = isLargeScreen ? 18.0 : 16.0;
    final cardPadding = isLargeScreen ? 16.0 : 12.0;

    if (_selectedDay == null) {
      return Center(
        child: Text(
          'Select a day to view events',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: isLargeScreen ? 18 : 14,
          ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(isLargeScreen ? 16.0 : 8.0),
          child: Text(
            DateFormat('EEEE, d MMM').format(_selectedDay!),
            style: TextStyle(
              fontSize: titleFontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child:
              _events[dateText(_selectedDay!)] == null ||
                  _events[dateText(_selectedDay!)]!.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.event_available,
                        size: emptyIconSize,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "No event for this day",
                        style: TextStyle(
                          fontSize: emptyTextSize,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _showAddEventDialog,
                        icon: Icon(Icons.add, size: isLargeScreen ? 24 : 20),
                        label: Text(
                          "Add Event",
                          style: TextStyle(fontSize: isLargeScreen ? 16 : 14),
                        ),
                        style: ElevatedButton.styleFrom(
                          iconColor: Colors.white,
                          foregroundColor: Colors.white,
                          backgroundColor: _themeColor.withOpacity(0.8),
                          padding: EdgeInsets.symmetric(
                            horizontal: isLargeScreen ? 32 : 24,
                            vertical: isLargeScreen ? 16 : 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.only(
                    top: isLargeScreen ? 12 : 8,
                    bottom: isLargeScreen ? 24 : 16,
                    left: isLargeScreen ? 8 : 0,
                    right: isLargeScreen ? 8 : 0,
                  ),
                  itemCount: _getEventsForDay(_selectedDay!).length,
                  itemBuilder: (context, index) {
                    final event = _getEventsForDay(_selectedDay!)[index];
                    final eventData = _events[dateText(_selectedDay!)]![index];
                    final eventColor =
                        event.color ?? Theme.of(context).primaryColor;

                    // Build the card widget
                    final cardWidget = Card(
                      margin: EdgeInsets.symmetric(
                        horizontal: isLargeScreen ? 12 : 16,
                        vertical: isLargeScreen ? 10 : 6,
                      ),
                      elevation: isLargeScreen ? 2 : 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: eventColor.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        splashFactory: InkRipple.splashFactory,
                        splashColor: eventColor.withOpacity(0.3),
                        highlightColor: eventColor.withOpacity(0.1),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _showEventDetails(event);
                        },
                        onLongPress: (_isKioskEnabled && _hideDeleteEdit)
                            ? null
                            : () {
                                HapticFeedback.mediumImpact();
                                _showEditEventDialog(event);
                              },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                eventColor.withOpacity(0.2),
                                Colors.white,
                              ],
                              stops: const [0.02, 0.1],
                            ),
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: cardPadding,
                              horizontal: cardPadding + 4,
                            ),
                            child: Row(
                              children: [
                                // Left colored indicator
                                Container(
                                  width: isLargeScreen ? 5 : 4,
                                  height: isLargeScreen ? 70 : 55,
                                  decoration: BoxDecoration(
                                    color: eventColor,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                                SizedBox(width: isLargeScreen ? 20 : 16),
                                // Content
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Time display
                                      if (event.timeString.isNotEmpty)
                                        Padding(
                                          padding: EdgeInsets.only(bottom: 4),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.access_time,
                                                size: isLargeScreen ? 16 : 14,
                                                color: _themeColor,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                event.timeString,
                                                style: TextStyle(
                                                  fontSize: isLargeScreen
                                                      ? 14
                                                      : 12,
                                                  color: _themeColor,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      Text(
                                        event.title,
                                        style: TextStyle(
                                          fontSize: eventTitleFontSize,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 6),
                                      if (eventData.fingerprint != null)
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.person_outline,
                                              size: deviceFontSize + 2,
                                              color: Colors.grey[600],
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                event.deviceName ??
                                                    "Device ${event.fingerprint!.substring(0, 6)}",
                                                style: TextStyle(
                                                  fontSize: deviceFontSize,
                                                  color: Colors.grey[600],
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ),
                                // Swipe hint icon
                                // Only show swipe hint when delete is enabled
                                if (!(_isKioskEnabled && _hideDeleteEdit))
                                  Icon(
                                    Icons.chevron_left,
                                    color: Colors.grey[300],
                                    size: isLargeScreen ? 24 : 20,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );

                    // Wrap with Dismissible only if delete/edit is not hidden
                    if (_isKioskEnabled && _hideDeleteEdit) {
                      return cardWidget;
                    }

                    return Dismissible(
                      key: Key(event.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        margin: EdgeInsets.symmetric(
                          horizontal: isLargeScreen ? 12 : 16,
                          vertical: isLargeScreen ? 8 : 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red[400],
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.centerRight,
                        padding: EdgeInsets.only(right: 24),
                        child: Icon(
                          Icons.delete_outline,
                          color: Colors.white,
                          size: isLargeScreen ? 32 : 28,
                        ),
                      ),
                      confirmDismiss: (direction) async {
                        return await showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text('Delete Event'),
                            content: Text(
                              'Are you sure you want to delete "${event.title}"?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(false),
                                child: Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                ),
                                child: Text(
                                  'Delete',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      onDismissed: (direction) {
                        _deleteEventFromFirestore(event, index);
                      },
                      child: cardWidget,
                    );
                  },
                ),
        ),
      ],
    );
  }
}
