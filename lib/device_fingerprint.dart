import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'platform/platform.dart';

class DeviceFingerprint {
  static Future<String> generate() async {
    return Platform.instance.getDeviceId();
  }
}
