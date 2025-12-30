/// QR Code Scanner Screen
///
/// Allows users to scan a QR code from Music Assistant to get the Remote Access ID.
/// This is a completely NEW screen that doesn't modify any existing screens.

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  MobileScannerController? controller;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
    );
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  void _handleBarcode(BarcodeCapture capture) {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final String? code = barcode.rawValue;
      if (code != null && code.isNotEmpty) {
        setState(() => _isProcessing = true);
        
        // Extract Remote ID from QR code
        // The QR code from MA can be in various formats:
        // 1. Just the ID: "XXXX-XXXX-XXXX"
        // 2. URL with path: "https://example.com/remote/XXXX-XXXX-XXXX"
        // 3. URL with query: "https://example.com?id=XXXX-XXXX-XXXX"
        // 4. Protocol scheme: "ma-remote://XXXX-XXXX-XXXX"
        
        String remoteId = code;
        
        if (code.startsWith('ma-remote://')) {
          // Protocol scheme format
          remoteId = code.substring('ma-remote://'.length);
        } else if (code.startsWith('http://') || code.startsWith('https://')) {
          // Full URL - extract ID from path or query
          final uri = Uri.tryParse(code);
          if (uri != null) {
            // Try query parameter first
            if (uri.queryParameters.containsKey('id')) {
              remoteId = uri.queryParameters['id']!;
            } else if (uri.queryParameters.containsKey('remote_id')) {
              remoteId = uri.queryParameters['remote_id']!;
            } else {
              // Extract from path (e.g., /remote/XXXX-XXXX-XXXX)
              final pathSegments = uri.pathSegments;
              if (pathSegments.isNotEmpty) {
                remoteId = pathSegments.last;
              }
            }
          }
        }
        
        // Clean up the ID (remove any trailing slashes, whitespace)
        remoteId = remoteId.trim();
        while (remoteId.endsWith('/')) {
          remoteId = remoteId.substring(0, remoteId.length - 1);
        }

        // Return the scanned ID
        Navigator.of(context).pop(remoteId);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        backgroundColor: Colors.black.withOpacity(0.5),
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Camera preview
          MobileScanner(
            controller: controller,
            onDetect: _handleBarcode,
          ),

          // Overlay with instructions
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.9),
                    Colors.black.withOpacity(0.0),
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.qr_code_scanner_rounded,
                    size: 64,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Point your camera at the QR code',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'The QR code can be found in Music Assistant\nunder Settings → Remote Access',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  // Manual entry button
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop(); // Return to previous screen for manual entry
                    },
                    icon: const Icon(Icons.keyboard),
                    label: const Text('Enter ID Manually'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withOpacity(0.5)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Loading overlay
          if (_isProcessing)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
