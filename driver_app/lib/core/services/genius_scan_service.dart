import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_genius_scan/flutter_genius_scan.dart';

/// Professional Document Scanning Service using Genius Scan SDK
class GeniusScanDocumentService {
  
  /// Initialize Genius Scan with license key
  static Future<bool> initialize({String? licenseKey}) async {
    try {
      // Initialize Genius Scan SDK
      if (licenseKey != null) {
        FlutterGeniusScan.setLicenseKey(licenseKey);
      }
      
      debugPrint('✅ Genius Scan SDK initialized successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to initialize Genius Scan: $e');
      return false;
    }
  }
  
  /// Scan document with professional quality
  static Future<GeniusScanResult?> scanDocument({
    required DocumentType documentType,
    Map<String, dynamic>? customConfig,
  }) async {
    try {
      debugPrint('🔍 Starting Genius Scan for: ${documentType.name}');
      
      // Configure scan settings for optimal results
      final config = customConfig ?? _getOptimalConfigForDocument(documentType);
      
      // Start scanning
      final result = await FlutterGeniusScan.scanWithConfiguration(config);
      
      if (result != null && result['scans'] != null) {
        final scans = result['scans'] as List;
        debugPrint('✅ Genius Scan completed successfully');
        debugPrint('📄 Scanned pages: ${scans.length}');
        
        // Get scanned images
        final scannedImages = <File>[];
        for (final scan in scans) {
          final scanMap = scan as Map<String, dynamic>;
          final enhancedUrl = scanMap['enhancedUrl'] as String?;
          final originalUrl = scanMap['originalUrl'] as String?;
          final imageUrl = enhancedUrl ?? originalUrl;
          
          if (imageUrl != null) {
            scannedImages.add(File(imageUrl));
          }
        }
        
        // Get OCR text if available
        String ocrText = '';
        if (result['ocrResult'] != null) {
          final ocrResult = result['ocrResult'] as Map<String, dynamic>;
          ocrText = ocrResult['fullText'] as String? ?? '';
        }
        
        return GeniusScanResult(
          success: true,
          scannedImages: scannedImages,
          ocrText: ocrText,
          confidence: _calculateConfidence(result.cast<String, dynamic>()),
          documentType: documentType,
          originalResult: result.cast<String, dynamic>(),
        );
      } else {
        debugPrint('❌ Genius Scan cancelled by user or failed');
        return null;
      }
      
    } catch (e) {
      debugPrint('❌ Genius Scan error: $e');
      return GeniusScanResult(
        success: false,
        scannedImages: [],
        ocrText: '',
        confidence: 0.0,
        documentType: documentType,
        errorMessage: e.toString(),
      );
    }
  }
  
  /// Get optimal configuration for different document types
  static Map<String, dynamic> _getOptimalConfigForDocument(DocumentType documentType) {
    switch (documentType) {
      case DocumentType.drivingLicenseFront:
      case DocumentType.drivingLicenseBack:
        return {
          'source': 'camera',
          'multiPage': false,
          'defaultFilter': 'photo', // Best for ID cards
          'jpegQuality': 95,
          'outputImageMaxWidth': 2000,
          'outputImageMaxHeight': 2000,
          'ocrConfiguration': {
            'languages': ['en'], // English for Pakistani licenses
            'outputFormats': ['fullText', 'textLayout'],
          },
          'cameraConfiguration': {
            'flashButtonHidden': false,
            'captureButtonHidden': false,
            'galleryButtonHidden': true,
            'closeButtonHidden': false,
          },
          'editConfiguration': {
            'cropEnabled': true,
            'rotationEnabled': true,
            'enhancementEnabled': true,
            'multiPageEnabled': false,
          },
        };
        
      case DocumentType.vehicleRegistration:
      case DocumentType.insuranceCertificate:
        return {
          'source': 'camera',
          'multiPage': false,
          'defaultFilter': 'blackAndWhite', // Best for text documents
          'jpegQuality': 95,
          'outputImageMaxWidth': 2000,
          'outputImageMaxHeight': 2000,
          'ocrConfiguration': {
            'languages': ['en'],
            'outputFormats': ['fullText', 'textLayout'],
          },
          'cameraConfiguration': {
            'flashButtonHidden': false,
            'captureButtonHidden': false,
            'galleryButtonHidden': true,
            'closeButtonHidden': false,
          },
          'editConfiguration': {
            'cropEnabled': true,
            'rotationEnabled': true,
            'enhancementEnabled': true,
            'multiPageEnabled': false,
          },
        };
        
      case DocumentType.driverPhoto:
        return {
          'source': 'camera',
          'multiPage': false,
          'defaultFilter': 'photo',
          'jpegQuality': 95,
          'outputImageMaxWidth': 1500,
          'outputImageMaxHeight': 1500,
          // No OCR needed for photos
          'cameraConfiguration': {
            'flashButtonHidden': false,
            'captureButtonHidden': false,
            'galleryButtonHidden': true,
            'closeButtonHidden': false,
          },
          'editConfiguration': {
            'cropEnabled': true,
            'rotationEnabled': true,
            'enhancementEnabled': false,
            'multiPageEnabled': false,
          },
        };
        
      case DocumentType.vehiclePhoto:
        return {
          'source': 'camera',
          'multiPage': false,
          'defaultFilter': 'photo',
          'jpegQuality': 90,
          'outputImageMaxWidth': 2000,
          'outputImageMaxHeight': 2000,
          // No OCR needed for photos
          'cameraConfiguration': {
            'flashButtonHidden': false,
            'captureButtonHidden': false,
            'galleryButtonHidden': true,
            'closeButtonHidden': false,
          },
          'editConfiguration': {
            'cropEnabled': true,
            'rotationEnabled': true,
            'enhancementEnabled': true,
            'multiPageEnabled': false,
          },
        };
    }
  }
  
