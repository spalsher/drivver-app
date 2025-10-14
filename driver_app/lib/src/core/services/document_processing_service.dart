import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' show join;
import 'package:flutter_image_compress/flutter_image_compress.dart';

class DocumentProcessingService {
  /// Processes the captured image: enhances it, runs OCR, and parses the text.
  Future<ProcessingResult> processImage(File imageFile) async {
    try {
      // 1. Enhance the image for better OCR results
      final enhancedImageFile = await _enhanceImage(imageFile);

      // 2. Perform OCR on the enhanced image
      final ocrText = await _extractTextWithMLKit(enhancedImageFile);

      // 3. Parse the OCR text to extract structured data
      final extractedData = _parseDriverLicenseData(ocrText);

      return ProcessingResult(
        imageFile: enhancedImageFile,
        extractedData: extractedData,
      );
    } catch (e) {
      debugPrint('Error processing document: $e');
      rethrow;
    }
  }

  /// Process scan result with OCR text and blocks already available
  Future<ProcessingResult> processScanResult(File imageFile, String ocrText, List<Map<String, dynamic>> blocks) async {
    try {
      // 1. Enhance the image for better OCR results
      final enhancedImageFile = await _enhanceImage(imageFile);

      // 2. Parse the OCR text to extract structured data
      final extractedData = _parseDriverLicenseData(ocrText);

      // 3. Validate extraction quality
      final validationResult = _validateExtractionQuality(extractedData, ocrText);

      return ProcessingResult(
        imageFile: enhancedImageFile,
        extractedData: extractedData,
        validationResult: validationResult,
      );
    } catch (e) {
      debugPrint('Error processing scan result: $e');
      rethrow;
    }
  }

  /// Enhances the image by adjusting contrast and brightness.
  Future<File> _enhanceImage(File imageFile) async {
    debugPrint('Enhancing image for OCR...');
    final imageBytes = await imageFile.readAsBytes();
    final image = img.decodeImage(imageBytes);

    if (image == null) {
      throw Exception('Could not decode image for enhancement.');
    }

    // Apply image filters
    img.adjustColor(image, contrast: 1.5, brightness: 1.1);
    
    // Get a temporary directory to save the enhanced image
    final directory = await getTemporaryDirectory();
    final path = join(directory.path, '${DateTime.now().millisecondsSinceEpoch}-enhanced.jpg');

    // Save the enhanced image
    final enhancedImageFile = File(path)..writeAsBytesSync(img.encodeJpg(image, quality: 90));
    
    debugPrint('Image enhancement complete. Saved to: ${enhancedImageFile.path}');
    return enhancedImageFile;
  }
  
  /// Extract text using Google ML Kit OCR
  Future<String> _extractTextWithMLKit(File imageFile) async {
    try {
      debugPrint('📋 Starting ML Kit OCR extraction from: ${imageFile.path}');

      if (!await imageFile.exists()) {
        throw Exception('Image file does not exist for OCR: ${imageFile.path}');
      }

      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final inputImage = InputImage.fromFilePath(imageFile.path);

      final recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      final extractedText = recognizedText.text;
      debugPrint('✅ ML Kit OCR extracted ${extractedText.length} characters');
      return extractedText;
    } catch (e) {
      debugPrint('❌ OCR error: $e');
      rethrow;
    }
  }

  /// Parse driver license data from OCR text - Optimized for Pakistani licenses
  Map<String, dynamic> _parseDriverLicenseData(String text) {
    final Map<String, dynamic> data = {
      'documentType': 'driving_license',
      'extractionMethod': 'custom_scanner_mlkit_ocr',
    };

    try {
      debugPrint('🏛️ Two-column table parsing (${text.length} chars)');
      debugPrint('📄 RAW TEXT:\n$text');
      debugPrint('=' * 80);
      
      // Split into lines
      final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
      
      // STRATEGY: OCR reads column-by-column (labels first, then values)
      // The values appear IMMEDIATELY after the last label
      
      // Find where the actual data starts (first line with numbers/names after labels)
      int valuesStartIndex = -1;
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];
        // Look for lines that contain actual data (dates, license numbers, names)
        if (line.contains(RegExp(r'\d{1,2}[-\s]?[A-Za-z]{3}[-\s]?\d{4}')) || // Date pattern
            line.contains(RegExp(r'\d{5}-\d{7,8}-\d+')) || // License pattern
            (line.contains(RegExp(r'^[A-Z]{3,}(?:\s+[A-Z]{3,})+$')) && // Multi-word name
             !line.contains(RegExp(r'POLICE|DRIVING|LICENSE|SINDH|AUTHORITY')))) {
          valuesStartIndex = i;
          break;
        }
      }
      
      debugPrint('📍 Values start at line $valuesStartIndex');
      
