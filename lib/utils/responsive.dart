import 'package:flutter/material.dart';

class Responsive {
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 600;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= 600 &&
      MediaQuery.of(context).size.width < 1200;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1200;

  /// Returns true if the current device is in landscape orientation
  static bool isLandscape(BuildContext context) =>
      MediaQuery.of(context).orientation == Orientation.landscape;

  /// Safe area for the current platform
  static EdgeInsets safePadding(BuildContext context) =>
      MediaQuery.of(context).padding;

  /// Get the screen width
  static double width(BuildContext context) =>
      MediaQuery.of(context).size.width;

  /// Get the screen height
  static double height(BuildContext context) =>
      MediaQuery.of(context).size.height;

  /// Get a responsive value based on the screen size
  /// [mobile] value for mobile screens
  /// [tablet] value for tablet screens
  /// [desktop] value for desktop screens
  static T getResponsiveValue<T>({
    required BuildContext context,
    required T mobile,
    T? tablet,
    required T desktop,
  }) {
    if (isDesktop(context)) return desktop;
    if (isTablet(context)) return tablet ?? mobile;
    return mobile;
  }
}
