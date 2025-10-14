import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/document_verification_service.dart';
import '../../../core/config/document_validation_config.dart';

/// Country selector widget for document validation
class CountrySelector extends StatelessWidget {
  const CountrySelector({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<DocumentVerificationService>(
      builder: (context, docService, child) {
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            border: Border.all(color: Colors.blue.shade200),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.public,
                    color: Colors.blue.shade600,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Document Country/Region',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Select your country to improve document recognition accuracy:',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.blue.shade600,
                ),
              ),
              const SizedBox(height: 12),
              
              // Country dropdown
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.blue.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: docService.countryCode,
                    isExpanded: true,
                    items: _getCountryItems(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        docService.setCountryCode(newValue);
                        _showCountryChangedSnackbar(context, newValue);
                      }
                    },
                  ),
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Help text
              Text(
                'This helps the AI recognize text patterns specific to your country\'s documents.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue.shade500,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<DropdownMenuItem<String>> _getCountryItems() {
    final countries = {
      'PK': '🇵🇰 Pakistan',
      'US': '🇺🇸 United States',
      'UK': '🇬🇧 United Kingdom',
      'CA': '🇨🇦 Canada',
      'AU': '🇦🇺 Australia',
      'IN': '🇮🇳 India',
      'DE': '🇩🇪 Germany',
      'FR': '🇫🇷 France',
    };

    return countries.entries.map((entry) {
      return DropdownMenuItem<String>(
        value: entry.key,
        child: Text(entry.value),
      );
    }).toList();
  }

  void _showCountryChangedSnackbar(BuildContext context, String countryCode) {
    final countryNames = {
      'PK': 'Pakistan',
      'US': 'United States',
      'UK': 'United Kingdom', 
      'CA': 'Canada',
      'AU': 'Australia',
      'IN': 'India',
      'DE': 'Germany',
      'FR': 'France',
    };

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text('Document validation set to ${countryNames[countryCode]}'),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

/// Debug info widget to show validation details
class ValidationDebugInfo extends StatelessWidget {
  final Map<String, dynamic>? validationResult;

  const ValidationDebugInfo({
    Key? key,
    this.validationResult,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (validationResult == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.bug_report,
                size: 16,
                color: Colors.grey.shade600,
              ),
              const SizedBox(width: 6),
              Text(
                'Validation Debug Info',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          if (validationResult!['foundKeywords'] != null) ...[
            Text(
              'Found Keywords: ${validationResult!['foundKeywords'].join(", ")}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 4),
          ],
          
          if (validationResult!['expectedKeywords'] != null) ...[
            Text(
              'Expected Keywords: ${validationResult!['expectedKeywords'].take(5).join(", ")}...',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 4),
          ],
          
          Text(
            'Confidence: ${((validationResult!['confidence'] ?? 0.0) * 100).toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