      // Extract the values section (from first data line until we hit footer text)
      List<String> valuesLines = [];
      if (valuesStartIndex >= 0) {
        for (int i = valuesStartIndex; i < lines.length; i++) {
          final line = lines[i];
          // Stop at footer text (licensing authority, etc.)
          if (line.contains(RegExp(r'Licensing|Authority|DSP|DL\s+C', caseSensitive: false))) {
            break; 
          }
          valuesLines.add(line);
        }
      }
      debugPrint('📋 Value lines: $valuesLines');

      // STEP 1: Extract license number (pattern-based, position-independent)
      final licenseRegex = RegExp(r'(\d{5}-\d{7,8}-\d+)(?:#\d+)?', caseSensitive: false);
      for (final line in valuesLines) {
        final match = licenseRegex.firstMatch(line);
        if (match != null) {
          data['licenseNumber'] = match.group(1)!.trim();
          debugPrint('✅ License: ${data['licenseNumber']}');
          break;
        }
      }
      if (!data.containsKey('licenseNumber')) {
        data['licenseNumber'] = 'Not detected';
      }
      
      // STEP 2: Extract names from value lines (most reliable for Pakistani licenses)
      final allNames = <String>[];

      // Find names in the value lines - they appear after labels in order
      final namePattern = RegExp(r'\b[A-Z]{2,}(?:\s+[A-Z]{2,})*\b');

      // Look for names in the structured value lines
      for (final line in lines) {
        final trimmedLine = line.trim();
        if (trimmedLine.length >= 6 &&
            !trimmedLine.contains(RegExp(r'\d{4}')) && // Skip dates
            !trimmedLine.toUpperCase().contains('DRIVING') &&
            !trimmedLine.toUpperCase().contains('LICENSE') &&
            !trimmedLine.toUpperCase().contains('SINDH') &&
            trimmedLine.split(RegExp(r'\s+')).length >= 2) {

          // Check if line looks like a name (all uppercase letters with spaces)
          if (RegExp(r'^[A-Z\s]+$').hasMatch(trimmedLine)) {
            allNames.add(trimmedLine);
            debugPrint('  ✅ Found name in values: $trimmedLine');
          }
        }
      }

      debugPrint('📋 Total names found: ${allNames.length}');
      for (var name in allNames) {
        debugPrint('  ✅ Name: $name');
      }

      // POSITION-BASED ASSIGNMENT (Most reliable for Pakistani licenses)
      String? driverName;
      String? fatherName;

      debugPrint('📋 Position-based assignment for ${allNames.length} names: $allNames');

      if (allNames.length >= 2) {
        // Method 1: Use label proximity to determine which is father
        final fatherLabelPattern = RegExp(r'father|husband|father/husband', caseSensitive: false);

        // Find which name appears after "Father/Husband:" label
        for (int i = 0; i < allNames.length; i++) {
          final name = allNames[i];
          final nameIndex = text.indexOf(name);
          if (nameIndex != -1) {
            final beforeText = text.substring(0, nameIndex).toLowerCase();
            final contextWindow = beforeText.length > 150 ? beforeText.substring(beforeText.length - 150) : beforeText;

            if (fatherLabelPattern.hasMatch(contextWindow)) {
              fatherName = name;
              driverName = allNames.firstWhere((n) => n != fatherName);
              debugPrint('✅ Father (by label proximity): $fatherName');
              debugPrint('✅ Driver (by position): $driverName');
              break;
            }
          }
        }

        // Method 2: If no clear father label, assume first name is driver, second is father
        if (driverName == null) {
          driverName = allNames[0];
          fatherName = allNames.length > 1 ? allNames[1] : null;
          debugPrint('✅ Driver (first position): $driverName');
          debugPrint('✅ Father (second position): $fatherName');
        }
      } else if (allNames.length == 1) {
        driverName = allNames[0];
        debugPrint('✅ Driver (only name found): $driverName');
      }

      data['fullName'] = driverName ?? 'Not detected';
      data['fatherName'] = fatherName ?? 'Not detected';

      debugPrint('📋 Final assignment: Driver=${data['fullName']}, Father=${data['fatherName']}');

      // STEP 3: Extract all dates
      final datePattern = RegExp(r'(\d{1,2}[-.\s]?(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec|Bec|Dee|Deo)[-.\s]?\d{2,4})', caseSensitive: false);
      final allDates = <String>[];

      // Use the entire text for date extraction to be safer
      final dateMatches = datePattern.allMatches(text);
      for (final match in dateMatches) {
        allDates.add(_normalizeDate(match.group(1)!));
      }

      debugPrint('📅 Found ${allDates.length} dates: $allDates');

      // Smart date assignment by context and position
      final sortedDates = allDates.map((d) => _parseDate(d)).where((d) => d != null).toList();
      sortedDates.sort((a, b) => a!.compareTo(b!));

