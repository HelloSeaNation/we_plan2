import 'dart:io' as io;
import 'package:flutter/material.dart';
import "firestore_service.dart";
import 'package:quickalert/quickalert.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart';
// Mobile scanner only available on mobile platforms
import 'package:mobile_scanner/mobile_scanner.dart';

class ShareSetupScreen extends StatefulWidget {
  final bool isFirstTime;
  const ShareSetupScreen({super.key, this.isFirstTime = true});

  @override
  State<ShareSetupScreen> createState() => _ShareSetupScreenState();
}

class _ShareSetupScreenState extends State<ShareSetupScreen> {
  final _codeController = TextEditingController();
  bool _isCreatingNew = true;
  bool _isScanning = false;
  MobileScannerController? _mobileScannerController;
  bool _isLoading = false;
  Color _themeColor = Colors.blue;

  @override
  void initState() {
    super.initState();
    _loadThemeColor();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _mobileScannerController?.dispose();
    super.dispose();
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

  // Check if QR scanning is supported (mobile platforms only)
  bool get _isQRScanSupported {
    if (io.Platform.isAndroid || io.Platform.isIOS) {
      return true;
    }
    return false;
  }

  Future<void> _scanQRCode() async {
    if (!_isQRScanSupported) return;
    
    setState(() {
      _isScanning = true;
      _mobileScannerController = MobileScannerController(
        detectionSpeed: DetectionSpeed.normal,
        facing: CameraFacing.back,
      );
    });
  }

  Future<void> _handleCreateOrJoin() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();

      if (_isCreatingNew) {
        // Only show warning when creating (not first time)
        if (!widget.isFirstTime) {
          bool? confirmCreate = await QuickAlert.show(
            context: context,
            type: QuickAlertType.warning,
            title: 'Warning',
            text:
                'Creating a new calendar will permanently delete '
                'all events from your current calendar',
            confirmBtnText: 'Continue',
            cancelBtnText: 'Cancel',
            confirmBtnColor: Colors.red,
            showCancelBtn: true,
            onConfirmBtnTap: () {
              Navigator.of(context).pop(true);
            },
            onCancelBtnTap: () {
              Navigator.of(context).pop(false);
            },
          );

          if (confirmCreate != true) {
            setState(() => _isLoading = false);
            return;
          }
        }

        // Show loading indicator
        await QuickAlert.show(
          context: context,
          type: QuickAlertType.loading,
          title: 'Creating',
          text: 'Setting up your new calendar',
          autoCloseDuration: const Duration(seconds: 1),
        );

        await FirestoreService.initialize();
        await prefs.setString('shareCode', FirestoreService.shareCode);
      } else {
        // Join existing calendar
        if (_codeController.text.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enter or scan a share code')),
          );
          setState(() => _isLoading = false);
          return;
        }

        // Show loading indicator
        await QuickAlert.show(
          context: context,
          type: QuickAlertType.loading,
          title: 'Joining',
          text: 'Connecting to calendar',
          autoCloseDuration: const Duration(seconds: 1),
        );

        bool isValid = await FirestoreService.validateShareCode(
          _codeController.text,
        );
        if (!isValid) {
          // First dismiss any existing loading dialog
          Navigator.of(context).popUntil((route) => route.isFirst);

          QuickAlert.show(
            context: context,
            type: QuickAlertType.error,
            title: 'Wrong code',
            text: 'The share code you entered is invalid or does not exist.',
            confirmBtnText: 'OK',
            confirmBtnColor: Theme.of(context).colorScheme.primary,
          );
          setState(() => _isLoading = false);
          return;
        }
        await prefs.setString('shareCode', _codeController.text);
      }

