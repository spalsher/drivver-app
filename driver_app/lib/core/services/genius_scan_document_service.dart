import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_genius_scan/flutter_genius_scan.dart';

/// Professional document scanning service using Flutter Genius Scan
/// Provides the best OCR accuracy and document processing capabilities
class GeniusScanDocumentService {
  static bool _isInitialized = false;

  /// Initialize the Genius Scan service
  static Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Initialize Genius Scan SDK with license key (empty for trial)
      FlutterGeniusScan.setLicenseKey(""); // Using trial version - no await needed
      _isInitialized = true;
      debugPrint('✅ Genius Scan Service initialized successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to initialize Genius Scan: $e');
      return false;
    }
  }

  /// Scan document with professional OCR extraction
  static Future<DocumentScanResult> scanDocumentWithOCR({
    required BuildContext context,
    String documentType = 'Driver License',
  }) async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) {
        return DocumentScanResult(
          success: false,
          errorMessage: 'Failed to initialize Genius Scan',
        );
      }
    }

    try {
      debugPrint('📸 Starting Genius Scan for: $documentType');

      // Configure scan settings for optimal document capture
      final scanConfiguration = {
        'source': 'camera',
        'multiPage': false,
        'defaultFilter': 'photo',
        'jpegQuality': 0.9,
        'maxScanDimension': 2000,
        'ocrConfiguration': {
          'languages': ['eng'], // English OCR
          'outputFormats': ['txt', 'searchablePDF'],
        },
      };

      // Start the scanning process
      final result = await FlutterGeniusScan.scanWithConfiguration(scanConfiguration);
      
      if (result != null && result['scans'] != null) {
        final scans = result['scans'] as List;
        if (scans.isNotEmpty) {
          final firstScan = scans.first as Map<String, dynamic>;
          final imagePath = firstScan['enhancedUrl'] as String?;
          final ocrText = firstScan['ocrText'] as String?;
          
          if (imagePath != null) {
            final imageFile = File(imagePath);
            
            debugPrint('✅ Genius Scan completed: $imagePath');
            debugPrint('📄 OCR Text Length: ${ocrText?.length ?? 0} characters');
            
            // Parse the OCR text based on document type
            final parsedData = _parseDocumentText(ocrText ?? '', documentType);
            
            // Calculate confidence based on OCR quality
            final confidence = _calculateOCRConfidence(ocrText ?? '', parsedData);

            return DocumentScanResult(
              success: true,
              imageFile: imageFile,
              extractedText: ocrText ?? '',
              extractedData: parsedData,
              confidence: confidence,
              scanMethod: 'genius_scan_professional',
            );
          }
        }
      }
      
      return DocumentScanResult(
        success: false,
        errorMessage: 'No document scanned or scan cancelled',
      );
      
    } catch (e) {
      debugPrint('❌ Genius Scan error: $e');
      return DocumentScanResult(
        success: false,
        errorMessage: 'Scanning failed: $e',
      );
    }
  }

  /// Parse extracted OCR text based on document type
  static Map<String, dynamic> _parseDocumentText(String extractedText, String documentType) {
    if (documentType.toLowerCase().contains('license')) {
      return _parseDriverLicense(extractedText);
    } else if (documentType.toLowerCase().contains('registration')) {
      return _parseVehicleRegistration(extractedText);
    } else {
      return _parseGenericDocument(extractedText, documentType);
    }
  }

  /// Parse Pakistani driving license from OCR text
  static Map<String, dynamic> _parseDriverLicense(String text) {
    final Map<String, dynamic> parsedData = {};

    try {
      // Enhanced Pakistani Sindh Driving License patterns
      final patterns = {
        'licenseNumber': [
          RegExp(r'License\s+No\.?\s*:?\s*([0-9\-]+)', caseSensitive: false),
          RegExp(r'([0-9]{5}-[0-9]{7}-[0-9]{6})', caseSensitive: false),
          RegExp(r'(\d{5}-\d{7}-\d{6})', caseSensitive: false),
          RegExp(r'No\.?\s*([0-9\-]+)', caseSensitive: false),
        ],
        'fullName': [
          RegExp(r'Name\s*:?\s*([A-Z][A-Z\s]+)', caseSensitive: false),
          RegExp(r'^([A-Z][A-Z\s]+[A-Z])$', multiLine: true),
          RegExp(r'([A-Z]{2,}\s+[A-Z]{2,}\s+[A-Z]{2,})', caseSensitive: false),
        ],
        'fatherName': [
          RegExp(r'Father[\/\s]*Husband\s*:?\s*([A-Z\s]+)', caseSensitive: false),
          RegExp(r'S\/O\s*:?\s*([A-Z\s]+)', caseSensitive: false),
          RegExp(r'Father\s*:?\s*([A-Z\s]+)', caseSensitive: false),
        ],
        'dateOfBirth': [
          RegExp(r'Date\s+of\s+Birth\s*:?\s*(\d{1,2}[-\/]\w{3}[-\/]\d{4})', caseSensitive: false),
          RegExp(r'DOB\s*:?\s*(\d{1,2}[-\/]\w{3}[-\/]\d{4})', caseSensitive: false),
          RegExp(r'(\d{1,2}-\w{3}-\d{4})', caseSensitive: false),
          RegExp(r'(\d{1,2}\/\d{1,2}\/\d{4})', caseSensitive: false),
        ],
        'category': [
          RegExp(r'Category\s*:?\s*([A-Z\s]+)', caseSensitive: false),
          RegExp(r'(MOTOR\s+CAR|MOTORCYCLE|LTV|HTV)', caseSensitive: false),
        ],
        'issueDate': [
          RegExp(r'Issue\s+Date\s*:?\s*(\d{1,2}[-\/]\w{3}[-\/]\d{4})', caseSensitive: false),
          RegExp(r'Issued\s*:?\s*(\d{1,2}[-\/]\w{3}[-\/]\d{4})', caseSensitive: false),
        ],
        'expiryDate': [
          RegExp(r'Valid\s+Till\s*:?\s*(\d{1,2}[-\/]\w{3}[-\/]\d{4})', caseSensitive: false),
          RegExp(r'Expiry\s*:?\s*(\d{1,2}[-\/]\w{3}[-\/]\d{4})', caseSensitive: false),
        ],
        'address': [
          RegExp(r'Address\s*:?\s*([A-Z0-9\s,\-\/]+)', caseSensitive: false),
        ],
      };

      // Extract data using patterns with confidence scoring
      patterns.forEach((field, regexList) {
        for (final regex in regexList) {
          final match = regex.firstMatch(text);
          if (match != null && match.group(1) != null) {
            String value = match.group(1)!.trim();
            
            // Clean up the extracted value
            value = _cleanExtractedText(value);
            
            if (value.isNotEmpty && value.length > 2) {
              parsedData[field] = value;
              debugPrint('✅ Genius Scan extracted $field: $value');
              break; // Use first successful match
            }
          }
        }
      });

      // Add metadata
      parsedData['extractionMethod'] = 'genius_scan_professional_ocr';
      parsedData['documentType'] = 'driving_license';
      parsedData['extractionTimestamp'] = DateTime.now().toIso8601String();
      parsedData['ocrEngine'] = 'genius_scan';
      parsedData['processingQuality'] = 'professional';
      
    } catch (e) {
      debugPrint('❌ License parsing error: $e');
    }

    return parsedData;
  }

  /// Parse vehicle registration document
  static Map<String, dynamic> _parseVehicleRegistration(String text) {
    final Map<String, dynamic> parsedData = {};

    try {
      final patterns = {
        'registrationNumber': [
          RegExp(r'Registration\s+No\.?\s*:?\s*([A-Z0-9\-]+)', caseSensitive: false),
          RegExp(r'Reg\.?\s*No\.?\s*:?\s*([A-Z0-9\-]+)', caseSensitive: false),
        ],
        'ownerName': [
          RegExp(r'Owner\s*:?\s*([A-Z\s]+)', caseSensitive: false),
          RegExp(r'Name\s*:?\s*([A-Z\s]+)', caseSensitive: false),
        ],
        'vehicleMake': [
          RegExp(r'Make\s*:?\s*([A-Z]+)', caseSensitive: false),
          RegExp(r'(TOYOTA|HONDA|SUZUKI|HYUNDAI|KIA|NISSAN)', caseSensitive: false),
        ],
        'vehicleModel': [
          RegExp(r'Model\s*:?\s*([A-Z0-9\s]+)', caseSensitive: false),
        ],
        'year': [
          RegExp(r'Year\s*:?\s*(\d{4})', caseSensitive: false),
          RegExp(r'Model\s+Year\s*:?\s*(\d{4})', caseSensitive: false),
        ],
      };

      patterns.forEach((field, regexList) {
        for (final regex in regexList) {
          final match = regex.firstMatch(text);
          if (match != null && match.group(1) != null) {
            String value = match.group(1)!.trim();
            value = _cleanExtractedText(value);
            
            if (value.isNotEmpty) {
              parsedData[field] = value;
              debugPrint('✅ Genius Scan extracted $field: $value');
              break;
            }
          }
        }
      });

      parsedData['extractionMethod'] = 'genius_scan_professional_ocr';
      parsedData['documentType'] = 'vehicle_registration';
      parsedData['extractionTimestamp'] = DateTime.now().toIso8601String();
      
    } catch (e) {
      debugPrint('❌ Registration parsing error: $e');
    }

    return parsedData;
  }

  /// Parse generic document
  static Map<String, dynamic> _parseGenericDocument(String text, String documentType) {
    return {
      'documentType': documentType,
      'extractedText': text,
      'extractionMethod': 'genius_scan_professional_ocr',
      'extractionTimestamp': DateTime.now().toIso8601String(),
      'textLength': text.length,
      'ocrEngine': 'genius_scan',
      'processingQuality': 'professional',
    };
  }

  /// Clean extracted text
  static String _cleanExtractedText(String text) {
    // Remove extra whitespace and clean up common OCR artifacts
    text = text.trim();
    text = text.replaceAll(RegExp(r'\s+'), ' '); // Multiple spaces to single
    text = text.replaceAll(RegExp(r'[^\w\s\-\/\.]'), ''); // Remove special chars except common ones
    
    // Remove common OCR artifacts
    text = text.replaceAll(RegExp(r'^[^\w]+'), ''); // Leading non-word chars
    text = text.replaceAll(RegExp(r'[^\w]+$'), ''); // Trailing non-word chars
    
    return text;
  }

  /// Calculate OCR confidence based on extracted data quality
  static double _calculateOCRConfidence(String extractedText, Map<String, dynamic> parsedData) {
    if (extractedText.isEmpty) return 0.0;
    
    double confidence = 0.6; // Base confidence for Genius Scan
    
    // Bonus for successful field extraction
    if (parsedData.containsKey('licenseNumber') || parsedData.containsKey('registrationNumber')) {
      confidence += 0.2;
    }
    
    if (parsedData.containsKey('fullName') || parsedData.containsKey('ownerName')) {
      confidence += 0.15;
    }
    
    if (parsedData.containsKey('dateOfBirth') || parsedData.containsKey('year')) {
      confidence += 0.1;
    }
    
    // Bonus for text length (more text usually means better OCR)
    if (extractedText.length > 200) {
      confidence += 0.1;
    }
    
    // Bonus for multiple successful extractions
    final extractedFields = parsedData.keys.where((key) => 
      !['extractionMethod', 'documentType', 'extractionTimestamp', 'ocrEngine', 'processingQuality'].contains(key)
    ).length;
    
    if (extractedFields >= 3) {
      confidence += 0.1;
    }
    
    return confidence.clamp(0.0, 0.98);
  }

  /// Get version information
  static Future<String> getVersionInfo() async {
    return 'Flutter Genius Scan v4.0.0 - Professional OCR';
  }

  /// Dispose resources
  static Future<void> dispose() async {
    try {
      _isInitialized = false;
      debugPrint('🧹 Genius Scan Service disposed');
    } catch (e) {
      debugPrint('⚠️ Error disposing Genius Scan: $e');
    }
  }
}

/// Result class for document scanning with professional OCR
class DocumentScanResult {
  final bool success;
  final File? imageFile;
  final String? extractedText;
  final Map<String, dynamic>? extractedData;
  final double confidence;
  final String? scanMethod;
  final String? errorMessage;

  DocumentScanResult({
    required this.success,
    this.imageFile,
    this.extractedText,
    this.extractedData,
    this.confidence = 0.0,
    this.scanMethod,
    this.errorMessage,
  });

  @override
  String toString() {
    return 'DocumentScanResult(success: $success, confidence: ${(confidence * 100).toStringAsFixed(1)}%, fields: ${extractedData?.keys.length ?? 0}, method: $scanMethod)';
  }
}
