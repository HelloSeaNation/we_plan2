import 'dart:io' as io show Platform;
import 'package:flutter/foundation.dart';
import 'platform_interface.dart';

// Import the correct implementation based on platform
import 'platform_mobile.dart';
import 'platform_linux.dart';

// For web, we'll use a stub implementation that doesn't require dart:html
// We'll create this stub separately
import 'platform_stub.dart' if (dart.library.html) 'platform_web.dart'
    as platform_impl;

class Platform {
  static PlatformInterface get instance {
    if (kIsWeb) {
      return platform_impl.createPlatformImplementation();
    } else if (!kIsWeb && io.Platform.isLinux) {
      return PlatformLinux();
    } else {
      return PlatformMobile();
    }
  }
}
