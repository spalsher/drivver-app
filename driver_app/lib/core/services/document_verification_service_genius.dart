import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as path;
import 'package:mime/mime.dart';
import 'api_service.dart';
import 'genius_scan_service.dart';

enum DocumentType {
  drivingLicenseFront,
  drivingLicenseBack,
  vehicleRegistration,
  insuranceCertificate,
  driverPhoto,
  vehiclePhoto,
}

enum DocumentStatus {
  notUploaded,
  uploading,
  underReview,
  approved,
  rejected,
}

class DocumentInfo {
  final DocumentType type;
  final String title;
  final String description;
  final String icon;
  final DocumentStatus status;
  final String? filePath;
  final DateTime? uploadedAt;
  final String? rejectionReason;

  const DocumentInfo({
    required this.type,
    required this.title,
    required this.description,
    required this.icon,
    this.status = DocumentStatus.notUploaded,
    this.filePath,
    this.uploadedAt,
    this.rejectionReason,
  });

  DocumentInfo copyWith({
    DocumentType? type,
    String? title,
    String? description,
    String? icon,
    DocumentStatus? status,
    String? filePath,
    DateTime? uploadedAt,
    String? rejectionReason,
  }) {
    return DocumentInfo(
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      status: status ?? this.status,
      filePath: filePath ?? this.filePath,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
    );
  }
}

