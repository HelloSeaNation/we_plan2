import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Hands the Firebase JS SDK a debug token: when it is set before App Check
/// starts, the SDK uses its debug provider instead of reCAPTCHA. The token
/// must be registered in Firebase console > App Check > Apps > ann > Manage
/// debug tokens.
void setWebDebugToken(String token) {
  globalContext['FIREBASE_APPCHECK_DEBUG_TOKEN'] = token.toJS;
}
