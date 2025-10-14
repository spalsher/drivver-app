import 'dart:io';
import 'package:flutter/material.dart';

/// Country-specific document validation configurations
class DocumentValidationConfig {
  static const String _defaultCountry = 'US'; // Default country
  
  /// Get validation config for a specific country
  static Map<String, dynamic> getConfig(String country) {
    return _countryConfigs[country.toUpperCase()] ?? _countryConfigs[_defaultCountry]!;
  }
  
  /// Country-specific validation configurations
  static const Map<String, Map<String, dynamic>> _countryConfigs = {
    // United States
    'US': {
      'driverLicense': {
        'keywords': [
          'DRIVER', 'LICENSE', 'LICENCE', 'DL', 'CDL',
          'DEPARTMENT', 'MOTOR', 'VEHICLE', 'DMV',
          'EXPIRES', 'EXPIRY', 'DOB', 'DATE OF BIRTH',
          'CLASS', 'RESTRICTIONS', 'ENDORSEMENTS'
        ],
        'licensePatterns': [
          r'(?:DL|LICENSE|LICENCE)\s*(?:NO|NUMBER|#)?\s*:?\s*([A-Z0-9]{8,15})',
          r'([A-Z0-9]{8,15})', // Fallback pattern
        ],
        'namePatterns': [
          r'(?:NAME|FULL NAME)\s*:?\s*([A-Z\s]{2,50})',
          r'([A-Z]{2,}\s+[A-Z]{2,})', // First Last pattern
        ],
        'datePatterns': [
          r'(?:EXP|EXPIRES|EXPIRY)\s*:?\s*(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})',
          r'(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})', // General date pattern
        ],
        'confidenceThreshold': 0.3,
      },
    },
    
    // United Kingdom
    'UK': {
      'driverLicense': {
        'keywords': [
          'DRIVING', 'LICENCE', 'DRIVER', 'LICENSE',
          'DVLA', 'GREAT BRITAIN', 'UNITED KINGDOM',
          'EXPIRES', 'EXPIRY', 'VALID', 'UNTIL',
          'CATEGORIES', 'RESTRICTIONS', 'DOB'
        ],
        'licensePatterns': [
          r'([A-Z]{5}\d{6}[A-Z]{2}\d{2}[A-Z])', // UK format: MORGA657054SM9IJ
          r'(?:LICENCE|LICENSE)\s*(?:NO|NUMBER)?\s*:?\s*([A-Z0-9]{16})',
        ],
        'namePatterns': [
          r'([A-Z]{2,}\s+[A-Z\s]{2,50})', // UK name format
          r'(?:NAME|SURNAME)\s*:?\s*([A-Z\s]{2,50})',
        ],
        'datePatterns': [
          r'(\d{2}\.\d{2}\.\d{4})', // DD.MM.YYYY format
          r'(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})',
        ],
        'confidenceThreshold': 0.25,
      },
    },
    
    // Canada
    'CA': {
      'driverLicense': {
        'keywords': [
          'DRIVER', 'LICENSE', 'LICENCE', 'PERMIT',
          'PROVINCE', 'ONTARIO', 'QUEBEC', 'ALBERTA', 'BRITISH COLUMBIA',
          'EXPIRES', 'EXPIRY', 'DOB', 'DATE OF BIRTH',
          'CLASS', 'RESTRICTIONS', 'CONDITIONS'
        ],
        'licensePatterns': [
          r'([A-Z]\d{4}-\d{5}-\d{5})', // Ontario format
          r'([A-Z0-9]{8,15})', // General Canadian format
        ],
        'namePatterns': [
          r'(?:NAME|NOM)\s*:?\s*([A-Z\s]{2,50})',
          r'([A-Z]{2,}\s+[A-Z]{2,})',
        ],
        'datePatterns': [
          r'(?:EXP|EXPIRES|EXPIRY)\s*:?\s*(\d{4}[/-]\d{2}[/-]\d{2})', // YYYY-MM-DD
          r'(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})',
        ],
        'confidenceThreshold': 0.3,
      },
    },
    
    // Australia
    'AU': {
      'driverLicense': {
        'keywords': [
          'DRIVER', 'LICENCE', 'LICENSE', 'PERMIT',
          'NSW', 'VIC', 'QLD', 'WA', 'SA', 'TAS', 'ACT', 'NT',
          'EXPIRES', 'EXPIRY', 'DOB', 'DATE OF BIRTH',
          'CLASS', 'CONDITIONS', 'RESTRICTIONS'
        ],
        'licensePatterns': [
          r'(\d{8,10})', // Australian format: 8-10 digits
          r'([A-Z0-9]{8,12})',
        ],
        'namePatterns': [
          r'(?:NAME|SURNAME)\s*:?\s*([A-Z\s]{2,50})',
          r'([A-Z]{2,}\s+[A-Z]{2,})',
        ],
        'datePatterns': [
          r'(\d{2}[/-]\d{2}[/-]\d{4})', // DD/MM/YYYY
          r'(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})',
        ],
        'confidenceThreshold': 0.25,
      },
    },
    
    // India
    'IN': {
      'driverLicense': {
        'keywords': [
          'DRIVING', 'LICENCE', 'LICENSE', 'PERMIT',
          'INDIA', 'BHARATH', 'GOVERNMENT', 'STATE',
          'VALID', 'UPTO', 'EXPIRES', 'EXPIRY',
          'DOB', 'DATE', 'BIRTH', 'CLASS', 'VEHICLE'
        ],
        'licensePatterns': [
          r'([A-Z]{2}\d{2}\s?\d{11})', // Indian format: HR06 20110012345
          r'([A-Z]{2}[-\s]?\d{2}[-\s]?\d{4}[-\s]?\d{7})',
        ],
        'namePatterns': [
          r'(?:NAME|नाम)\s*:?\s*([A-Z\s]{2,50})',
          r'([A-Z]{2,}\s+[A-Z\s]{2,50})',
        ],
        'datePatterns': [
          r'(\d{2}[-/]\d{2}[-/]\d{4})', // DD-MM-YYYY or DD/MM/YYYY
          r'(\d{1,2}[-/]\d{1,2}[-/]\d{2,4})',
        ],
        'confidenceThreshold': 0.2,
      },
    },
    
    // Germany
    'DE': {
      'driverLicense': {
        'keywords': [
          'FÜHRERSCHEIN', 'FAHRERLAUBNIS', 'DRIVING', 'LICENCE',
          'DEUTSCHLAND', 'GERMANY', 'BUNDESREPUBLIK',
          'GÜLTIG', 'BIS', 'EXPIRES', 'KLASSE', 'CLASS'
        ],
        'licensePatterns': [
          r'([A-Z0-9]{11})', // German format: 11 characters
          r'(\d{10})', // 10 digits format
        ],
        'namePatterns': [
          r'(?:NAME|NACHNAME)\s*:?\s*([A-Z\s]{2,50})',
          r'([A-Z]{2,}\s+[A-Z]{2,})',
        ],
        'datePatterns': [
          r'(\d{2}\.\d{2}\.\d{4})', // DD.MM.YYYY
          r'(\d{1,2}[./]\d{1,2}[./]\d{2,4})',
        ],
        'confidenceThreshold': 0.25,
      },
    },
    
    // France
    'FR': {
      'driverLicense': {
        'keywords': [
          'PERMIS', 'CONDUIRE', 'LICENCE', 'DRIVING',
          'FRANCE', 'RÉPUBLIQUE', 'FRANÇAISE',
          'VALABLE', 'JUSQU', 'EXPIRES', 'CATÉGORIE'
        ],
        'licensePatterns': [
          r'(\d{12})', // French format: 12 digits
          r'([A-Z0-9]{10,15})',
        ],
        'namePatterns': [
          r'(?:NOM|NAME)\s*:?\s*([A-Z\s]{2,50})',
          r'([A-Z]{2,}\s+[A-Z]{2,})',
        ],
        'datePatterns': [
          r'(\d{2}/\d{2}/\d{4})', // DD/MM/YYYY
          r'(\d{1,2}[./]\d{1,2}[./]\d{2,4})',
        ],
        'confidenceThreshold': 0.25,
      },
    },
    
    // Pakistan
    'PK': {
      'driverLicense': {
        'keywords': [
          'DRIVING', 'LICENSE', 'LICENCE', 'SINDH', 'PAKISTAN',
          'POLICE', 'DLS', 'CNIC', 'STRIVING', 'SERVE',
          'LICENSE NO', 'NAME', 'FATHER', 'HUSBAND',
          'DATE', 'BIRTH', 'CATEGORY', 'CYCLE', 'CAR',
          'ISSUE', 'VALID', 'UPTO', 'KARACHI', 'LAHORE',
          'ISLAMABAD', 'PUNJAB', 'BALOCHISTAN', 'KPK',
          'LICENSING', 'AUTHORITY', 'BLOOD', 'GROUP',
          'ADDRESS', 'PSV', 'DIGP', 'TRAFFIC'
        ],
        'licensePatterns': [
          r'(\d{5}[-]\d{7}[-]\d[#]\d{3})', // Pakistani format: 42301-1083424-9#417
          r'LICENSE\s*NO[:.]\s*(\d{5}[-]\d{7}[-]\d[#]?\d{3})',
          r'(\d{5}[-]\d{7}[-]\d)', // CNIC format
          r'([A-Z0-9]{15,25})', // Fallback pattern
        ],
        'namePatterns': [
          r'NAME[:\s]+([A-Z\s]{3,50})', // Name field
          r'([A-Z]{3,}\s+[A-Z\s]{2,50})', // First Middle Last pattern
          r'FATHER[/]HUSBAND[:\s]+([A-Z\s]{3,50})', // Father/Husband name
        ],
        'datePatterns': [
          r'(\d{1,2}[-]\w{3}[-]\d{4})', // DD-MMM-YYYY (31-Aug-1977)
          r'(\d{1,2}[-/]\d{1,2}[-/]\d{4})', // DD-MM-YYYY or DD/MM/YYYY
          r'BIRTH[:\s]+(\d{1,2}[-]\w{3}[-]\d{4})',
          r'ISSUE[:\s]+(\d{1,2}[-]\w{3}[-]\d{4})',
          r'VALID\s+UPTO[:\s]+(\d{1,2}[-]\w{3}[-]\d{4})',
        ],
        'confidenceThreshold': 0.15, // Lower threshold due to unique format
      },
    },
  };
  
  /// Get list of supported countries
  static List<String> getSupportedCountries() {
    return _countryConfigs.keys.toList();
  }
  
  /// Add custom country configuration
  static void addCountryConfig(String countryCode, Map<String, dynamic> config) {
    // This would be used to add new country configurations dynamically
    debugPrint('Adding custom config for country: $countryCode');
  }
}
