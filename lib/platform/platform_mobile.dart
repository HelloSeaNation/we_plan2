import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'platform_interface.dart';

class PlatformMobile implements PlatformInterface {
  @override
  String get operatingSystem => Platform.operatingSystem;

  @override
  bool get isAndroid => Platform.isAndroid;

  @override
  bool get isIOS => Platform.isIOS;

  @override
  bool get isWeb => false;

  @override
  Future<String> getDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();

    if (isAndroid) {
      if (await Permission.phone.status.isGranted) {
        final androidInfo = await deviceInfo.androidInfo;
        return 'ANDROID-'
            '${androidInfo.model}-'
            '${androidInfo.version.sdkInt}-'
            '${androidInfo.board}-'
            '${androidInfo.hardware}';
      } else {
        return 'ANDROID-${DateTime.now().millisecondsSinceEpoch}';
      }
    } else if (isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return 'IOS-${iosInfo.model}-${iosInfo.systemVersion}';
    } else {
      return 'UNKNOWN-$operatingSystem-${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  @override
  Future<void> requestPermissions() async {
    if (isAndroid) {
      await Permission.phone.request();
    }
  }

  @override
  void redirectToUrl(String url) {
    // Not supported on mobile - use url_launcher instead if needed
  }

  @override
  bool get isFullscreen => false;

  @override
  void toggleFullscreen() {
    // Not supported on mobile
  }
}
