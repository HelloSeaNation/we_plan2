import 'package:flutter/material.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

// Web implementation using iframe
Widget buildDakboardIframe(String url) {
  final String viewType = 'dakboard-iframe-${url.hashCode}';

  // Register the iframe view factory
  ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
    final iframe = html.IFrameElement()
      ..src = url
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..allow = 'fullscreen'
      ..setAttribute('allowfullscreen', 'true');
    return iframe;
  });

  return SizedBox(
    width: double.infinity,
    height: double.infinity,
    child: HtmlElementView(viewType: viewType),
  );
}
