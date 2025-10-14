import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../../../core/services/mlkit_document_service.dart';
import '../../../core/services/advanced_image_processor.dart';
import '../../../core/services/document_verification_service.dart';

/// Multi-shot capture system for optimal document quality
class MultiShotCaptureScreen extends StatefulWidget {
  final DocumentType documentType;
  final Function(File, DocumentValidationResult) onBestImageSelected;

  const MultiShotCaptureScreen({
    super.key,
    required this.documentType,
    required this.onBestImageSelected,
  });

  @override
  State<MultiShotCaptureScreen> createState() => _MultiShotCaptureScreenState();
}

class _MultiShotCaptureScreenState extends State<MultiShotCaptureScreen> {
  CameraController? _cameraController;
  bool _isInitialized = false;
  
  final List<CaptureResult> _captureResults = [];
  int _currentShot = 0;
  final int _maxShots = 3;
  bool _isProcessing = false;
  
  late MLKitDocumentService _mlKitService;

  @override
  void initState() {
    super.initState();
    _mlKitService = MLKitDocumentService(countryCode: 'PK');
    _initializeCamera();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _mlKitService.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      _cameraController = CameraController(
        cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('❌ Camera initialization error: $e');
    }
  }

  Future<void> _captureImage() async {
    if (_cameraController == null || _isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      // Capture image
      final image = await _cameraController!.takePicture();
      debugPrint('📸 Captured shot ${_currentShot + 1}/$_maxShots');

      // Process and validate
      final processedImage = await AdvancedImageProcessor.processForOCR(File(image.path));
      final validationResult = await _mlKitService.validateDocument(
        imageFile: processedImage,
        expectedDocumentType: widget.documentType.name,
      );

      // Store result
      _captureResults.add(CaptureResult(
        originalFile: File(image.path),
        processedFile: processedImage,
        validationResult: validationResult,
        shotNumber: _currentShot + 1,
      ));

      _currentShot++;

      if (_currentShot >= _maxShots) {
        // All shots taken, select best one
        _selectBestImage();
      } else {
        setState(() {
          _isProcessing = false;
        });
      }

    } catch (e) {
      debugPrint('❌ Capture error: $e');
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _selectBestImage() {
    if (_captureResults.isEmpty) return;

    // Sort by overall quality score (confidence + field validation)
    _captureResults.sort((a, b) {
      final scoreA = _calculateQualityScore(a.validationResult);
      final scoreB = _calculateQualityScore(b.validationResult);
      return scoreB.compareTo(scoreA);
    });

    final bestResult = _captureResults.first;
    debugPrint('🏆 Selected best image: Shot ${bestResult.shotNumber} (score: ${_calculateQualityScore(bestResult.validationResult).toStringAsFixed(2)})');

    // Return the best image
    widget.onBestImageSelected(bestResult.processedFile, bestResult.validationResult);
    Navigator.pop(context);
  }

  double _calculateQualityScore(DocumentValidationResult result) {
    double score = 0.0;
    
    // OCR confidence (40% weight)
    score += result.confidence * 0.4;
    
    // Field validation confidence (40% weight)
    score += result.fieldValidation.overallConfidence * 0.4;
    
    // Number of extracted fields (10% weight)
    final fieldBonus = (result.extractedData.length / 6.0).clamp(0.0, 1.0) * 0.1;
    score += fieldBonus;
    
    // Valid fields bonus (10% weight)
    final validFieldsRatio = result.fieldValidation.fieldScores.values
        .where((score) => score.isValid)
        .length / result.fieldValidation.fieldScores.length.clamp(1, 10);
    score += validFieldsRatio * 0.1;
    
    return score.clamp(0.0, 1.0);
  }

  String _getDocumentTypeName() {
    switch (widget.documentType) {
      case DocumentType.drivingLicenseFront:
        return 'Driving License (Front)';
      case DocumentType.drivingLicenseBack:
        return 'Driving License (Back)';
      case DocumentType.vehicleRegistration:
        return 'Vehicle Registration';
      case DocumentType.insuranceCertificate:
        return 'Insurance Certificate';
      case DocumentType.driverPhoto:
        return 'Driver Photo';
      case DocumentType.vehiclePhoto:
        return 'Vehicle Photo';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Multi-Shot Capture - ${_getDocumentTypeName()}'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (!_isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return Stack(
      children: [
        // Camera preview
        Positioned.fill(
          child: CameraPreview(_cameraController!),
        ),
        
        // Progress indicator
        Positioned(
          top: 20,
          left: 20,
          right: 20,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  'Shot ${_currentShot + 1} of $_maxShots',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: _currentShot / _maxShots,
                  backgroundColor: Colors.grey,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade400),
                ),
                const SizedBox(height: 8),
                Text(
                  _isProcessing 
                      ? 'Processing image...' 
                      : 'Position document clearly and tap capture',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        
        // Previous shots preview
        if (_captureResults.isNotEmpty)
          Positioned(
            right: 20,
            top: 120,
            child: Column(
              children: _captureResults.map((result) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: Container(
                  width: 60,
                  height: 40,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.file(
                      result.originalFile,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              )).toList(),
            ),
          ),
        
        // Capture button
        Positioned(
          bottom: 50,
          left: 0,
          right: 0,
          child: Center(
            child: GestureDetector(
              onTap: _isProcessing ? null : _captureImage,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isProcessing ? Colors.grey : Colors.white,
                  border: Border.all(
                    color: Colors.blue.shade400,
                    width: 4,
                  ),
                ),
                child: Icon(
                  _isProcessing ? Icons.hourglass_empty : Icons.camera,
                  color: Colors.blue.shade400,
                  size: 32,
                ),
              ),
            ),
          ),
        ),
        
        // Skip to selection (if at least one shot taken)
        if (_captureResults.isNotEmpty && !_isProcessing)
          Positioned(
            bottom: 150,
            left: 0,
            right: 0,
            child: Center(
              child: TextButton(
                onPressed: _selectBestImage,
                style: TextButton.styleFrom(
                  backgroundColor: Colors.black54,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: Text('Use Best of ${_captureResults.length} Shot${_captureResults.length > 1 ? 's' : ''}'),
              ),
            ),
          ),
      ],
    );
  }
}

/// Result of a single capture attempt
class CaptureResult {
  final File originalFile;
  final File processedFile;
  final DocumentValidationResult validationResult;
  final int shotNumber;

  CaptureResult({
    required this.originalFile,
    required this.processedFile,
    required this.validationResult,
    required this.shotNumber,
  });
}

/// Document type enum (should match the one in document_verification_service.dart)
// Removed duplicate enum definition since we're importing it from document_verification_service.dart
