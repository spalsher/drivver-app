import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/services/document_verification_service.dart';
import '../../../core/services/field_validation_system.dart';

/// Manual correction interface for extracted document data
class ManualCorrectionScreen extends StatefulWidget {
  final DocumentType documentType;
  final Map<String, String> extractedData;
  final FieldValidationResult validationResult;
  final Function(Map<String, String>) onDataCorrected;

  const ManualCorrectionScreen({
    super.key,
    required this.documentType,
    required this.extractedData,
    required this.validationResult,
    required this.onDataCorrected,
  });

  @override
  State<ManualCorrectionScreen> createState() => _ManualCorrectionScreenState();
}

class _ManualCorrectionScreenState extends State<ManualCorrectionScreen> {
  late Map<String, TextEditingController> _controllers;
  late Map<String, String> _correctedData;
  late FieldValidationResult _currentValidation;
  
  @override
  void initState() {
    super.initState();
    _correctedData = Map<String, String>.from(widget.extractedData);
    _currentValidation = widget.validationResult;
    
    // Initialize controllers
    _controllers = {};
    for (final entry in _correctedData.entries) {
      _controllers[entry.key] = TextEditingController(text: entry.value);
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _validateField(String fieldName, String value) {
    setState(() {
      _correctedData[fieldName] = value;
      
      // Re-validate all data
      _currentValidation = FieldValidationSystem.validateExtractedData(
        _correctedData,
        widget.documentType.name,
        'PK', // TODO: Get from user preferences
      );
    });
  }

  void _submitCorrectedData() {
    if (_currentValidation.isValid) {
      widget.onDataCorrected(_correctedData);
      Navigator.pop(context);
    } else {
      _showValidationErrorDialog();
    }
  }

  void _showValidationErrorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Validation Errors'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Please fix the following issues:'),
            const SizedBox(height: 12),
            ...widget.validationResult.invalidFields.map((field) {
              final score = _currentValidation.fieldScores[field]!;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getFieldDisplayName(field),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    ...score.issues.map((issue) => Text(
                      '• $issue',
                      style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                    )),
                  ],
                ),
              );
            }),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _getFieldDisplayName(String fieldName) {
    switch (fieldName) {
      case 'licenseNumber':
        return 'License Number';
      case 'fullName':
        return 'Full Name';
      case 'fatherName':
        return 'Father/Husband Name';
      case 'dateOfBirth':
        return 'Date of Birth';
      case 'issueDate':
        return 'Issue Date';
      case 'expiryDate':
        return 'Expiry Date';
      case 'category':
        return 'Category';
      default:
        return fieldName;
    }
  }

  Widget _buildFieldEditor(String fieldName, String value) {
    final score = _currentValidation.fieldScores[fieldName];
    final controller = _controllers[fieldName]!;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Field header with confidence indicator
          Row(
            children: [
              Expanded(
                child: Text(
                  _getFieldDisplayName(fieldName),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (score != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: score.confidenceColor.withOpacity(0.1),
                    border: Border.all(color: score.confidenceColor),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        score.isValid ? Icons.check_circle : Icons.warning,
                        size: 16,
                        color: score.confidenceColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${(score.confidence * 100).round()}%',
                        style: TextStyle(
                          color: score.confidenceColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          
          const SizedBox(height: 8),
          
          // Text field
          TextFormField(
            controller: controller,
            onChanged: (value) => _validateField(fieldName, value),
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: score?.isValid == false ? Colors.red : Colors.grey,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: score?.isValid == false ? Colors.red : Colors.grey.shade300,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: score?.isValid == false ? Colors.red : Colors.blue,
                  width: 2,
                ),
              ),
              filled: true,
              fillColor: score?.isValid == false 
                  ? Colors.red.shade50 
                  : Colors.grey.shade50,
              suffixIcon: score?.isValid == true
                  ? Icon(Icons.check_circle, color: Colors.green.shade600)
                  : score?.isValid == false
                      ? Icon(Icons.error, color: Colors.red.shade600)
                      : null,
            ),
            inputFormatters: _getInputFormatters(fieldName),
            textCapitalization: _getTextCapitalization(fieldName),
          ),
          
          // Issues and suggestions
          if (score != null && (score.issues.isNotEmpty || score.suggestions.isNotEmpty)) ...[
            const SizedBox(height: 8),
            
            // Issues
            if (score.issues.isNotEmpty) ...[
              ...score.issues.map((issue) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.error,
                      size: 16,
                      color: Colors.red.shade600,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        issue,
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
            ],
            
            // Suggestions
            if (score.suggestions.isNotEmpty) ...[
              ...score.suggestions.map((suggestion) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      size: 16,
                      color: Colors.blue.shade600,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        suggestion,
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
            ],
          ],
          
          // Quick fix suggestions for common errors
          if (fieldName == 'fullName' || fieldName == 'fatherName') 
            _buildNameSuggestions(fieldName, value),
        ],
      ),
    );
  }

  Widget _buildNameSuggestions(String fieldName, String value) {
    final suggestions = _getNameSuggestions(value);
    
    if (suggestions.isEmpty) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick fixes:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade700,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: suggestions.map((suggestion) => GestureDetector(
              onTap: () {
                _controllers[fieldName]!.text = suggestion;
                _validateField(fieldName, suggestion);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  border: Border.all(color: Colors.blue.shade200),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  suggestion,
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontSize: 12,
                  ),
                ),
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }

  List<String> _getNameSuggestions(String value) {
    final suggestions = <String>[];
    
    // Common OCR corrections
    final corrections = {
      'LODAI': 'LODHI',
      'MEHMOOD': 'MEHMOOD',
      '0': 'O',
      '1': 'I',
      '5': 'S',
      '8': 'B',
    };
    
    String corrected = value;
    for (final entry in corrections.entries) {
      if (value.contains(entry.key)) {
        corrected = corrected.replaceAll(entry.key, entry.value);
        if (corrected != value) {
          suggestions.add(corrected);
        }
      }
    }
    
    return suggestions.take(3).toList(); // Limit to 3 suggestions
  }

  List<TextInputFormatter> _getInputFormatters(String fieldName) {
    switch (fieldName) {
      case 'licenseNumber':
        return [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9\-#]')),
        ];
      case 'fullName':
      case 'fatherName':
        return [
          FilteringTextInputFormatter.allow(RegExp(r'[A-Z\s]')),
          TextInputFormatter.withFunction((oldValue, newValue) {
            return newValue.copyWith(text: newValue.text.toUpperCase());
          }),
        ];
      default:
        return [];
    }
  }

  TextCapitalization _getTextCapitalization(String fieldName) {
    switch (fieldName) {
      case 'fullName':
      case 'fatherName':
        return TextCapitalization.characters;
      default:
        return TextCapitalization.none;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review & Correct Data'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: _submitCorrectedData,
            icon: const Icon(Icons.check, color: Colors.white),
            label: const Text(
              'Submit',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Overall confidence indicator
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _currentValidation.overallConfidence >= 0.8 
                  ? Colors.green.shade50 
                  : _currentValidation.overallConfidence >= 0.6
                      ? Colors.orange.shade50
                      : Colors.red.shade50,
              border: Border(
                bottom: BorderSide(
                  color: _currentValidation.overallConfidence >= 0.8 
                      ? Colors.green.shade200
                      : _currentValidation.overallConfidence >= 0.6
                          ? Colors.orange.shade200
                          : Colors.red.shade200,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _currentValidation.isValid ? Icons.check_circle : Icons.warning,
                  color: _currentValidation.overallConfidence >= 0.8 
                      ? Colors.green.shade600
                      : _currentValidation.overallConfidence >= 0.6
                          ? Colors.orange.shade600
                          : Colors.red.shade600,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Overall Confidence: ${(_currentValidation.overallConfidence * 100).round()}%',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (_currentValidation.suggestions.isNotEmpty)
                        Text(
                          _currentValidation.suggestions.first,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Scrollable form
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Please review and correct the extracted information:',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Field editors
                  ..._correctedData.entries.map((entry) =>
                      _buildFieldEditor(entry.key, entry.value)
                  ),
                  
                  const SizedBox(height: 100), // Space for bottom button
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _submitCorrectedData,
        backgroundColor: _currentValidation.isValid ? Colors.green : Colors.grey,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.check),
        label: const Text('Submit Corrected Data'),
      ),
    );
  }
}
