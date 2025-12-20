import 'package:flutter/material.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'dart:async';

// Web implementation using iframe with loading indicator
class DakboardIframeWidget extends StatefulWidget {
  final String url;

  const DakboardIframeWidget({super.key, required this.url});

  @override
  State<DakboardIframeWidget> createState() => _DakboardIframeWidgetState();
}

class _DakboardIframeWidgetState extends State<DakboardIframeWidget> {
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  late String _viewType;
  html.IFrameElement? _iframe;
  Timer? _loadingTimer;

  @override
  void initState() {
    super.initState();
    _viewType = 'dakboard-iframe-${widget.url.hashCode}-${DateTime.now().millisecondsSinceEpoch}';
    _registerIframe();

    // Set a timeout - if still loading after 15 seconds, show error
    _loadingTimer = Timer(const Duration(seconds: 15), () {
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Dakboard is taking too long to load.\nCheck your URL or internet connection.';
        });
      }
    });
  }

  void _registerIframe() {
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      _iframe = html.IFrameElement()
        ..src = widget.url
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.backgroundColor = 'black'
        // Allow various permissions for Dakboard to work properly
        ..allow = 'fullscreen; autoplay; encrypted-media; picture-in-picture; geolocation'
        ..setAttribute('allowfullscreen', 'true')
        ..setAttribute('referrerpolicy', 'no-referrer-when-downgrade')
        ..setAttribute('loading', 'eager');

      // Listen for load event
      _iframe!.onLoad.listen((_) {
        if (mounted) {
          _loadingTimer?.cancel();
          setState(() {
            _isLoading = false;
            _hasError = false;
          });
        }
      });

      // Listen for error event
      _iframe!.onError.listen((_) {
        if (mounted) {
          _loadingTimer?.cancel();
          setState(() {
            _isLoading = false;
            _hasError = true;
            _errorMessage = 'Failed to load Dakboard.\nThe URL may be invalid or blocked.';
          });
        }
      });

      return _iframe!;
    });
  }

  @override
  void dispose() {
    _loadingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // The iframe
        SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: HtmlElementView(viewType: _viewType),
        ),

        // Loading overlay
        if (_isLoading)
          Container(
            color: Colors.black,
            width: double.infinity,
            height: double.infinity,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Loading Dakboard...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.url,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),

        // Error overlay
        if (_hasError)
          Container(
            color: Colors.black,
            width: double.infinity,
            height: double.infinity,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Colors.red[400],
                    size: 64,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _errorMessage,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.url,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Tap anywhere to dismiss',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// Wrapper function to maintain backward compatibility
Widget buildDakboardIframe(String url) {
  return DakboardIframeWidget(url: url);
}
