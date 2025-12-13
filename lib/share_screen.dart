import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:we_plan2/main.dart';
import 'package:we_plan2/share_setup_screen.dart';

class ShareScreen extends StatefulWidget {
  final String shareCode;
  final bool isFirstTimeUser;

  const ShareScreen({
    super.key,
    required this.shareCode,
    this.isFirstTimeUser = true,
  });

  @override
  State<ShareScreen> createState() => _ShareScreenState();
}

class _ShareScreenState extends State<ShareScreen> {
  Color _themeColor = Colors.blue; // Default color

  @override
  void initState() {
    super.initState();
    _loadThemeColor();
  }

  Future<void> _loadThemeColor() async {
    final prefs = await SharedPreferences.getInstance();
    final colorValue = prefs.getInt('color_value');
    if (colorValue != null) {
      setState(() {
        _themeColor = Color(colorValue);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isFirstTimeUser ? 'Welcome!' : ''),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // For first-time flow, go to setup screen
            if (widget.isFirstTimeUser) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => ShareSetupScreen(isFirstTime: true),
                ),
              );
            }
            // For non-first-time, go back to calendar
            else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 16.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, size: 72, color: _themeColor),
                const SizedBox(height: 16),
                Text(
                  "Your Calendar is Ready!",
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _themeColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                // QR Code with decorative frame
                Card(
                  elevation: 1,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          child: QrImageView(
                            data: widget.shareCode,
                            version: QrVersions.auto,
                            size: 200.0,
                            eyeStyle: QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: _themeColor.withOpacity(0.8),
                            ),
                            dataModuleStyle: QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: _themeColor.withOpacity(0.8),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 20,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.shareCode,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.copy,
                                  size: 20,
                                  color: _themeColor.withOpacity(0.8),
                                ),
                                tooltip: 'Copy to clipboard',
                                onPressed: () {
                                  // Copy to clipboard
                                  Share.share(widget.shareCode);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text(
                                        'Code copied to clipboard',
                                      ),
                                      duration: const Duration(seconds: 2),
                                      backgroundColor: _themeColor,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),
                if (widget.isFirstTimeUser)
                  ElevatedButton(
                    onPressed: () {
                      WidgetsBinding.instance.addPostFrameCallback((_) async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('first_time', false);
                      });
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) =>
                                  const MyHomePage(title: ''),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _themeColor,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      "Let's Get Started!",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                if (!widget.isFirstTimeUser) const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
