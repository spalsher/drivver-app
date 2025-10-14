import 'package:flutter/material.dart';
import '../../../core/services/document_verification_service.dart';
import '../../../core/services/ultimate_ocr_processor.dart';

/// ULTIMATE Real-Time Correction Preview Widget
class UltimateCorrectionPreviewWidget extends StatefulWidget {
  final DocumentType documentType;
  final Map<String, String> rawExtractedData;
  final Function(Map<String, String>) onDataConfirmed;

  const UltimateCorrectionPreviewWidget({
    super.key,
    required this.documentType,
    required this.rawExtractedData,
    required this.onDataConfirmed,
  });

  @override
  State<UltimateCorrectionPreviewWidget> createState() => _UltimateCorrectionPreviewWidgetState();
}

class _UltimateCorrectionPreviewWidgetState extends State<UltimateCorrectionPreviewWidget>
    with TickerProviderStateMixin {
  
  late Map<String, String> _processedData;
  late Map<String, dynamic> _correctionReport;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  bool _showingCorrections = false;
  bool _userApproved = false;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _processData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _processData() {
    debugPrint('🧠 Starting ULTIMATE processing...');
    
    // Apply ULTIMATE OCR Processing
    _processedData = UltimateOCRProcessor.processExtractedData(widget.rawExtractedData);
    _correctionReport = UltimateOCRProcessor.generateCorrectionReport(
      widget.rawExtractedData,
      _processedData,
    );
    
    debugPrint('✅ ULTIMATE processing complete');
    debugPrint('📊 Corrections made: ${_correctionReport['corrections'].length}');
    
    setState(() {
      _showingCorrections = true;
    });
    
    _animationController.forward();
  }

  void _confirmData() {
    setState(() {
      _userApproved = true;
    });
    
    widget.onDataConfirmed(_processedData);
  }

  void _rejectAndEdit() {
    // Navigate to manual correction screen with processed data
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ManualCorrectionScreen(
          documentType: widget.documentType,
          extractedData: _processedData,
          validationResult: FieldValidationResult(
            fieldScores: {},
            overallConfidence: _correctionReport['confidence'] ?? 0.8,
            isValid: true,
            suggestions: List<String>.from(_correctionReport['suggestions'] ?? []),
          ),
          onDataCorrected: (correctedData) {
            setState(() {
              _processedData = correctedData;
              _userApproved = true;
            });
            widget.onDataConfirmed(correctedData);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_showingCorrections) {
      return _buildProcessingIndicator();
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.blue.shade50,
              Colors.green.shade50,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.blue.shade200,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.shade100,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _buildCorrectionsList(),
            const SizedBox(height: 20),
            _buildProcessedData(),
            const SizedBox(height: 20),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessingIndicator() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.orange.shade600),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🧠 ULTIMATE AI Processing...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Applying Pakistani intelligence and corrections',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final corrections = _correctionReport['corrections'] as Map<String, dynamic>;
    final confidence = _correctionReport['confidence'] as double;
    
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.shade600,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.auto_fix_high,
            color: Colors.white,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ULTIMATE AI Corrections Applied',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                ),
              ),
              Text(
                '${corrections.length} corrections • ${(confidence * 100).round()}% confidence',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue.shade600,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: confidence > 0.9 
                ? Colors.green.shade100 
                : confidence > 0.7 
                    ? Colors.orange.shade100 
                    : Colors.red.shade100,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${(confidence * 100).round()}%',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: confidence > 0.9 
                  ? Colors.green.shade700 
                  : confidence > 0.7 
                      ? Colors.orange.shade700 
                      : Colors.red.shade700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCorrectionsList() {
    final corrections = _correctionReport['corrections'] as Map<String, dynamic>;
    
    if (corrections.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade600, size: 20),
            const SizedBox(width: 8),
            Text(
              'No corrections needed - data is perfect!',
              style: TextStyle(
                color: Colors.green.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Intelligent Corrections Made:',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        ...corrections.entries.map((entry) {
          final fieldName = entry.key;
          final correction = entry.value as Map<String, dynamic>;
          
          return _buildCorrectionItem(fieldName, correction);
        }).toList(),
      ],
    );
  }

  Widget _buildCorrectionItem(String fieldName, Map<String, dynamic> correction) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_fix_high, size: 16, color: Colors.blue.shade600),
              const SizedBox(width: 6),
              Text(
                _getFieldDisplayName(fieldName),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Before:',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.red.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      correction['original'] ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade700,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'After:',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.green.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      correction['corrected'] ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            correction['reason'] ?? '',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade600,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessedData() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade600, size: 18),
              const SizedBox(width: 8),
              Text(
                'Final Processed Data:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._processedData.entries.map((entry) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    '${_getFieldDisplayName(entry.key)}:',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    entry.value,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade800,
                      fontWeight: FontWeight.bold,
                    ),
                    softWrap: true,
                    overflow: TextOverflow.visible,
                  ),
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _rejectAndEdit,
            icon: const Icon(Icons.edit, size: 16),
            label: const Text('Edit Manually'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.orange.shade700,
              side: BorderSide(color: Colors.orange.shade300),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: _userApproved ? null : _confirmData,
            icon: Icon(
              _userApproved ? Icons.check_circle : Icons.thumb_up,
              size: 16,
            ),
            label: Text(_userApproved ? 'Confirmed!' : 'Looks Perfect!'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _userApproved ? Colors.green : Colors.blue.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  String _getFieldDisplayName(String fieldName) {
    switch (fieldName) {
      case 'licenseNumber':
        return 'License Number';
      case 'fullName':
        return 'Full Name';
      case 'fatherName':
        return 'Father Name';
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
}
