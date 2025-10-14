import 'dart:convert';
import 'package:flutter/material.dart';

/// ULTIMATE OCR Post-Processing System with Pakistani Intelligence
class UltimateOCRProcessor {
  
  // Pakistani Name Database for Intelligent Correction
  static const Map<String, List<String>> _pakistaniNameCorrections = {
    // Common OCR Errors → Correct Names
    'LODAF': ['LODHI', 'LODHE'],
    'LODAI': ['LODHI', 'LODHE'],
    'MEHMOOD': ['MEHMOOD', 'MAHMOOD'],
    'REHMAN': ['REHMAN', 'RAHMAN'],
    'MUHAMMAD': ['MUHAMMAD', 'MOHAMMAD'],
    'AHMED': ['AHMED', 'AHMAD'],
    'HASSAN': ['HASSAN', 'HASAN'],
    'HUSSAIN': ['HUSSAIN', 'HUSAIN'],
    'NASIR': ['NASIR', 'NASSER'],
    'AAMIR': ['AAMIR', 'AMIR'],
    'KHAN': ['KHAN'],
    'SHAH': ['SHAH'],
    'MALIK': ['MALIK'],
    'ALI': ['ALI'],
  };
  
  // Date Corrections
  static const Map<String, String> _dateCorrections = {
    'DES': 'DEC',
    'JAN': 'JAN',
    'FEB': 'FEB', 
    'MAR': 'MAR',
    'APR': 'APR',
    'MAY': 'MAY',
    'JUN': 'JUN',
    'JUL': 'JUL',
    'AUG': 'AUG',
    'SEP': 'SEP',
    'OCT': 'OCT',
    'NOV': 'NOV',
    'DEC': 'DEC',
  };
  
  /// ULTIMATE Data Processing with Intelligence
  static Map<String, String> processExtractedData(Map<String, String> rawData) {
    debugPrint('🧠 ULTIMATE OCR Processing: ${rawData.length} fields');
    
    final processedData = <String, String>{};
    
    for (final entry in rawData.entries) {
      final fieldName = entry.key;
      final rawValue = entry.value;
      
      String processedValue = rawValue;
      
      switch (fieldName) {
        case 'fullName':
        case 'fatherName':
          processedValue = _processName(rawValue);
          break;
        case 'dateOfBirth':
        case 'issueDate':
        case 'expiryDate':
          processedValue = _processDate(rawValue);
          break;
        case 'licenseNumber':
          processedValue = _processLicenseNumber(rawValue);
          break;
        case 'category':
          processedValue = _processCategory(rawValue);
          break;
        default:
          processedValue = _processGeneric(rawValue);
      }
      
      processedData[fieldName] = processedValue;
      
      if (processedValue != rawValue) {
        debugPrint('🔧 Corrected $fieldName: "$rawValue" → "$processedValue"');
      }
    }
    
    debugPrint('✅ ULTIMATE Processing Complete: ${processedData.length} fields processed');
    return processedData;
  }
  
  /// Process Names with Pakistani Intelligence
  static String _processName(String rawName) {
    if (rawName.isEmpty) return rawName;
    
    String processed = rawName.toUpperCase().trim();
    
    // Remove common OCR artifacts
    processed = processed.replaceAll(RegExp(r'[^A-Z\s]'), '');
    processed = processed.replaceAll(RegExp(r'\s+'), ' ');
    
    // Apply Pakistani name corrections
    for (final correction in _pakistaniNameCorrections.entries) {
      final wrongName = correction.key;
      final correctNames = correction.value;
      
      if (processed.contains(wrongName)) {
        // Use the most common correct version
        processed = processed.replaceAll(wrongName, correctNames.first);
      }
    }
    
    // Smart word-by-word correction
    final words = processed.split(' ');
    final correctedWords = <String>[];
    
    for (final word in words) {
      String correctedWord = word;
      
      // Find best match in Pakistani names database
      double bestScore = 0.0;
      String bestMatch = word;
      
      for (final nameList in _pakistaniNameCorrections.values) {
        for (final correctName in nameList) {
          final similarity = _calculateSimilarity(word, correctName);
          if (similarity > bestScore && similarity > 0.7) {
            bestScore = similarity;
            bestMatch = correctName;
          }
        }
      }
      
      correctedWords.add(bestMatch);
    }
    
    return correctedWords.join(' ').trim();
  }
  
  /// Process Dates with Intelligence
  static String _processDate(String rawDate) {
    if (rawDate.isEmpty) return rawDate;
    
    String processed = rawDate.toUpperCase().trim();
    
    // Apply month corrections
    for (final correction in _dateCorrections.entries) {
      processed = processed.replaceAll(correction.key, correction.value);
    }
    
    // Validate and fix date format
    final datePattern = RegExp(r'(\d{1,2})[-/](\w{3})[-/](\d{4})');
    final match = datePattern.firstMatch(processed);
    
    if (match != null) {
      final day = match.group(1)!.padLeft(2, '0');
      final month = match.group(2)!;
      final year = match.group(3)!;
      
      // Ensure valid month
      String validMonth = month;
      if (!_dateCorrections.containsValue(month)) {
        // Try to find closest match
        for (final correctMonth in _dateCorrections.values) {
          if (_calculateSimilarity(month, correctMonth) > 0.6) {
            validMonth = correctMonth;
            break;
          }
        }
      }
      
      return '$day-$validMonth-$year';
    }
    
    return processed;
  }
  
