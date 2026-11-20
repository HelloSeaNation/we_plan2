import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:we_plan2/firebase_options.dart';
import 'package:we_plan2/services/app_check_service.dart';

void main() {
  test('the web build uses reCAPTCHA Enterprise with the Pi site key', () {
    final provider = AppCheckService.webProvider();
    expect(provider, isA<ReCaptchaEnterpriseProvider>());
    expect(provider.siteKey, AppCheckService.recaptchaSiteKey);
    expect(AppCheckService.recaptchaSiteKey, startsWith('6L'));
  });

  test('the web build is the web app registered for App Check', () {
    // App Check refuses tokens for an app id that isn't registered; the old
    // web id was the Android one with "web" in it.
    expect(
      DefaultFirebaseOptions.web.appId,
      '1:1013851184422:web:f272132176c7a5ef87f5e7',
    );
    expect(
      DefaultFirebaseOptions.web.appId,
      isNot(contains('c0038858f774ab9787f5e7')),
    );
  });

  test('activate does nothing outside the web', () async {
    // Tests run on the VM: no Firebase app exists, so a call that reached
    // FirebaseAppCheck would throw inside, and activate must still return.
    await expectLater(AppCheckService.activate(), completes);
  });
}
