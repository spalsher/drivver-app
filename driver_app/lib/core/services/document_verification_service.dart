import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as path;
import 'package:mime/mime.dart';
import 'api_service.dart';
import '../../features/document_verification/widgets/smart_document_scanner.dart';

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
  uploaded,
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
  final DateTime? reviewedAt;
  final String? rejectionReason;

  const DocumentInfo({
    required this.type,
    required this.title,
    required this.description,
    required this.icon,
    this.status = DocumentStatus.notUploaded,
    this.filePath,
    this.uploadedAt,
    this.reviewedAt,
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
    DateTime? reviewedAt,
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
      reviewedAt: reviewedAt ?? this.reviewedAt,
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
  DocumentType? _currentProcessingDocument;
  String? _errorMessage;
  String _overallVerificationStatus = 'pending';
  bool _isFullyVerified = false;
  int _approvedCount = 0;
  int _totalRequired = 6;
  Map<String, String> _extractedData = {};
  
  // Document tracking
  final Map<DocumentType, DocumentStatus> _documentStatuses = {};
  final Map<DocumentType, String> _documentUrls = {};
  final Map<DocumentType, DateTime> _documentUploadDates = {};

  // Getters
  bool get isLoading => _isLoading;
  bool get isProcessingDocument => _isProcessingDocument;
  String? get errorMessage => _errorMessage;
  String get overallVerificationStatus => _overallVerificationStatus;
  bool get isFullyVerified => _isFullyVerified;
  int get approvedCount => _approvedCount;
  int get totalRequired => _totalRequired;
  double get completionPercentage => _totalRequired > 0 ? _approvedCount / _totalRequired : 0.0;
  Map<String, String> get extractedData => _extractedData;
  DocumentType? get currentProcessingDocument => _currentProcessingDocument;

  // Helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setProcessingDocument(bool processing) {
    _isProcessingDocument = processing;
    notifyListeners();
  }

  void _setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }

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

  // Getters for UI compatibility
  int get approvedDocumentsCount => _approvedCount;
  int get totalDocumentsCount => _totalRequired;
  bool get isAllDocumentsApproved => _isFullyVerified;
  bool get hasRejectedDocuments => _documentStatuses.values.any((status) => status == DocumentStatus.rejected);

  /// Get document info by type
  DocumentInfo getDocument(DocumentType type) => getDocumentInfo(type);

  /// Initialize service (for compatibility)
  Future<void> initialize() async {
    debugPrint('🚀 Initializing Document Verification Service...');
    await loadDocumentStatus();
  }

  /// Upload document flow (for compatibility)
  Future<bool> uploadDocumentFlow({
    required BuildContext context,
    required DocumentType documentType,
  }) async {
    await scanDocumentWithGeniusScan(
      context: context,
      documentType: documentType,
    );
    return _errorMessage == null;
  }

  /// Capture with smart camera (for compatibility)
  Future<void> captureDocumentWithSmartCamera({
    required BuildContext context,
    required DocumentType documentType,
  }) async {
    await scanDocumentWithGeniusScan(
      context: context,
      documentType: documentType,
    );
  }

  /// Delete document
  Future<bool> deleteDocument(DocumentType documentType) async {
    try {
      _setLoading(true);
      _clearError();
      
      // TODO: Implement actual deletion API call
      debugPrint('🗑️ Deleting document: ${documentType.name}');
      
      // Simulate deletion
      await Future.delayed(const Duration(seconds: 1));
      
      // Update local state
      _documentStatuses[documentType] = DocumentStatus.notUploaded;
      _documentUrls.remove(documentType);
      _documentUploadDates.remove(documentType);
      
      notifyListeners();
      return true;
      
    } catch (e) {
      _setError('Failed to delete document: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  DocumentInfo getDocumentInfo(DocumentType type) {
    return _documents[type]!;
  }

  /// Enhanced document capture using smart scanner
  Future<void> scanDocumentWithGeniusScan({
    required BuildContext context,
    required DocumentType documentType,
  }) async {
    try {
      _setLoading(true);
      _setProcessingDocument(true);
      _currentProcessingDocument = documentType;
      _clearError();
      
      debugPrint('📸 Starting smart document scanner for: ${documentType.name}');

      // Navigate to smart scanner
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => SmartDocumentScanner(
            documentType: documentType.name,
            onDocumentScanned: (file, extractedData) async {
              // Store extracted data
              _extractedData = extractedData.map((key, value) => MapEntry(key, value.toString()));
              debugPrint('📋 Smart scanner extracted ${_extractedData.length} fields');

              // Upload the document
              final success = await uploadDocument(
                documentType: documentType,
                imageFile: file,
                extractedData: _extractedData,
                confidence: 0.95, // High confidence for smart capture
              );

              if (success) {
                debugPrint('✅ Smart document scan and upload successful');
              }

              // Pop the scanner with result
              Navigator.pop(context, success);
            },
          ),
        ),
      );

      if (result == null) {
        debugPrint('❌ User cancelled smart scanning');
        return;
      }

      if (result) {
        debugPrint('✅ Document processing completed successfully');
      } else {
        _setError('Failed to process document');
      }

    } catch (e) {
      _setError('Smart scanning error: $e');
      debugPrint('❌ Smart scanner error: $e');
    } finally {
      _setLoading(false);
      _setProcessingDocument(false);
      _currentProcessingDocument = null;
    }
  }

  /// Show image source selection dialog
  Future<ImageSource?> _showImageSourceDialog(BuildContext context) async {
    return showDialog<ImageSource>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Image Source'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Simulate OCR extraction for demonstration (public method)
  Map<String, String> simulateOCRExtraction(DocumentType documentType) {
    return _simulateOCRExtraction(documentType);
  }

  /// Simulate OCR extraction for demonstration (private implementation)
  Map<String, String> _simulateOCRExtraction(DocumentType documentType) {
    switch (documentType) {
      case DocumentType.drivingLicenseFront:
        return {
          'licenseNumber': '42301-1083424-9',
          'fullName': 'AAMIR REHMAN LODHI',
          'fatherName': 'NASIR MEHMOOD LODHI',
          'dateOfBirth': '31-AUG-1977',
          'expiryDate': '31-AUG-2027',
          'category': 'M CYCLE, M CAR',
        };
      case DocumentType.drivingLicenseBack:
        return {
          'address': 'HOUSE NO 123, STREET 456, KARACHI',
          'bloodGroup': 'B+',
          'issueDate': '01-SEP-2022',
        };
      case DocumentType.vehicleRegistration:
        return {
          'registrationNumber': 'ABC-123',
          'engineNumber': 'ENG123456',
          'chassisNumber': 'CHS789012',
          'make': 'HONDA',
          'model': 'CIVIC',
          'year': '2020',
        };
      default:
        return {};
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

      // Check if file exists and handle PDF files
      if (!await imageFile.exists()) {
        debugPrint('❌ File does not exist: ${imageFile.path}');
        
        // For PDF files from flutter_doc_scanner, create extracted data only upload
        if (imageFile.path.toLowerCase().endsWith('.pdf')) {
          debugPrint('💡 PDF file detected, uploading extracted data only');
          
          // Create a minimal form data with just extracted data
          final formData = FormData.fromMap({
            'documentType': documentType.name,
            'extractedData': extractedData != null && extractedData.isNotEmpty 
                ? jsonEncode(extractedData)
                : jsonEncode({'note': 'Scanned with Flutter Doc Scanner (PDF format)'}),
            'geniusScanConfidence': confidence?.toString() ?? '0.95',
            'scanMethod': 'flutter_doc_scanner_pdf',
            'fileType': 'pdf_extracted_data',
          });

          final response = await _apiService.uploadDocument(formData);
          
          if (response['success']) {
            _documents[documentType] = _documents[documentType]!.copyWith(
              status: DocumentStatus.underReview,
              filePath: 'pdf_extracted_data',
              uploadedAt: DateTime.now(),
            );
            
            debugPrint('✅ PDF extracted data uploaded successfully: ${documentType.name}');
            
            if (extractedData != null && extractedData.isNotEmpty) {
              debugPrint('📋 PDF OCR data included: ${extractedData.keys.join(", ")}');
            }
            
            notifyListeners();
            return true;
          } else {
            _setError('Failed to upload PDF extracted data: ${response['message']}');
            return false;
          }
        }
        
        _setError('File not found: ${imageFile.path}');
        return false;
      }

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
        'scanMethod': 'hybrid_genius_scan_logic',
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

      // Load individual document statuses (placeholder - implement in API service)
      final documentsResponse = <String, dynamic>{'success': true, 'documents': <Map<String, dynamic>>[]};
      if (documentsResponse['success'] as bool) {
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

      // Load overall verification status (placeholder - implement in API service)
      final verificationResponse = <String, dynamic>{'success': true, 'status': 'pending', 'isFullyVerified': false, 'approvedCount': 0, 'totalRequired': 6};
      if (verificationResponse['success'] as bool) {
        _overallVerificationStatus = verificationResponse['status'] as String? ?? 'pending';
        _isFullyVerified = verificationResponse['isFullyVerified'] as bool? ?? false;
        _approvedCount = verificationResponse['approvedCount'] as int? ?? 0;
        _totalRequired = verificationResponse['totalRequired'] as int? ?? 6;
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
}