  /// Calculate confidence score from Genius Scan result
  static double _calculateConfidence(Map<String, dynamic> result) {
    // Genius Scan provides high-quality results by default
    double confidence = 0.95; // Base confidence for professional scanning
    
    // Adjust based on OCR results if available
    if (result['ocrResult'] != null) {
      final ocrResult = result['ocrResult'] as Map<String, dynamic>;
      final ocrText = ocrResult['fullText'] as String? ?? '';
      
      if (ocrText.isNotEmpty) {
        confidence = 0.98; // Higher confidence with OCR
        
        // Check text quality indicators
        if (ocrText.length > 50) confidence += 0.01;
        if (ocrText.contains(RegExp(r'\d{5}-\d{6,8}-\d'))) confidence += 0.01; // License pattern
        if (ocrText.toUpperCase().contains('DRIVING')) confidence += 0.005;
      }
    }
    
    // Check scan quality
    if (result['scans'] != null) {
      final scans = result['scans'] as List;
      if (scans.isNotEmpty) {
        final scan = scans.first as Map<String, dynamic>;
        if (scan['enhancedUrl'] != null) confidence += 0.01; // Enhanced image available
      }
    }
    
    return confidence.clamp(0.0, 1.0);
  }
  
  /// Extract structured data from OCR text using Pakistani patterns
  static Map<String, String> extractDataFromOCR(String ocrText, DocumentType documentType) {
    final data = <String, String>{};
    
    if (ocrText.isEmpty) return data;
    
    debugPrint('🔍 Extracting data from Genius Scan OCR (${ocrText.length} chars)');
    
    switch (documentType) {
      case DocumentType.drivingLicenseFront:
        data.addAll(_extractDriverLicenseData(ocrText));
        break;
      case DocumentType.vehicleRegistration:
        data.addAll(_extractVehicleRegistrationData(ocrText));
        break;
      case DocumentType.insuranceCertificate:
        data.addAll(_extractInsuranceData(ocrText));
        break;
      default:
        break;
    }
    
    debugPrint('📋 Genius Scan extracted ${data.length} fields: ${data.keys.join(", ")}');
    return data;
  }
  
  /// Extract driver license data with improved Pakistani patterns
  static Map<String, String> _extractDriverLicenseData(String text) {
    final data = <String, String>{};
    final upperText = text.toUpperCase();
    
    // License Number - Pakistani format
    final licensePatterns = [
      RegExp(r'(\d{5}[-]\d{6,8}[-]\d[#]?\d*)'),
      RegExp(r'LICENSE\s*NO[.\s]*(\d{5}[-]\d{6,8}[-]\d[#]?\d*)'),
    ];
    
    for (final pattern in licensePatterns) {
      final match = pattern.firstMatch(upperText);
      if (match != null) {
        data['licenseNumber'] = match.group(1)!.trim();
        break;
      }
    }
    
    // Names - Multiple strategies for better accuracy
    final namePatterns = [
      RegExp(r'NAME[:\s]+([A-Z][A-Z\s]{8,35})'),
      RegExp(r'FATHER[/\s]*HUSBAND[:\s]+([A-Z][A-Z\s]{8,35})'),
    ];
    
    for (final pattern in namePatterns) {
      final matches = pattern.allMatches(upperText);
      for (final match in matches) {
        final name = match.group(1)!.trim();
        if (name.isNotEmpty && name.length > 5) {
          if (!data.containsKey('fullName')) {
            data['fullName'] = name;
          } else if (!data.containsKey('fatherName')) {
            data['fatherName'] = name;
          }
        }
      }
    }
    
    // Dates - Pakistani format
    final datePattern = RegExp(r'(\d{1,2}[-/]\w{3}[-/]\d{4})');
    final dates = datePattern.allMatches(upperText).map((m) => m.group(1)!).toList();
    
    if (dates.isNotEmpty) {
      data['dateOfBirth'] = dates.first;
      if (dates.length > 1) {
        data['expiryDate'] = dates.last;
      }
    }
    
    // Category
    final categoryPattern = RegExp(r'(M\s*CYCLE[,\s]*M\s*CAR|MCYCLE[,\s]*MCAR|LTV|HTV|PSV)');
    final categoryMatch = categoryPattern.firstMatch(upperText);
    if (categoryMatch != null) {
      data['category'] = categoryMatch.group(1)!.trim();
    }
    
    return data;
  }
  
  /// Extract vehicle registration data
  static Map<String, String> _extractVehicleRegistrationData(String text) {
    final data = <String, String>{};
    // TODO: Implement vehicle registration extraction
    return data;
  }
  
  /// Extract insurance data
  static Map<String, String> _extractInsuranceData(String text) {
    final data = <String, String>{};
    // TODO: Implement insurance data extraction
    return data;
  }
}

/// Genius Scan result wrapper
class GeniusScanResult {
  final bool success;
  final List<File> scannedImages;
  final String ocrText;
  final double confidence;
  final DocumentType documentType;
  final String? errorMessage;
  final Map<String, dynamic>? originalResult;
  
  const GeniusScanResult({
    required this.success,
    required this.scannedImages,
    required this.ocrText,
    required this.confidence,
    required this.documentType,
    this.errorMessage,
    this.originalResult,
  });
}

/// Document types enum
enum DocumentType {
  drivingLicenseFront,
  drivingLicenseBack,
  vehicleRegistration,
  insuranceCertificate,
  driverPhoto,
  vehiclePhoto,
}
