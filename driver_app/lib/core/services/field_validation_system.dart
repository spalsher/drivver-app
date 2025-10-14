import 'dart:math';
import 'package:flutter/material.dart';

/// Field-level confidence scoring and validation system
class FieldValidationSystem {
  
  /// Validate and score extracted field data
  static FieldValidationResult validateExtractedData(
    Map<String, String> extractedData,
    String documentType,
    String countryCode,
  ) {
    final results = <String, FieldScore>{};
    double totalConfidence = 0.0;
    int validFields = 0;
    
    for (final entry in extractedData.entries) {
      final fieldName = entry.key;
      final fieldValue = entry.value;
      
      final score = _validateField(fieldName, fieldValue, documentType, countryCode);
      results[fieldName] = score;
      
      if (score.isValid) {
        totalConfidence += score.confidence;
        validFields++;
      }
    }
    
    final overallConfidence = validFields > 0 ? totalConfidence / validFields : 0.0;
    
    return FieldValidationResult(
      fieldScores: results,
      overallConfidence: overallConfidence,
      isValid: overallConfidence >= 0.7, // 70% threshold
      suggestions: _generateSuggestions(results),
    );
  }
  
  /// Validate individual field
  static FieldScore _validateField(
    String fieldName,
    String fieldValue,
    String documentType,
    String countryCode,
  ) {
    switch (fieldName) {
      case 'licenseNumber':
        return _validateLicenseNumber(fieldValue, countryCode);
      case 'fullName':
        return _validateName(fieldValue, 'fullName');
      case 'fatherName':
        return _validateName(fieldValue, 'fatherName');
      case 'dateOfBirth':
      case 'issueDate':
      case 'expiryDate':
        return _validateDate(fieldValue, fieldName);
      case 'category':
        return _validateCategory(fieldValue, countryCode);
      default:
        return FieldScore(
          fieldName: fieldName,
          confidence: 0.5,
          isValid: fieldValue.isNotEmpty,
          issues: fieldValue.isEmpty ? ['Field is empty'] : [],
          suggestions: [],
        );
    }
  }
  
  /// Validate license number format
  static FieldScore _validateLicenseNumber(String value, String countryCode) {
    final issues = <String>[];
    final suggestions = <String>[];
    double confidence = 0.0;
    
    if (value.isEmpty) {
      issues.add('License number is required');
      return FieldScore(
        fieldName: 'licenseNumber',
        confidence: 0.0,
        isValid: false,
        issues: issues,
        suggestions: ['Please ensure license number is clearly visible'],
      );
    }
    
    // Pakistan license number validation
    if (countryCode == 'PK') {
      final pkPattern = RegExp(r'^\d{5}-\d{7}-\d(\#\d+)?$');
      if (pkPattern.hasMatch(value)) {
        confidence = 0.95;
      } else {
        issues.add('Invalid Pakistan license number format');
        suggestions.add('Expected format: 12345-1234567-1#123');
        confidence = 0.3;
      }
    } else {
      // Generic validation
      if (value.length >= 8 && value.length <= 20) {
        confidence = 0.8;
      } else {
        issues.add('License number length seems incorrect');
        confidence = 0.4;
      }
    }
    
    return FieldScore(
      fieldName: 'licenseNumber',
      confidence: confidence,
      isValid: confidence >= 0.7,
      issues: issues,
      suggestions: suggestions,
    );
  }
  
