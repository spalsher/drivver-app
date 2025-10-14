import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/document_verification_service.dart';

/// Widget to display extracted data from ML Kit and allow auto-fill
class ExtractedDataWidget extends StatelessWidget {
  final DocumentType documentType;

  const ExtractedDataWidget({
    Key? key,
    required this.documentType,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<DocumentVerificationService>(
      builder: (context, docService, child) {
        final extractedData = docService.extractedData;
        
        if (extractedData.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            border: Border.all(color: Colors.green.shade200),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.smart_toy,
                    color: Colors.green.shade600,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Auto-Extracted Information',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Display extracted data based on document type
              ...extractedData.entries.map((entry) => 
                _buildDataField(context, entry.key, entry.value)
              ).toList(),
              
              const SizedBox(height: 12),
              
              // Auto-fill button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showAutoFillDialog(context, extractedData),
                  icon: const Icon(Icons.auto_fix_high),
                  label: const Text('Use This Information'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDataField(BuildContext context, String key, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              _formatFieldName(key),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.green.shade200),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                softWrap: true,
                overflow: TextOverflow.visible,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatFieldName(String key) {
    switch (key) {
      case 'licenseNumber':
        return 'License Number';
      case 'fullName':
        return 'Full Name';
      case 'expiryDate':
        return 'Expiry Date';
      case 'vin':
        return 'VIN';
      case 'licensePlate':
        return 'License Plate';
      case 'make':
        return 'Vehicle Make';
      case 'policyNumber':
        return 'Policy Number';
      case 'insurer':
        return 'Insurance Company';
      default:
        return key.replaceAllMapped(
          RegExp(r'([A-Z])'),
          (match) => ' ${match.group(0)}',
        ).trim();
    }
  }

  void _showAutoFillDialog(BuildContext context, Map<String, String> extractedData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.auto_fix_high, color: Colors.green),
            SizedBox(width: 8),
            Text('Auto-Fill Information'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'The following information was automatically extracted from your document:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            ...extractedData.entries.map((entry) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_formatFieldName(entry.key)}:',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      entry.value,
                      softWrap: true,
                      overflow: TextOverflow.visible,
                    ),
                  ),
                ],
              ),
            )).toList(),
            const SizedBox(height: 16),
            const Text(
              'Would you like to use this information to fill your profile?',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _handleAutoFill(context, extractedData);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Use Information'),
          ),
        ],
      ),
    );
  }

  void _handleAutoFill(BuildContext context, Map<String, String> extractedData) {
    // Here you would integrate with your profile/registration forms
    // For now, we'll show a success message
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text('Auto-filled ${extractedData.length} fields from document'),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );

    // TODO: Implement actual auto-fill logic based on your app's architecture
    // This could involve:
    // 1. Navigating to profile/registration screen
    // 2. Pre-filling form fields with extracted data
    // 3. Updating user profile with extracted information
    
    debugPrint('🎯 Auto-fill data: $extractedData');
  }
}

/// Processing indicator widget for ML Kit validation
class DocumentProcessingIndicator extends StatelessWidget {
  const DocumentProcessingIndicator({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<DocumentVerificationService>(
      builder: (context, docService, child) {
        if (!docService.isProcessingDocument) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            border: Border.all(color: Colors.blue.shade200),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Processing Document...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Using AI to validate and extract information',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.blue.shade600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Validation result widget
class DocumentValidationResult extends StatelessWidget {
  final bool isValid;
  final String? errorMessage;
  final double confidence;

  const DocumentValidationResult({
    Key? key,
    required this.isValid,
    this.errorMessage,
    required this.confidence,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isValid ? Colors.green.shade50 : Colors.red.shade50,
        border: Border.all(
          color: isValid ? Colors.green.shade200 : Colors.red.shade200,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isValid ? Icons.check_circle : Icons.error,
                color: isValid ? Colors.green.shade600 : Colors.red.shade600,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                isValid ? 'Document Validated' : 'Validation Failed',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isValid ? Colors.green.shade800 : Colors.red.shade800,
                ),
              ),
            ],
          ),
          if (!isValid && errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              errorMessage!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.red.shade700,
              ),
            ),
          ],
          if (isValid) ...[
            const SizedBox(height: 8),
            Text(
              'Confidence: ${(confidence * 100).toInt()}%',
              style: TextStyle(
                fontSize: 14,
                color: Colors.green.shade600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
