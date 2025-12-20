import 'dart:io' as io;
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'platform_interface.dart';

class PlatformLinux implements PlatformInterface {
  @override
  String get operatingSystem => io.Platform.operatingSystem;

  @override
  bool get isAndroid => false;

  @override
  bool get isIOS => false;

  @override
  bool get isWeb => false;

  @override
  Future<String> getDeviceId() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      
      if (io.Platform.isLinux) {
        final linuxInfo = await deviceInfo.linuxInfo;
        // Create a unique device identifier using Linux system information
        final identifier = 'LINUX-'
            '${linuxInfo.machineId}-'
            '${linuxInfo.name}-'
            '${linuxInfo.prettyName}';
        
        // Hash it for consistency
        final bytes = utf8.encode(identifier);
        final hash = sha256.convert(bytes);
        return 'LINUX-${hash.toString().substring(0, 16)}';
      }
      
      // Fallback for other Unix-like systems
      return 'LINUX-${DateTime.now().millisecondsSinceEpoch}';
    } catch (e) {
      // Fallback if device info fails
      return 'LINUX-${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  @override
  Future<void> requestPermissions() async {
    // Linux desktop apps typically don't need runtime permissions
    // like mobile platforms do
    // This is a no-op for Linux
  }

  @override
  void redirectToUrl(String url) {
    // On Linux, we could open the URL in the default browser
    // For now, this is a no-op as the main use case is web
  }
}

