// Stub file for mobile_scanner on web platform
// This provides empty implementations so the app compiles on web

import 'package:flutter/material.dart';

enum DetectionSpeed { normal, fast, noDuplicates }
enum CameraFacing { front, back }

class MobileScannerController {
  MobileScannerController({
    DetectionSpeed? detectionSpeed,
    CameraFacing? facing,
  });

  Future<void> stop() async {}
  void dispose() {}
}

class Barcode {
  final String? rawValue;
  Barcode({this.rawValue});
}

class BarcodeCapture {
  final List<Barcode> barcodes;
  BarcodeCapture({this.barcodes = const []});
}

class MobileScanner extends StatelessWidget {
  final MobileScannerController? controller;
  final Function(BarcodeCapture)? onDetect;

  const MobileScanner({
    super.key,
    this.controller,
    this.onDetect,
  });

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
