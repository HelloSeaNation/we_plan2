import 'package:flutter/material.dart';
import '../utils/responsive.dart';

/// A widget that adapts to different screen sizes.
/// It will show different layouts based on the screen size:
/// - Mobile: screen width < 650
/// - Tablet: screen width >= 650 && < 1100
/// - Desktop: screen width >= 1100
class ResponsiveLayout extends StatelessWidget {
  final Widget mobileLayout;
  final Widget? tabletLayout;
  final Widget desktopLayout;

  /// Creates a responsive layout.
  /// [mobileLayout] is used for small screens (< 650 width)
  /// [tabletLayout] is used for medium screens (>= 650 && < 1100 width)
  /// [desktopLayout] is used for large screens (>= 1100 width)
  ///
  /// If [tabletLayout] is null, [mobileLayout] is used for tablet screens.
  const ResponsiveLayout({
    Key? key,
    required this.mobileLayout,
    this.tabletLayout,
    required this.desktopLayout,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (Responsive.isDesktop(context)) {
          return desktopLayout;
        } else if (Responsive.isTablet(context)) {
          return tabletLayout ?? mobileLayout;
        } else {
          return mobileLayout;
        }
      },
    );
  }
}
