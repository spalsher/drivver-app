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

      debugPrint('📋 Advanced name assignment for ${allNames.length} names: $allNames');

      if (allNames.length >= 2) {
        final assignmentResult = _assignNamesWithAdvancedLogic(allNames, text);
        driverName = assignmentResult['driver'];
        fatherName = assignmentResult['father'];
        
        // Validate the assignment
        final validation = _validateNameAssignment(driverName, fatherName, text);
        if (!validation['isValid']) {
          debugPrint('⚠️ Assignment validation failed: ${validation['reason']}');
          // Apply correction
          final corrected = _correctNameAssignment(driverName, fatherName, allNames, text);
          driverName = corrected['driver'];
          fatherName = corrected['father'];
          debugPrint('🔧 Applied name correction');
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

  /// Advanced name assignment with multiple strategies
  Map<String, String?> _assignNamesWithAdvancedLogic(List<String> names, String text) {
    debugPrint('🧠 Starting advanced name assignment logic...');
    
    // Strategy 1: Label proximity analysis
    final labelResult = _assignByLabelProximity(names, text);
    if ((labelResult['confidence'] as double) > 0.8) {
      debugPrint('✅ High confidence from label proximity');
      return {
        'driver': labelResult['driver'] as String?,
        'father': labelResult['father'] as String?,
      };
    }
    
    // Strategy 2: Structural position analysis
    final structureResult = _assignByStructuralPosition(names, text);
    if ((structureResult['confidence'] as double) > 0.7) {
      debugPrint('✅ High confidence from structural position');
      return {
        'driver': structureResult['driver'] as String?,
        'father': structureResult['father'] as String?,
      };
    }
    
    // Strategy 3: Name pattern analysis
    final patternResult = _assignByNamePatterns(names, text);
    if ((patternResult['confidence'] as double) > 0.6) {
      debugPrint('✅ Moderate confidence from name patterns');
      return {
        'driver': patternResult['driver'] as String?,
        'father': patternResult['father'] as String?,
      };
    }
    
    // Fallback: Use the highest confidence result
    final results = [labelResult, structureResult, patternResult];
    results.sort((a, b) => (b['confidence'] as double).compareTo(a['confidence'] as double));
    
    final bestResult = results.first;
    debugPrint('🔄 Using fallback assignment with confidence: ${bestResult['confidence']}');
    return {
      'driver': bestResult['driver'] as String?,
      'father': bestResult['father'] as String?,
    };
  }

  /// Strategy 1: Assign names based on label proximity
  Map<String, dynamic> _assignByLabelProximity(List<String> names, String text) {
    debugPrint('🏷️ Analyzing label proximity...');
    
    final lines = text.split('\n');
    String? driverName;
    String? fatherName;
    double confidence = 0.0;
    
    // Look for "Name:" and "Father/Husband:" labels
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].toLowerCase();
      
      if (line.contains('name:') && !line.contains('father') && !line.contains('husband')) {
        // Look for driver name in next few lines
        for (int j = i + 1; j < i + 4 && j < lines.length; j++) {
          final candidateLine = lines[j].trim();
          if (names.contains(candidateLine)) {
            driverName = candidateLine;
            confidence += 0.4;
            debugPrint('  📍 Driver name by "Name:" label: $driverName');
            break;
          }
        }
      }
      
      if (line.contains('father') || line.contains('husband')) {
        // Look for father name in next few lines
        for (int j = i + 1; j < i + 4 && j < lines.length; j++) {
          final candidateLine = lines[j].trim();
          if (names.contains(candidateLine) && candidateLine != driverName) {
            fatherName = candidateLine;
            confidence += 0.4;
            debugPrint('  👨 Father name by "Father/Husband:" label: $fatherName');
            break;
          }
        }
      }
    }
    
    // If we found both names with good confidence
    if (driverName != null && fatherName != null) {
      confidence += 0.2; // bonus for finding both
    }
    
    return {
      'driver': driverName,
      'father': fatherName,
      'confidence': confidence,
    };
  }

  /// Strategy 2: Assign names based on structural position in ID layout
  Map<String, dynamic> _assignByStructuralPosition(List<String> names, String text) {
    debugPrint('🏗️ Analyzing structural position...');
    
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    String? driverName;
    String? fatherName;
    double confidence = 0.0;
    
    // Find positions of names in the line structure
    final namePositions = <String, int>{};
    for (final name in names) {
      for (int i = 0; i < lines.length; i++) {
        if (lines[i] == name) {
          namePositions[name] = i;
          break;
        }
      }
    }
    
    if (namePositions.length >= 2) {
      final sortedNames = names.toList()
        ..sort((a, b) => (namePositions[a] ?? 999).compareTo(namePositions[b] ?? 999));
      
      // In Pakistani licenses, driver name typically appears before father name
      driverName = sortedNames[0];
      fatherName = sortedNames[1];
      confidence = 0.6;
      
      debugPrint('  📊 Position-based assignment: Driver=$driverName (line ${namePositions[driverName]}), Father=$fatherName (line ${namePositions[fatherName]})');
    }
    
    return {
      'driver': driverName,
      'father': fatherName,
      'confidence': confidence,
    };
  }

  /// Strategy 3: Assign names based on name patterns and characteristics
  Map<String, dynamic> _assignByNamePatterns(List<String> names, String text) {
    debugPrint('🔤 Analyzing name patterns...');
    
    String? driverName;
    String? fatherName;
    double confidence = 0.0;
    
    if (names.length >= 2) {
      // Analyze name characteristics
      final nameAnalysis = <String, Map<String, dynamic>>{};
      
      for (final name in names) {
        final words = name.split(' ');
        final hasMiddleName = words.length >= 3;
        final totalLength = name.length;
        final hasCommonFatherPrefixes = name.toUpperCase().contains(RegExp(r'\b(MUHAMMAD|MOHAMMAD|AHMED|ALI|SHAH)\b'));
        
        nameAnalysis[name] = {
          'wordCount': words.length,
          'hasMiddleName': hasMiddleName,
          'length': totalLength,
          'hasCommonFatherPrefixes': hasCommonFatherPrefixes,
          'score': 0.0,
        };
        
        debugPrint('  📝 $name: ${words.length} words, length: $totalLength, middle: $hasMiddleName');
      }
      
      // Score names for being driver vs father
      for (final entry in nameAnalysis.entries) {
        final name = entry.key;
        final analysis = entry.value;
        double driverScore = 0.0;
        
        // Driver names are often longer and have middle names
        if (analysis['hasMiddleName']) driverScore += 0.3;
        if (analysis['length'] > 15) driverScore += 0.2;
        if (analysis['wordCount'] >= 3) driverScore += 0.2;
        
        // Father names often have common prefixes
        if (analysis['hasCommonFatherPrefixes']) driverScore -= 0.2;
        
        analysis['driverScore'] = driverScore;
        debugPrint('  🎯 $name driver score: $driverScore');
      }
      
      // Assign based on scores
      final sortedByDriverScore = nameAnalysis.entries.toList()
        ..sort((a, b) => (b.value['driverScore'] as double).compareTo(a.value['driverScore'] as double));
      
      driverName = sortedByDriverScore[0].key;
      fatherName = sortedByDriverScore[1].key;
      confidence = 0.5;
      
      debugPrint('  🏆 Pattern-based assignment: Driver=$driverName, Father=$fatherName');
    }
    
    return {
      'driver': driverName,
      'father': fatherName,
      'confidence': confidence,
    };
  }

  /// Validate name assignment for logical consistency
  Map<String, dynamic> _validateNameAssignment(String? driverName, String? fatherName, String text) {
    final issues = <String>[];
    
    // Check if names are swapped (common issue)
    if (driverName != null && fatherName != null) {
      final driverWords = driverName.split(' ').length;
      final fatherWords = fatherName.split(' ').length;
      
      // Driver names are typically longer than father names
      if (fatherWords > driverWords && driverWords >= 3) {
        issues.add('Father name is longer than driver name');
      }
      
      // Check for common father name patterns in driver field
      if (driverName.toUpperCase().startsWith(RegExp(r'\b(MUHAMMAD|MOHAMMAD)\b')) && 
          !fatherName.toUpperCase().startsWith(RegExp(r'\b(MUHAMMAD|MOHAMMAD)\b'))) {
        issues.add('Driver name has father-like prefix');
      }
    }
    
    final isValid = issues.isEmpty;
    final reason = issues.join(', ');
    
    debugPrint('🔍 Name validation: ${isValid ? "PASSED" : "FAILED"} ${reason.isNotEmpty ? "($reason)" : ""}');
    
    return {
      'isValid': isValid,
      'reason': reason,
      'issues': issues,
    };
  }

  /// Correct name assignment based on validation issues
  Map<String, String?> _correctNameAssignment(String? driverName, String? fatherName, List<String> allNames, String text) {
    debugPrint('🔧 Applying name correction logic...');
    
    if (driverName != null && fatherName != null) {
      final driverWords = driverName.split(' ').length;
      final fatherWords = fatherName.split(' ').length;
      
      // If father name is significantly longer, swap them
      if (fatherWords > driverWords && driverWords >= 2) {
        debugPrint('  🔄 Swapping names due to length mismatch');
        return {
          'driver': fatherName,
          'father': driverName,
        };
      }
      
      // If driver name has common father prefixes, consider swapping
      if (driverName.toUpperCase().startsWith(RegExp(r'\b(MUHAMMAD|MOHAMMAD)\b')) && 
          driverWords == 2 && fatherWords >= 3) {
        debugPrint('  🔄 Swapping names due to father prefix pattern');
        return {
          'driver': fatherName,
          'father': driverName,
        };
      }
    }
    
    // No correction needed
    return {
      'driver': driverName,
      'father': fatherName,
    };
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

    // Check names (25 points) - Enhanced validation
    if (data['fullName'] != 'Not detected' && data['fullName'].toString().length > 5) {
      score += 15;
      // Bonus for multi-word names (more likely to be correct)
      if (data['fullName'].toString().split(' ').length >= 2) score += 5;
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
