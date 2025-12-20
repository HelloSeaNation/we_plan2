import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'platform_interface.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

// This function will be called from platform.dart
PlatformInterface createPlatformImplementation() {
  return PlatformStub();
}

// Stub implementation for non-web platforms
class PlatformStub implements PlatformInterface {
  @override
  String get operatingSystem => 'web';

  @override
  bool get isAndroid => false;

  @override
  bool get isIOS => false;

  @override
  bool get isWeb => true;

  @override
  Future<String> getDeviceId() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final webInfo = await deviceInfo.webBrowserInfo;

      // Create a simplified fingerprint using non-html info
      final fingerprint = 'WEB-'
          '${webInfo.browserName.toString()}-'
          '${webInfo.platform ?? 'unknown'}-'
          '${webInfo.language ?? 'unknown'}-'
          '${DateTime.now().millisecondsSinceEpoch}';

      // Hash the fingerprint for privacy
      return sha256.convert(utf8.encode(fingerprint)).toString();
    } catch (e) {
      debugPrint('Error getting web device ID: $e');
      // Fallback to a temporary ID
      return 'WEB-${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  @override
  Future<void> requestPermissions() async {
    // Web doesn't need the same permissions as mobile
    return;
  }

  @override
  void redirectToUrl(String url) {
    // Stub implementation - does nothing on non-web platforms
    debugPrint('redirectToUrl is only supported on web platform');
  }
}
