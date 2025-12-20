import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dakboard_view.dart' as dakboard_view;

/// Full-screen Dakboard display page with tap-to-return functionality
class DakboardDisplayPage extends StatelessWidget {
  final String dakboardUrl;

  const DakboardDisplayPage({
    super.key,
    required this.dakboardUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Dakboard content (iframe on web, WebView on mobile)
          if (kIsWeb)
            SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: dakboard_view.buildDakboardIframe(dakboardUrl),
            )
          else
            Container(
              color: Colors.black,
              child: const Center(
                child: Text(
                  'Dakboard display is only supported on web',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),

          // Transparent tap overlay - tap anywhere to return
          // Use Listener for raw pointer events - more reliable on Raspberry Pi
          Positioned.fill(
            child: Listener(
              onPointerDown: (_) => Navigator.of(context).pop(),
              behavior: HitTestBehavior.opaque,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => Navigator.of(context).pop(),
                onPanDown: (_) => Navigator.of(context).pop(),
                child: Container(
                  color: Colors.transparent,
                ),
              ),
            ),
          ),

          // Small hint at bottom (fades out after a few seconds)
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: _FadingHint(),
          ),
        ],
      ),
    );
  }
}

/// A hint that fades out after a few seconds
class _FadingHint extends StatefulWidget {
  @override
  State<_FadingHint> createState() => _FadingHintState();
}

class _FadingHintState extends State<_FadingHint> {
  double _opacity = 1.0;

  @override
  void initState() {
    super.initState();
    // Start fading after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _opacity = 0.0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _opacity,
      duration: const Duration(seconds: 2),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        margin: const EdgeInsets.symmetric(horizontal: 40),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(30),
        ),
        child: const Text(
          'Tap anywhere to return to calendar',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