      if (sortedDates.length >= 2) {
        // DOB is always the earliest date
        data['dateOfBirth'] = _formatDate(sortedDates.first!);

        // Expiry is always the latest date
        data['expiryDate'] = _formatDate(sortedDates.last!);

        // Issue date is the remaining one if 3 dates are found
        if (sortedDates.length >= 3) {
           data['issueDate'] = _formatDate(sortedDates[1]!);
        } else {
           data['issueDate'] = 'Not detected';
        }
      } else {
        data['issueDate'] = 'Not detected';
        data['dateOfBirth'] = 'Not detected';
        data['expiryDate'] = 'Not detected';
      }

      // STEP 4: Extract category
      final categoryPattern = RegExp(r'M\s*CYCLE[,\s]+M\s*CAR|MCYCLE|M\s*CAR', caseSensitive: false);
      final categoryMatch = categoryPattern.firstMatch(text);
      if (categoryMatch != null) {
        data['category'] = categoryMatch.group(0)!.replaceAll(RegExp(r'\s+'), ' ').trim();
      } else {
        data['category'] = 'Not detected';
      }

      // STEP 5: Extract address
      if (text.contains(RegExp(r'Karachi', caseSensitive: false))) {
        data['address'] = 'Karachi';
      } else {
        data['address'] = 'Not detected';
      }

      data['rawText'] = text;

      // STEP 6: Validate extraction quality and return confidence
      final validationResult = _validateExtractionQuality(data, text);

      debugPrint('=' * 80);
      debugPrint('🎯 Table parsing complete: ${data.keys.length} fields');
      debugPrint('📊 Final data: $data');
      debugPrint('🔍 Validation: ${validationResult.confidence}% confidence');

    } catch (e) {
      debugPrint('❌ Table parsing error: $e');
    }

    return data;
  }

  /// Normalize date format to DD-MMM-YYYY
  String _normalizeDate(String date) {
    // Fix common OCR errors
    String normalized = date.replaceAll(RegExp(r'[\s.]+'), '-');
    normalized = normalized.replaceAll(RegExp(r'Bec|Dee|Deo', caseSensitive: false), 'Dec');
    normalized = normalized.replaceAll(RegExp(r'Auq', caseSensitive: false), 'Aug');
    
    // Fix year errors like 201B -> 2018
    if (RegExp(r'\d{3}[BODS]$').hasMatch(normalized)) {
      var lastChar = normalized[normalized.length-1];
      if (lastChar == 'B') normalized = normalized.substring(0, normalized.length-1) + '8';
      if (lastChar == 'O' || lastChar == 'D') normalized = normalized.substring(0, normalized.length-1) + '0';
      if (lastChar == 'S') normalized = normalized.substring(0, normalized.length-1) + '5';
    }

    return normalized;
  }

  DateTime? _parseDate(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length != 3) return null;

      final day = int.parse(parts[0]);
      final monthStr = parts[1].toLowerCase();
      final year = int.parse(parts[2]);

      const monthMap = {
        'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
        'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12
      };

      final month = monthMap[monthStr.substring(0,3)];
      if (month == null) return null;

      return DateTime(year, month, day);
    } catch(e) {
      return null;
    }
  }

  String _formatDate(DateTime date) {
    const monthMap = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day}-${monthMap[date.month-1]}-${date.year}';
  }

  /// Validate extraction quality and return confidence score
  ValidationResult _validateExtractionQuality(Map<String, dynamic> data, String rawText) {
    int score = 0;
    int maxScore = 100;

    // Check license number (30 points)
    if (data['licenseNumber'] != 'Not detected' &&
        data['licenseNumber'].toString().contains('-') &&
        data['licenseNumber'].toString().length > 10) {
      score += 30;
    }

    // Check names (25 points)
    if (data['fullName'] != 'Not detected' && data['fullName'].toString().length > 5) {
      score += 15;
    }
    if (data['fatherName'] != 'Not detected' && data['fatherName'].toString().length > 5) {
      score += 10;
    }

    // Check dates (25 points)
    if (data['dateOfBirth'] != 'Not detected') score += 10;
    if (data['expiryDate'] != 'Not detected') score += 10;
    if (data['issueDate'] != 'Not detected') score += 5;

    // Check category (10 points)
    if (data['category'] != 'Not detected') score += 10;

    // Check if raw text has reasonable length (10 points)
    if (rawText.length > 50) score += 10;

    debugPrint('🔍 Extraction validation: $score/$maxScore points');

    return ValidationResult(confidence: score, needsRetry: score < 70);
  }
}

/// Validation result for extraction quality
class ValidationResult {
  final int confidence;
  final bool needsRetry;

  ValidationResult({required this.confidence, required this.needsRetry});
}

/// A simple class to hold the results of the document processing.
class ProcessingResult {
  final File imageFile;
  final Map<String, dynamic> extractedData;
  final ValidationResult? validationResult;

  ProcessingResult({
    required this.imageFile,
    required this.extractedData,
    this.validationResult,
  });
}
