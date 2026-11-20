import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

import 'app_check_debug_stub.dart'
    if (dart.library.js_interop) 'app_check_debug_web.dart';

/// Firebase App Check: proves to the database that a request comes from this
/// app on its own website, so someone with the app's public Firebase keys is
/// turned away. Enforcement is a switch in the Firebase console (it covers the
/// whole project, the WePlan phone app too); while it is on, a build without
/// App Check can't load any calendar.
///
/// The web build (the Raspberry Pi display) uses reCAPTCHA Enterprise. The key
/// only works on helloseanation.github.io, so a copy of the app run anywhere
/// else gets no token. Other platforms are left out.
class AppCheckService {
  const AppCheckService._();

  /// The reCAPTCHA Enterprise site key ("WePlan Pi (web)" in Google Cloud >
  /// Security > reCAPTCHA). It is public by design: it only works on the
  /// domains listed on the key.
  static const String recaptchaSiteKey =
      '6LddbCkuAAAAAHwmeM7b5XWN9Po7vHRLBwOdDKdX';

  /// A debug token for testing on this computer, which the reCAPTCHA key
  /// refuses (localhost is not on it). It is a secret, so it only comes from
  /// the gitignored `app_check_debug.json`; the build that goes to GitHub
  /// Pages never has one. See GITHUB_PAGES_DEPLOY.md, "App Check".
  static const String _debugToken = String.fromEnvironment(
    'APP_CHECK_DEBUG_TOKEN',
  );

  static bool _activated = false;

  /// The provider the web build uses.
  static ReCaptchaEnterpriseProvider webProvider() =>
      ReCaptchaEnterpriseProvider(recaptchaSiteKey);

  /// Turns App Check on, once Firebase has started; later calls do nothing.
  /// It never throws: if it can't start, the app carries on (and only loses
  /// the database while enforcement is on).
  static Future<void> activate() async {
    if (!kIsWeb || _activated) return;
    _activated = true;
    try {
      if (_debugToken.isNotEmpty) setWebDebugToken(_debugToken);
      await FirebaseAppCheck.instance.activate(webProvider: webProvider());
    } catch (e) {
      debugPrint('App Check not started: $e');
    }
  }
}
