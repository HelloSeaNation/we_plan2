import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing kiosk mode state and timers
class KioskService {
  // Singleton instance
  static final KioskService _instance = KioskService._internal();
  factory KioskService() => _instance;
  KioskService._internal();

  // Settings keys
  static const String _keyKioskEnabled = 'kiosk_enabled';
  static const String _keyInactivityTimeout = 'kiosk_inactivity_timeout';
  static const String _keyHideDeleteEdit = 'kiosk_hide_delete_edit';
  static const String _keyScreensaverEnabled = 'kiosk_screensaver_enabled';
  static const String _keyScreensaverTimeout = 'kiosk_screensaver_timeout';
  static const String _keyScreensaverImageUrl = 'kiosk_screensaver_image_url';

  // Default values
  static const int defaultInactivityTimeout = 5; // minutes
  static const int defaultScreensaverTimeout = 10; // minutes

  // State
  bool _isEnabled = false;
  int _inactivityTimeoutMinutes = defaultInactivityTimeout;
  bool _hideDeleteEdit = false;
  bool _screensaverEnabled = false;
  int _screensaverTimeoutMinutes = defaultScreensaverTimeout;
  String _screensaverImageUrl = '';

  // Timers
  Timer? _inactivityTimer;
  Timer? _screensaverTimer;

  // Callbacks
  VoidCallback? _onInactivityTimeout;
  VoidCallback? _onScreensaverActivate;
  VoidCallback? _onScreensaverDeactivate;

  // Screensaver state
  bool _isScreensaverActive = false;

  // Getters
  bool get isEnabled => _isEnabled;
  int get inactivityTimeoutMinutes => _inactivityTimeoutMinutes;
  bool get hideDeleteEdit => _hideDeleteEdit;
  bool get screensaverEnabled => _screensaverEnabled;
  int get screensaverTimeoutMinutes => _screensaverTimeoutMinutes;
  String get screensaverImageUrl => _screensaverImageUrl;
  bool get isScreensaverActive => _isScreensaverActive;

  /// Initialize kiosk service and load settings from SharedPreferences
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isEnabled = prefs.getBool(_keyKioskEnabled) ?? false;
      _inactivityTimeoutMinutes = prefs.getInt(_keyInactivityTimeout) ?? defaultInactivityTimeout;
      _hideDeleteEdit = prefs.getBool(_keyHideDeleteEdit) ?? false;
      _screensaverEnabled = prefs.getBool(_keyScreensaverEnabled) ?? false;
      _screensaverTimeoutMinutes = prefs.getInt(_keyScreensaverTimeout) ?? defaultScreensaverTimeout;
      _screensaverImageUrl = prefs.getString(_keyScreensaverImageUrl) ?? '';

      debugPrint('KioskService initialized: enabled=$_isEnabled, timeout=$_inactivityTimeoutMinutes min');
    } catch (e) {
      debugPrint('Error initializing KioskService: $e');
    }
  }

  /// Register callback for when inactivity timeout is reached
  void registerInactivityCallback(VoidCallback callback) {
    _onInactivityTimeout = callback;
  }

  /// Register callbacks for screensaver activation/deactivation
  void registerScreensaverCallbacks({
    required VoidCallback onActivate,
    required VoidCallback onDeactivate,
  }) {
    _onScreensaverActivate = onActivate;
    _onScreensaverDeactivate = onDeactivate;
  }

  /// Called when user activity is detected - resets all timers
  void onUserActivity() {
    if (!_isEnabled) return;

    // Deactivate screensaver if active
    if (_isScreensaverActive) {
      _isScreensaverActive = false;
      _onScreensaverDeactivate?.call();
    }

    // Reset inactivity timer
    _resetInactivityTimer();

    // Reset screensaver timer
    if (_screensaverEnabled) {
      _resetScreensaverTimer();
    }
  }

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(
      Duration(minutes: _inactivityTimeoutMinutes),
      () {
        debugPrint('Kiosk: Inactivity timeout reached');
        _onInactivityTimeout?.call();
      },
    );
  }

  void _resetScreensaverTimer() {
    _screensaverTimer?.cancel();
    _screensaverTimer = Timer(
      Duration(minutes: _screensaverTimeoutMinutes),
      () {
        debugPrint('Kiosk: Screensaver activated');
        _isScreensaverActive = true;
        _onScreensaverActivate?.call();
      },
    );
  }

  /// Start kiosk mode timers (call when kiosk mode is enabled)
  void startTimers() {
    if (!_isEnabled) return;

    _resetInactivityTimer();
    if (_screensaverEnabled) {
      _resetScreensaverTimer();
    }
  }

  /// Stop all timers (call when kiosk mode is disabled or app is disposed)
  void stopTimers() {
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
    _screensaverTimer?.cancel();
    _screensaverTimer = null;
    _isScreensaverActive = false;
  }

  /// Update kiosk settings and persist to SharedPreferences
  Future<void> updateSettings({
    bool? enabled,
    int? inactivityTimeoutMinutes,
    bool? hideDeleteEdit,
    bool? screensaverEnabled,
    int? screensaverTimeoutMinutes,
    String? screensaverImageUrl,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (enabled != null) {
        _isEnabled = enabled;
        await prefs.setBool(_keyKioskEnabled, enabled);
      }

      if (inactivityTimeoutMinutes != null) {
        _inactivityTimeoutMinutes = inactivityTimeoutMinutes;
        await prefs.setInt(_keyInactivityTimeout, inactivityTimeoutMinutes);
      }

      if (hideDeleteEdit != null) {
        _hideDeleteEdit = hideDeleteEdit;
        await prefs.setBool(_keyHideDeleteEdit, hideDeleteEdit);
      }

      if (screensaverEnabled != null) {
        _screensaverEnabled = screensaverEnabled;
        await prefs.setBool(_keyScreensaverEnabled, screensaverEnabled);
      }

      if (screensaverTimeoutMinutes != null) {
        _screensaverTimeoutMinutes = screensaverTimeoutMinutes;
        await prefs.setInt(_keyScreensaverTimeout, screensaverTimeoutMinutes);
      }

      if (screensaverImageUrl != null) {
        _screensaverImageUrl = screensaverImageUrl;
        await prefs.setString(_keyScreensaverImageUrl, screensaverImageUrl);
      }

      // Restart timers with new settings if enabled
      if (_isEnabled) {
        startTimers();
      } else {
        stopTimers();
      }

      debugPrint('KioskService settings updated: enabled=$_isEnabled');
    } catch (e) {
      debugPrint('Error updating KioskService settings: $e');
    }
  }

  /// Dispose of resources
  void dispose() {
    stopTimers();
    _onInactivityTimeout = null;
    _onScreensaverActivate = null;
    _onScreensaverDeactivate = null;
  }
}
