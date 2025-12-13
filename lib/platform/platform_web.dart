import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'platform_interface.dart';
import 'dart:html' as html;
import 'dart:convert';
import 'package:crypto/crypto.dart';

// This function will be called from platform.dart
PlatformInterface createPlatformImplementation() {
  return PlatformWeb();
}

class PlatformWeb implements PlatformInterface {
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

      // Create a web fingerprint using available browser info
      final fingerprint = 'WEB-'
          '${webInfo.browserName.toString()}-'
          '${webInfo.platform ?? 'unknown'}-'
          '${webInfo.language ?? 'unknown'}-'
          '${html.window.navigator.userAgent}-'
          '${html.window.screen?.width ?? 0}x${html.window.screen?.height ?? 0}';

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
}