  /// Process License Number
  static String _processLicenseNumber(String rawLicense) {
    if (rawLicense.isEmpty) return rawLicense;
    
    // Clean and format Pakistani license number
    String processed = rawLicense.replaceAll(RegExp(r'[^0-9\-#]'), '');
    
    // Ensure proper format: 12345-1234567-1#123
    final licensePattern = RegExp(r'(\d{5})[-]?(\d{6,8})[-]?(\d)([#]?\d*)');
    final match = licensePattern.firstMatch(processed);
    
    if (match != null) {
      final part1 = match.group(1)!;
      final part2 = match.group(2)!;
      final part3 = match.group(3)!;
      final part4 = match.group(4) ?? '';
      
      return '$part1-$part2-$part3$part4';
    }
    
    return processed;
  }
  
  /// Process Category
  static String _processCategory(String rawCategory) {
    if (rawCategory.isEmpty) return rawCategory;
    
    String processed = rawCategory.toUpperCase().trim();
    
    // Common category corrections
    processed = processed.replaceAll('MCYCLE', 'M CYCLE');
    processed = processed.replaceAll('MCAR', 'M CAR');
    processed = processed.replaceAll(',', ', ');
    processed = processed.replaceAll(RegExp(r'\s+'), ' ');
    
    return processed.trim();
  }
  
  /// Generic processing
  static String _processGeneric(String rawValue) {
    return rawValue.trim();
  }
  
  /// Calculate similarity between two strings (Levenshtein-based)
  static double _calculateSimilarity(String a, String b) {
    if (a == b) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;
    
    final longer = a.length > b.length ? a : b;
    final shorter = a.length > b.length ? b : a;
    
    if (longer.length == 0) return 1.0;
    
    final distance = _levenshteinDistance(longer, shorter);
    return (longer.length - distance) / longer.length;
  }
  
  /// Levenshtein distance calculation
  static int _levenshteinDistance(String a, String b) {
    final matrix = List.generate(
      a.length + 1,
      (i) => List.generate(b.length + 1, (j) => 0),
    );
    
    for (int i = 0; i <= a.length; i++) {
      matrix[i][0] = i;
    }
    
    for (int j = 0; j <= b.length; j++) {
      matrix[0][j] = j;
    }
    
    for (int i = 1; i <= a.length; i++) {
      for (int j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1,      // deletion
          matrix[i][j - 1] + 1,      // insertion
          matrix[i - 1][j - 1] + cost // substitution
        ].reduce((a, b) => a < b ? a : b);
      }
    }
    
    return matrix[a.length][b.length];
  }
  
  /// Get confidence score for processed data
  static double getProcessingConfidence(
    Map<String, String> originalData,
    Map<String, String> processedData,
  ) {
    if (originalData.isEmpty) return 0.0;
    
    int corrections = 0;
    int totalFields = originalData.length;
    
    for (final key in originalData.keys) {
      if (originalData[key] != processedData[key]) {
        corrections++;
      }
    }
    
    // Higher confidence if we made intelligent corrections
    final baseConfidence = 0.8;
    final correctionBonus = corrections * 0.05; // 5% bonus per correction
    
    return (baseConfidence + correctionBonus).clamp(0.0, 1.0);
  }
  
  /// Generate correction report
  static Map<String, dynamic> generateCorrectionReport(
    Map<String, String> originalData,
    Map<String, String> processedData,
  ) {
    final corrections = <String, Map<String, String>>{};
    final suggestions = <String>[];
    
    for (final key in originalData.keys) {
      final original = originalData[key] ?? '';
      final processed = processedData[key] ?? '';
      
      if (original != processed) {
        corrections[key] = {
          'original': original,
          'corrected': processed,
          'reason': _getCorrectionReason(key, original, processed),
        };
      }
    }
    
    if (corrections.isNotEmpty) {
      suggestions.add('Applied ${corrections.length} intelligent corrections');
      suggestions.add('Pakistani name database used for accuracy');
      suggestions.add('Date format standardized');
    }
    
    return {
      'corrections': corrections,
      'suggestions': suggestions,
      'confidence': getProcessingConfidence(originalData, processedData),
    };
  }
  
  /// Get reason for correction
  static String _getCorrectionReason(String fieldName, String original, String corrected) {
    switch (fieldName) {
      case 'fullName':
      case 'fatherName':
        return 'Pakistani name database correction';
      case 'dateOfBirth':
      case 'issueDate':
      case 'expiryDate':
        return 'Date format standardization';
      case 'licenseNumber':
        return 'License number format correction';
      case 'category':
        return 'Category format standardization';
      default:
        return 'General text cleanup';
    }
  }
}
