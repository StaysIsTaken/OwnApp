import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Vollbild-Scanner. Beim ersten erkannten Barcode wird der Code per
/// Navigator.pop zurückgegeben.
class BarcodeScanPage extends StatefulWidget {
  const BarcodeScanPage({super.key});

  @override
  State<BarcodeScanPage> createState() => _BarcodeScanPageState();
}

class _BarcodeScanPageState extends State<BarcodeScanPage> {
  bool _handled = false;

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final code = capture.barcodes.isNotEmpty
        ? capture.barcodes.first.rawValue
        : null;
    if (code != null && code.isNotEmpty) {
      _handled = true;
      Navigator.of(context).pop(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Barcode scannen')),
      body: Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(onDetect: _onDetect),
          // Einfacher Zielrahmen
          Container(
            width: 240,
            height: 160,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white70, width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const Positioned(
            bottom: 40,
            child: Text(
              'Barcode ins Feld halten',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