  /// Validate name fields
  static FieldScore _validateName(String value, String fieldType) {
    final issues = <String>[];
    final suggestions = <String>[];
    double confidence = 0.0;
    
    if (value.isEmpty) {
      issues.add('Name is required');
      return FieldScore(
        fieldName: fieldType,
        confidence: 0.0,
        isValid: false,
        issues: issues,
        suggestions: ['Please ensure name is clearly visible'],
      );
    }
    
    // Basic name validation
    final namePattern = RegExp(r'^[A-Z][A-Z\s]{2,49}$');
    if (namePattern.hasMatch(value)) {
      confidence = 0.9;
    } else {
      issues.add('Name format seems incorrect');
      confidence = 0.5;
    }
    
    // Check for common OCR errors
    if (value.contains(RegExp(r'[0-9]'))) {
      issues.add('Name contains numbers');
      suggestions.add('Names should not contain numbers');
      confidence *= 0.5;
    }
    
    // Check word count
    final words = value.split(' ').where((w) => w.isNotEmpty).toList();
    if (words.length < 2) {
      issues.add('Name seems incomplete');
      suggestions.add('Full names typically have 2-4 words');
      confidence *= 0.7;
    } else if (words.length > 5) {
      issues.add('Name seems too long');
      confidence *= 0.8;
    }
    
    // Pakistani name patterns
    final pakistaniNames = [
      'MUHAMMAD', 'MOHAMMAD', 'AHMED', 'ALI', 'HASSAN', 'HUSSAIN',
      'KHAN', 'SHAH', 'MALIK', 'LODHI', 'REHMAN', 'MEHMOOD', 'NASIR', 'AAMIR'
    ];
    
    if (pakistaniNames.any((name) => value.contains(name))) {
      confidence = min(confidence + 0.1, 1.0); // Bonus for Pakistani names
    }
    
    return FieldScore(
      fieldName: fieldType,
      confidence: confidence,
      isValid: confidence >= 0.6,
      issues: issues,
      suggestions: suggestions,
    );
  }
  
  /// Validate date fields
  static FieldScore _validateDate(String value, String fieldType) {
    final issues = <String>[];
    final suggestions = <String>[];
    double confidence = 0.0;
    
    if (value.isEmpty) {
      issues.add('Date is required');
      return FieldScore(
        fieldName: fieldType,
        confidence: 0.0,
        isValid: false,
        issues: issues,
        suggestions: ['Please ensure date is clearly visible'],
      );
    }
    
    // Date format validation
    final datePatterns = [
      RegExp(r'^\d{1,2}-[A-Z]{3}-\d{4}$'), // 31-AUG-1977
      RegExp(r'^\d{1,2}-\d{1,2}-\d{4}$'),  // 31-08-1977
      RegExp(r'^\d{1,2}/\d{1,2}/\d{4}$'),  // 31/08/1977
    ];
    
    bool validFormat = datePatterns.any((pattern) => pattern.hasMatch(value));
    
    if (validFormat) {
      confidence = 0.9;
      
      // Additional validation based on field type
      try {
        final parsedDate = _parseDate(value);
        final now = DateTime.now();
        
        switch (fieldType) {
          case 'dateOfBirth':
            if (parsedDate.isAfter(now)) {
              issues.add('Birth date cannot be in the future');
              confidence *= 0.3;
            } else if (now.difference(parsedDate).inDays < 6570) { // Less than 18 years
              issues.add('Age seems too young for driving license');
              confidence *= 0.7;
            } else if (now.difference(parsedDate).inDays > 36500) { // More than 100 years
              issues.add('Age seems unrealistic');
              confidence *= 0.5;
            }
            break;
            
          case 'issueDate':
            if (parsedDate.isAfter(now)) {
              issues.add('Issue date cannot be in the future');
              confidence *= 0.3;
            }
            break;
            
          case 'expiryDate':
            if (parsedDate.isBefore(now)) {
              issues.add('License appears to be expired');
              confidence *= 0.8; // Not invalid, just expired
            }
            break;
        }
      } catch (e) {
        issues.add('Date format is not parseable');
        confidence *= 0.5;
      }
    } else {
      issues.add('Invalid date format');
      suggestions.add('Expected format: DD-MMM-YYYY (e.g., 31-AUG-1977)');
      confidence = 0.3;
    }
    
    return FieldScore(
      fieldName: fieldType,
      confidence: confidence,
      isValid: confidence >= 0.6,
      issues: issues,
      suggestions: suggestions,
    );
  }
  
