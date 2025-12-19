import 'dart:async';
import 'dart:io';
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
  static const String _keyScreensaverFolderPath = 'kiosk_screensaver_folder_path';
  static const String _keyScreensaverRotationInterval = 'kiosk_screensaver_rotation_interval';
  static const String _keyScreensaverUseFolder = 'kiosk_screensaver_use_folder';
  static const String _keyDakboardUrl = 'kiosk_dakboard_url';
  static const String _keyUseDakboard = 'kiosk_use_dakboard';

  // Default values
  static const int defaultInactivityTimeout = 5; // minutes
  static const int defaultScreensaverTimeout = 10; // minutes
  static const int defaultRotationInterval = 10; // seconds

  // State
  bool _isEnabled = false;
  int _inactivityTimeoutMinutes = defaultInactivityTimeout;
  bool _hideDeleteEdit = false;
  bool _screensaverEnabled = false;
  int _screensaverTimeoutMinutes = defaultScreensaverTimeout;
  String _screensaverImageUrl = '';
  String _screensaverFolderPath = '';
  int _rotationIntervalSeconds = defaultRotationInterval;
  bool _useFolder = false;
  String _dakboardUrl = '';
  bool _useDakboard = false;

  // Image rotation state
  List<String> _imagePaths = [];
  int _currentImageIndex = 0;
  Timer? _imageRotationTimer;
  VoidCallback? _onImageChanged;

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
  String get screensaverFolderPath => _screensaverFolderPath;
  int get rotationIntervalSeconds => _rotationIntervalSeconds;
  bool get useFolder => _useFolder;
  String get dakboardUrl => _dakboardUrl;
  bool get useDakboard => _useDakboard;
  bool get isScreensaverActive => _isScreensaverActive;
  List<String> get imagePaths => _imagePaths;
  int get currentImageIndex => _currentImageIndex;
  String get currentImagePath => _imagePaths.isNotEmpty
      ? _imagePaths[_currentImageIndex % _imagePaths.length]
      : '';

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
      _screensaverFolderPath = prefs.getString(_keyScreensaverFolderPath) ?? '';
      _rotationIntervalSeconds = prefs.getInt(_keyScreensaverRotationInterval) ?? defaultRotationInterval;
      _useFolder = prefs.getBool(_keyScreensaverUseFolder) ?? false;
      _dakboardUrl = prefs.getString(_keyDakboardUrl) ?? '';
      _useDakboard = prefs.getBool(_keyUseDakboard) ?? false;

      // Load images from folder if using folder mode
      if (_useFolder && _screensaverFolderPath.isNotEmpty) {
        await loadImagesFromFolder();
      }

      debugPrint('KioskService initialized: enabled=$_isEnabled, timeout=$_inactivityTimeoutMinutes min');
    } catch (e) {
      debugPrint('Error initializing KioskService: $e');
    }
  }

  /// Load images from the specified folder path
  Future<void> loadImagesFromFolder() async {
    _imagePaths = [];

    if (_screensaverFolderPath.isEmpty) return;

    try {
      // Check if it's a network URL (folder listing) or local path
      if (_screensaverFolderPath.startsWith('http')) {
        // For network URLs, we expect a comma-separated list of image URLs
        // Or a base URL where images are named image1.jpg, image2.jpg, etc.
        // User should provide comma-separated URLs
        _imagePaths = _screensaverFolderPath
            .split(',')
            .map((url) => url.trim())
            .where((url) => url.isNotEmpty)
            .toList();
      } else if (!kIsWeb) {
        // Local file system path (for Raspberry Pi)
        final directory = Directory(_screensaverFolderPath);
        if (await directory.exists()) {
          final files = await directory.list().toList();
          _imagePaths = files
              .where((file) => file is File)
              .map((file) => file.path)
              .where((path) => _isImageFile(path))
              .toList();
          _imagePaths.sort(); // Sort alphabetically
        }
      }

      debugPrint('Loaded ${_imagePaths.length} images from folder');
    } catch (e) {
      debugPrint('Error loading images from folder: $e');
    }
  }

  /// Check if a file path is an image
  bool _isImageFile(String path) {
    final lowerPath = path.toLowerCase();
    return lowerPath.endsWith('.jpg') ||
           lowerPath.endsWith('.jpeg') ||
           lowerPath.endsWith('.png') ||
           lowerPath.endsWith('.gif') ||
           lowerPath.endsWith('.webp') ||
           lowerPath.endsWith('.bmp');
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

  /// Register callback for image rotation changes
  void registerImageChangeCallback(VoidCallback callback) {
    _onImageChanged = callback;
  }

  /// Called when user activity is detected - resets all timers
  void onUserActivity() {
    if (!_isEnabled) return;

    // Deactivate screensaver if active
    if (_isScreensaverActive) {
      _isScreensaverActive = false;
      _stopImageRotation();
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
        _startImageRotation();
        _onScreensaverActivate?.call();
      },
    );
  }

  /// Start image rotation timer
  void _startImageRotation() {
    if (!_useFolder || _imagePaths.isEmpty) return;

    _currentImageIndex = 0;
    _imageRotationTimer?.cancel();
    _imageRotationTimer = Timer.periodic(
      Duration(seconds: _rotationIntervalSeconds),
      (timer) {
        _currentImageIndex = (_currentImageIndex + 1) % _imagePaths.length;
        debugPrint('Kiosk: Rotating to image ${_currentImageIndex + 1}/${_imagePaths.length}');
        _onImageChanged?.call();
      },
    );
  }

  /// Stop image rotation timer
  void _stopImageRotation() {
    _imageRotationTimer?.cancel();
    _imageRotationTimer = null;
    _currentImageIndex = 0;
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
    _stopImageRotation();
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
    String? screensaverFolderPath,
    int? rotationIntervalSeconds,
    bool? useFolder,
    String? dakboardUrl,
    bool? useDakboard,
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

      if (screensaverFolderPath != null) {
        _screensaverFolderPath = screensaverFolderPath;
        await prefs.setString(_keyScreensaverFolderPath, screensaverFolderPath);
      }

      if (rotationIntervalSeconds != null) {
        _rotationIntervalSeconds = rotationIntervalSeconds;
        await prefs.setInt(_keyScreensaverRotationInterval, rotationIntervalSeconds);
      }

      if (useFolder != null) {
        _useFolder = useFolder;
        await prefs.setBool(_keyScreensaverUseFolder, useFolder);
      }

      if (dakboardUrl != null) {
        _dakboardUrl = dakboardUrl;
        await prefs.setString(_keyDakboardUrl, dakboardUrl);
      }

      if (useDakboard != null) {
        _useDakboard = useDakboard;
        await prefs.setBool(_keyUseDakboard, useDakboard);
      }

      // Reload images if folder settings changed
      if (_useFolder && _screensaverFolderPath.isNotEmpty) {
        await loadImagesFromFolder();
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
    _onImageChanged = null;
  }
}
