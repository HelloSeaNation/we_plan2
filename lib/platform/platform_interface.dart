abstract class PlatformInterface {
  String get operatingSystem;
  bool get isAndroid;
  bool get isIOS;
  bool get isWeb;
  Future<String> getDeviceId();
  Future<void> requestPermissions();

  /// Redirect the browser to a different URL (web only)
  void redirectToUrl(String url);
}