  /// Validate category field
  static FieldScore _validateCategory(String value, String countryCode) {
    final issues = <String>[];
    final suggestions = <String>[];
    double confidence = 0.0;
    
    if (value.isEmpty) {
      issues.add('Category is required');
      return FieldScore(
        fieldName: 'category',
        confidence: 0.0,
        isValid: false,
        issues: issues,
        suggestions: ['Please ensure category is clearly visible'],
      );
    }
    
    // Pakistan category validation
    if (countryCode == 'PK') {
      final validCategories = ['MCYCLE', 'M CAR', 'LTV', 'HTV', 'PSV', 'TRACTOR'];
      final containsValidCategory = validCategories.any((cat) => value.toUpperCase().contains(cat));
      
      if (containsValidCategory) {
        confidence = 0.9;
      } else {
        issues.add('Unknown vehicle category');
        suggestions.add('Common categories: MCYCLE, M CAR, LTV, HTV, PSV');
        confidence = 0.4;
      }
    } else {
      // Generic validation
      if (value.length >= 2 && value.length <= 50) {
        confidence = 0.7;
      } else {
        issues.add('Category format seems incorrect');
        confidence = 0.3;
      }
    }
    
    return FieldScore(
      fieldName: 'category',
      confidence: confidence,
      isValid: confidence >= 0.6,
      issues: issues,
      suggestions: suggestions,
    );
  }
  
  /// Parse date string to DateTime
  static DateTime _parseDate(String dateString) {
    // Handle different date formats
    if (dateString.contains('-')) {
      final parts = dateString.split('-');
      if (parts.length == 3) {
        final day = int.parse(parts[0]);
        final year = int.parse(parts[2]);
        
        int month;
        if (parts[1].length == 3) {
          // Month abbreviation
          final monthMap = {
            'JAN': 1, 'FEB': 2, 'MAR': 3, 'APR': 4, 'MAY': 5, 'JUN': 6,
            'JUL': 7, 'AUG': 8, 'SEP': 9, 'OCT': 10, 'NOV': 11, 'DEC': 12
          };
          month = monthMap[parts[1].toUpperCase()] ?? 1;
        } else {
          month = int.parse(parts[1]);
        }
        
        return DateTime(year, month, day);
      }
    }
    
    throw FormatException('Unable to parse date: $dateString');
  }
  
  /// Generate suggestions for improving data quality
  static List<String> _generateSuggestions(Map<String, FieldScore> fieldScores) {
    final suggestions = <String>[];
    
    final lowConfidenceFields = fieldScores.entries
        .where((entry) => entry.value.confidence < 0.7)
        .toList();
    
    if (lowConfidenceFields.isNotEmpty) {
      suggestions.add('Some fields have low confidence. Please review and correct if needed.');
    }
    
    final invalidFields = fieldScores.entries
        .where((entry) => !entry.value.isValid)
        .toList();
    
    if (invalidFields.isNotEmpty) {
      suggestions.add('Please fix the highlighted fields before submitting.');
    }
    
    return suggestions;
  }
}

/// Result of field validation
class FieldValidationResult {
  final Map<String, FieldScore> fieldScores;
  final double overallConfidence;
  final bool isValid;
  final List<String> suggestions;
  
  const FieldValidationResult({
    required this.fieldScores,
    required this.overallConfidence,
    required this.isValid,
    required this.suggestions,
  });
  
  /// Get fields that need user attention
  List<String> get fieldsNeedingAttention {
    return fieldScores.entries
        .where((entry) => entry.value.confidence < 0.7)
        .map((entry) => entry.key)
        .toList();
  }
  
  /// Get invalid fields
  List<String> get invalidFields {
    return fieldScores.entries
        .where((entry) => !entry.value.isValid)
        .map((entry) => entry.key)
        .toList();
  }
}

/// Individual field score and validation result
class FieldScore {
  final String fieldName;
  final double confidence;
  final bool isValid;
  final List<String> issues;
  final List<String> suggestions;
  
  const FieldScore({
    required this.fieldName,
    required this.confidence,
    required this.isValid,
    required this.issues,
    required this.suggestions,
  });
  
  /// Get confidence level as text
  String get confidenceLevel {
    if (confidence >= 0.9) return 'Very High';
    if (confidence >= 0.8) return 'High';
    if (confidence >= 0.7) return 'Good';
    if (confidence >= 0.5) return 'Medium';
    if (confidence >= 0.3) return 'Low';
    return 'Very Low';
  }
  
  /// Get confidence color
  Color get confidenceColor {
    if (confidence >= 0.8) return Colors.green;
    if (confidence >= 0.7) return Colors.lightGreen;
    if (confidence >= 0.5) return Colors.orange;
    return Colors.red;
  }
}
