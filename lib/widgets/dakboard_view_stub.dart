import 'package:flutter/material.dart';

// Stub implementation for non-web platforms
Widget buildDakboardIframe(String url) {
  // This should never be called on non-web platforms
  // Return empty container as fallback
  return Container(
    color: Colors.black,
    child: const Center(
      child: Text(
        'Dakboard WebView not available',
        style: TextStyle(color: Colors.white),
      ),
    ),
  );
}