      if (mounted) {
        // Initialize Firebase with the share code
        await FirestoreService.initialize(
          shareCode: _isCreatingNew ? null : _codeController.text,
        );

        // Navigate to the main calendar page
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const MyHomePage(title: '')),
          (route) => false, // Removes all previous routes
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: colorScheme.surface,
      ),
      body: (_isScanning && _isQRScanSupported) 
          ? _buildScannerView() 
          : _buildSetupView(colorScheme),
    );
  }

  Widget _buildScannerView() {
    return Stack(
      children: [
        MobileScanner(
          controller: _mobileScannerController,
          onDetect: (capture) {
            final List<Barcode> barcodes = capture.barcodes;
            for (final barcode in barcodes) {
              if (barcode.rawValue != null) {
                setState(() {
                  _codeController.text = barcode.rawValue!;
                  _isScanning = false;
                  _mobileScannerController?.stop();
                });
                break;
              }
            }
          },
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Align(
              alignment: Alignment.topRight,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(30),
                color: Colors.white.withOpacity(0.9),
                child: InkWell(
                  borderRadius: BorderRadius.circular(30),
                  onTap: () {
                    setState(() {
                      _isScanning = false;
                      _mobileScannerController?.stop();
                    });
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(Icons.close, size: 30),
                  ),
                ),
              ),
            ),
          ),
        ),
        Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.7,
            height: MediaQuery.of(context).size.width * 0.7,
            decoration: BoxDecoration(
              border: Border.all(
                color: _themeColor,
                width: 3,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 40),
            child: Text(
              'Align QR code within the frame',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    offset: const Offset(0, 1),
                    blurRadius: 3.0,
                    color: Colors.black.withOpacity(0.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSetupView(ColorScheme colorScheme) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Text(
                'Calendar Sharing',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                widget.isFirstTime
                    ? 'Welcome! Choose how you want to set up your calendar.'
                    : 'Choose whether to create a new calendar or join an existing one.',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              const SizedBox(height: 32),

              // Option cards
              _buildOptionCard(
                isSelected: _isCreatingNew,
                icon: Icons.add_circle_outline,
                title: 'Create new calendar',
                description: 'Start fresh with a new shared calendar',
                onTap: () => setState(() => _isCreatingNew = true),
                colorScheme: colorScheme,
              ),

              const SizedBox(height: 16),

              _buildOptionCard(
                isSelected: !_isCreatingNew,
                icon: Icons.people_outline,
                title: 'Join existing calendar',
                description:
                    'Connect to a calendar someone has shared with you',
                onTap: () => setState(() => _isCreatingNew = false),
                colorScheme: colorScheme,
              ),

              // Join code input
              if (!_isCreatingNew) ...[
                const SizedBox(height: 24),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: colorScheme.surface,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _codeController,
                    decoration: InputDecoration(
                      labelText: 'Enter share code',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      fillColor: Colors.grey[100],
                      filled: true,
                      prefixIcon: const Icon(Icons.tag),
                      suffixIcon: _isQRScanSupported
                          ? IconButton(
                              icon: const Icon(Icons.qr_code_scanner),
                              onPressed: _scanQRCode,
                              tooltip: 'Scan QR code',
                            )
                          : null,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Text(
                    'This code was shared with you by another user',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Action button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleCreateOrJoin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _themeColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                  ),
                  child:
                      _isLoading
                          ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                          : Text(
                            _isCreatingNew
                                ? 'Create Calendar'
                                : 'Join Calendar',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required bool isSelected,
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? _themeColor : Colors.grey[300]!,
            width: 2,
          ),
          color:
              isSelected
                  ? _themeColor.withOpacity(0.05)
                  : Colors.transparent,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    isSelected
                        ? _themeColor.withOpacity(0.1)
                        : Colors.grey[100],
              ),
              child: Icon(
                icon,
                color: isSelected ? _themeColor : Colors.grey[600],
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? _themeColor : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Radio(
              value: isSelected,
              groupValue: true,
              onChanged: (_) => onTap(),
              activeColor: _themeColor,
            ),
          ],
        ),
      ),
    );
  }
}
