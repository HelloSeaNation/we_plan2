import 'package:flutter/material.dart';

/// A container that centers its content with a maximum width.
/// Useful for keeping content at a reasonable width on large screens.
class CenteredContainer extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final BoxDecoration? decoration;
  final Alignment alignment;

  /// Creates a centered container with a maximum width.
  ///
  /// The [child] parameter is required and represents the content to be centered.
  /// The [maxWidth] parameter defaults to 1200, which is a common max width for web content.
  /// The [padding] parameter defaults to 16 pixels on all sides.
  /// The [alignment] parameter defaults to Alignment.center.
  const CenteredContainer({
    Key? key,
    required this.child,
    this.maxWidth = 1200,
    this.padding = const EdgeInsets.all(16),
    this.backgroundColor,
    this.decoration,
    this.alignment = Alignment.center,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        padding: padding,
        decoration: decoration,
        color: backgroundColor,
        width: double.infinity,
        child: child,
      ),
    );
  }
}
