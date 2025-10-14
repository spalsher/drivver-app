import 'dart:io';
import 'dart:typed_data'; // Added for Uint8List
import 'package:flutter/material.dart';
import 'package:drivrr_driver/src/core/services/document_processing_service.dart';
import 'package:drivrr_driver/src/core/services/smart_id_scanner_service.dart';
import 'package:path_provider/path_provider.dart'; // Added for getTemporaryDirectory
import 'package:path/path.dart' as p; // Alias to avoid name clash with BuildContext

/// An intelligent document scanner that uses a native, high-performance
/// library for edge detection, quality analysis, and auto-capture.
class SmartDocumentScanner extends StatefulWidget {
  final String documentType;
  final Function(File imageFile, Map<String, dynamic> extractedData) onDocumentScanned;

  const SmartDocumentScanner({
    super.key,
    required this.documentType,
    required this.onDocumentScanned,
  });

  @override
  State<SmartDocumentScanner> createState() => _SmartDocumentScannerState();
}

class _SmartDocumentScannerState extends State<SmartDocumentScanner> {
  final _processingService = DocumentProcessingService();
  final _nativeScanner = SmartIdScannerService();
  bool _isProcessing = false;

  Future<void> _scanDocument() async {
    if (_isProcessing) return;
    setState(() { _isProcessing = true; });

    try {
      final result = await _nativeScanner.scanDocument();
      final processingResult = await _processingService.processScanResult(result.imageFile, result.text, result.blocks);

      if (!mounted) return;

      // Check if extraction quality is good enough
      if (processingResult.validationResult?.needsRetry == true) {
        // Show dialog asking user to rescan for better quality
        if (mounted) {
          await _showRetryDialog();
          setState(() { _isProcessing = false; });
          return;
        }
      }

      // Extraction is good, proceed
      widget.onDocumentScanned(processingResult.imageFile, processingResult.extractedData);
    } catch (e) {
      debugPrint('Native scan error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scan failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isProcessing = false; });
      }
    }
  }

  Future<void> _showRetryDialog() async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Better Quality Needed'),
          ],
        ),
        content: const Text(
          'The document scan could be clearer. Please rescan for better extraction accuracy.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continue Anyway'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _scanDocument(); // Retry scan
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
            ),
            child: const Text('Rescan'),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Scan ${widget.documentType}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_alt),
            onPressed: _scanDocument,
          ),
        ],
      ),
      body: Stack(
        children: [
          // No inline camera widget; we rely on native UI for stability and auto-capture
          const SizedBox.shrink(),

          if (_isProcessing)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 20),
                    Text(
                      'Processing Document...',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}