/// Professional Document Verification Service using Genius Scan
class DocumentVerificationService extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final ImagePicker _imagePicker = ImagePicker();

  // State management
  bool _isLoading = false;
  bool _isProcessingDocument = false;
  String? _error;
  String _overallVerificationStatus = 'pending';
  bool _isFullyVerified = false;
  int _approvedCount = 0;
  int _totalRequired = 6;
  Map<String, String> _extractedData = {};
  DocumentType? _currentProcessingDocument;

  // Getters
  bool get isLoading => _isLoading;
  bool get isProcessingDocument => _isProcessingDocument;
  String? get error => _error;
  String get overallVerificationStatus => _overallVerificationStatus;
  bool get isFullyVerified => _isFullyVerified;
  int get approvedCount => _approvedCount;
  int get totalRequired => _totalRequired;
  double get completionPercentage => _totalRequired > 0 ? _approvedCount / _totalRequired : 0.0;
  Map<String, String> get extractedData => _extractedData;
  DocumentType? get currentProcessingDocument => _currentProcessingDocument;

  final Map<DocumentType, DocumentInfo> _documents = {
    DocumentType.drivingLicenseFront: DocumentInfo(
      type: DocumentType.drivingLicenseFront,
      title: 'Driving License (Front)',
      description: 'Front side of your driving license',
      icon: '🪪',
    ),
    DocumentType.drivingLicenseBack: DocumentInfo(
      type: DocumentType.drivingLicenseBack,
      title: 'Driving License (Back)',
      description: 'Back side of your driving license',
      icon: '🔄',
    ),
    DocumentType.vehicleRegistration: DocumentInfo(
      type: DocumentType.vehicleRegistration,
      title: 'Vehicle Registration',
      description: 'Vehicle registration certificate',
      icon: '📋',
    ),
    DocumentType.insuranceCertificate: DocumentInfo(
      type: DocumentType.insuranceCertificate,
      title: 'Insurance Certificate',
      description: 'Valid vehicle insurance certificate',
      icon: '🛡️',
    ),
    DocumentType.driverPhoto: DocumentInfo(
      type: DocumentType.driverPhoto,
      title: 'Driver Photo',
      description: 'Clear photo of yourself',
      icon: '👤',
    ),
    DocumentType.vehiclePhoto: DocumentInfo(
      type: DocumentType.vehiclePhoto,
      title: 'Vehicle Photo',
      description: 'Photo of your vehicle',
      icon: '🚗',
    ),
  };

  List<DocumentInfo> get documents => _documents.values.toList();

  DocumentInfo getDocumentInfo(DocumentType type) {
    return _documents[type]!;
  }

  /// Initialize Genius Scan SDK
  Future<void> initializeGeniusScan({String? licenseKey}) async {
    debugPrint('🚀 Initializing Genius Scan SDK...');
    final success = await GeniusScanDocumentService.initialize(licenseKey: licenseKey);
    if (success) {
      debugPrint('✅ Genius Scan SDK ready for professional document scanning');
    } else {
      debugPrint('❌ Failed to initialize Genius Scan SDK');
    }
  }

  /// Scan document using professional Genius Scan
  Future<void> scanDocumentWithGeniusScan({
    required BuildContext context,
    required DocumentType documentType,
  }) async {
    try {
      _setLoading(true);
      _setProcessingDocument(true);
      _currentProcessingDocument = documentType;
      _clearError();
      
      debugPrint('🔍 Starting professional scan for: ${documentType.name}');

      // Use Genius Scan for professional document scanning
      final result = await GeniusScanDocumentService.scanDocument(
        documentType: documentType,
      );

      if (result == null) {
        debugPrint('❌ Genius Scan cancelled by user');
        return;
      }

      if (!result.success) {
        _setError(result.errorMessage ?? 'Scanning failed');
        return;
      }

      if (result.scannedImages.isEmpty) {
        _setError('No images were scanned');
        return;
      }

      // Extract data from OCR if available
      if (result.ocrText.isNotEmpty) {
        _extractedData = GeniusScanDocumentService.extractDataFromOCR(
          result.ocrText,
          documentType,
        );
        debugPrint('📋 Genius Scan extracted ${_extractedData.length} fields');
      }

      // Upload the high-quality scanned image
      final success = await uploadDocument(
        documentType: documentType,
        imageFile: result.scannedImages.first,
        extractedData: _extractedData,
        confidence: result.confidence,
      );

      if (success) {
        debugPrint('✅ Professional document scan and upload successful');
      }

    } catch (e) {
      _setError('Professional scanning error: $e');
      debugPrint('❌ Genius Scan error: $e');
    } finally {
      _setLoading(false);
      _setProcessingDocument(false);
      _currentProcessingDocument = null;
    }
  }

  /// Upload document to backend
  Future<bool> uploadDocument({
    required DocumentType documentType,
    required File imageFile,
    Map<String, String>? extractedData,
    double? confidence,
  }) async {
    try {
      _setLoading(true);
      _clearError();
      
      debugPrint('📤 Uploading professional scanned document: ${documentType.name}');

      final fileName = path.basename(imageFile.path);
      final mimeType = lookupMimeType(imageFile.path) ?? 'image/jpeg';
      
      final formData = FormData.fromMap({
        'documentType': documentType.name,
        'file': await MultipartFile.fromFile(
          imageFile.path,
          filename: fileName,
          contentType: DioMediaType.parse(mimeType),
        ),
        'extractedData': extractedData != null && extractedData.isNotEmpty 
            ? jsonEncode(extractedData)
            : '',
        'geniusScanConfidence': confidence?.toString() ?? '0.95',
        'scanMethod': 'genius_scan_professional',
      });

      final response = await _apiService.uploadDocument(formData);
      
      if (response['success']) {
        _documents[documentType] = _documents[documentType]!.copyWith(
          status: DocumentStatus.underReview,
          filePath: response['filePath'],
          uploadedAt: DateTime.now(),
        );
        
        debugPrint('✅ Professional document uploaded successfully: ${documentType.name}');
        
        if (extractedData != null && extractedData.isNotEmpty) {
          debugPrint('📋 Professional OCR data included: ${extractedData.keys.join(", ")}');
        }
        
        notifyListeners();
        return true;
      } else {
        _documents[documentType] = _documents[documentType]!.copyWith(
          status: DocumentStatus.notUploaded,
          filePath: null,
          uploadedAt: null,
        );
        _setError(response['error'] ?? 'Upload failed');
        return false;
      }
    } catch (e) {
      _documents[documentType] = _documents[documentType]!.copyWith(
        status: DocumentStatus.notUploaded,
        filePath: null,
        uploadedAt: null,
      );
      _setError('Failed to upload document: $e');
      debugPrint('❌ Document upload error: $e');
      return false;
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  /// Pick image from camera or gallery (fallback option)
  Future<File?> pickImage({required ImageSource source}) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        return File(pickedFile.path);
      }
      return null;
    } catch (e) {
      _setError('Failed to pick image: $e');
      debugPrint('❌ Image picker error: $e');
      return null;
    }
  }

  /// Load document status from backend
  Future<void> loadDocumentStatus() async {
    try {
      _setLoading(true);
      _clearError();

      // Load individual document statuses
      final documentsResponse = await _apiService.getDocuments();
      if (documentsResponse['success']) {
        final documents = documentsResponse['documents'] as List;
        
        for (final doc in documents) {
          final typeString = doc['document_type'] as String;
          final documentType = _parseDocumentType(typeString);
          
          if (documentType != null) {
            _documents[documentType] = _documents[documentType]!.copyWith(
              status: _parseDocumentStatus(doc['status']),
              filePath: doc['file_path'],
              uploadedAt: doc['uploaded_at'] != null 
                  ? DateTime.parse(doc['uploaded_at'])
                  : null,
              rejectionReason: doc['rejection_reason'],
            );
          }
        }
      } else {
        debugPrint('ℹ️ No documents found yet: ${documentsResponse['error']}');
      }

      // Load overall verification status
      final verificationResponse = await _apiService.getVerificationStatus();
      if (verificationResponse['success']) {
        _overallVerificationStatus = verificationResponse['status'] ?? 'pending';
        _isFullyVerified = verificationResponse['isFullyVerified'] ?? false;
        _approvedCount = verificationResponse['approvedCount'] ?? 0;
        _totalRequired = verificationResponse['totalRequired'] ?? 6;
      } else {
        debugPrint('ℹ️ No verification status found yet: ${verificationResponse['error']}');
        _overallVerificationStatus = 'pending';
        _isFullyVerified = false;
        _approvedCount = 0;
        _totalRequired = 6;
      }

      notifyListeners();
    } catch (e) {
      _setError('Failed to load document status: $e');
      debugPrint('❌ Load document status error: $e');
    } finally {
      _setLoading(false);
    }
  }

  DocumentType? _parseDocumentType(String typeString) {
    switch (typeString) {
      case 'drivingLicenseFront':
        return DocumentType.drivingLicenseFront;
      case 'drivingLicenseBack':
        return DocumentType.drivingLicenseBack;
      case 'vehicleRegistration':
        return DocumentType.vehicleRegistration;
      case 'insuranceCertificate':
        return DocumentType.insuranceCertificate;
      case 'driverPhoto':
        return DocumentType.driverPhoto;
      case 'vehiclePhoto':
        return DocumentType.vehiclePhoto;
      default:
        return null;
    }
  }

  DocumentStatus _parseDocumentStatus(String? status) {
    switch (status) {
      case 'under_review':
        return DocumentStatus.underReview;
      case 'approved':
        return DocumentStatus.approved;
      case 'rejected':
        return DocumentStatus.rejected;
      default:
        return DocumentStatus.notUploaded;
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setProcessingDocument(bool processing) {
    _isProcessingDocument = processing;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }
}
