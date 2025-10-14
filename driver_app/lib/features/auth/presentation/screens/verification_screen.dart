import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/services/document_verification_service.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../document_verification/widgets/professional_document_widgets.dart';

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> 
    with TickerProviderStateMixin {
  late DocumentVerificationService _verificationService;
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _verificationService = DocumentVerificationService();
    
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    ));
    
    _initializeVerification();
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  Future<void> _initializeVerification() async {
    await _verificationService.initialize();
    setState(() {
      _isInitialized = true;
    });
    _updateProgressAnimation();
  }

  void _updateProgressAnimation() {
    final progress = _verificationService.approvedDocumentsCount / 
                    _verificationService.totalDocumentsCount;
    _progressController.animateTo(progress);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        body: const Center(
          child: CircularProgressIndicator(
            color: Color(AppConstants.primaryColorValue),
          ),
        ),
      );
    }

    return ChangeNotifierProvider.value(
      value: _verificationService,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          title: const Text(
            'Document Verification',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          backgroundColor: const Color(AppConstants.primaryColorValue),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => context.pop(),
          ),
        ),
        body: Consumer<DocumentVerificationService>(
          builder: (context, service, child) {
            return Column(
              children: [
                _buildProgressHeader(service),
                Expanded(
                  child: _buildDocumentsList(service),
                ),
                _buildBottomActions(service),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildProgressHeader(DocumentVerificationService service) {
    final approvedCount = service.approvedDocumentsCount;
    final totalCount = service.totalDocumentsCount;
    final isComplete = service.isAllDocumentsApproved;
    
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: const BoxDecoration(
        color: Color(AppConstants.primaryColorValue),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          // Progress Circle
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              children: [
                Center(
                  child: SizedBox(
                    width: 100,
                    height: 100,
                    child: AnimatedBuilder(
                      animation: _progressAnimation,
                      builder: (context, child) {
                        return CircularProgressIndicator(
                          value: _progressAnimation.value,
                          strokeWidth: 8,
                          backgroundColor: Colors.white.withOpacity(0.3),
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        );
                      },
                    ),
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$approvedCount/$totalCount',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const Text(
                        'Approved',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Status Text
          Text(
            isComplete 
                ? '🎉 Verification Complete!'
                : service.hasRejectedDocuments
                    ? '⚠️ Some documents need attention'
                    : '📋 Upload your documents',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            isComplete
                ? 'You can now start accepting ride requests'
                : 'Please upload all required documents to get verified',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsList(DocumentVerificationService service) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // Country Selector
        const CountrySelector(),
        
        // ML Kit Processing Indicator
        const DocumentProcessingIndicator(),
        
        // Extracted Data Widget
        if (service.extractedData.isNotEmpty && service.currentProcessingDocument != null)
          ExtractedDataWidget(
            extractedData: service.extractedData,
            documentType: service.currentProcessingDocument!,
          ),
        
        // Document Cards
        ...service.documents.map((document) => 
          _buildDocumentCard(document, service)
        ).toList(),
      ],
    );
  }

  Widget _buildDocumentCard(DocumentInfo document, DocumentVerificationService service) {
    final statusColor = _getStatusColor(document.status);
    final statusIcon = _getStatusIcon(document.status);
    final statusText = _getStatusText(document.status);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                // Document Icon
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      document.icon,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                
                // Document Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        document.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        document.description,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // ML Kit hint
                      Row(
                        children: [
                          Icon(
                            Icons.smart_toy,
                            size: 12,
                            color: Colors.blue.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'AI-powered validation & auto-fill',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.blue.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 16, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            // Rejection Reason (if any)
            if (document.status == DocumentStatus.rejected && document.rejectionReason != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Rejection reason: ${document.rejectionReason}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            // Upload Dates
            if (document.uploadedAt != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.access_time, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'Uploaded: ${_formatDate(document.uploadedAt!)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                    ),
                  ),
                  if (document.reviewedAt != null) ...[
                    const SizedBox(width: 16),
                    const Icon(Icons.verified, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      'Reviewed: ${_formatDate(document.reviewedAt!)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ],
              ),
            ],
            
            // Action Buttons
            const SizedBox(height: 16),
            Row(
              children: [
                if (document.status == DocumentStatus.notUploaded || 
                    document.status == DocumentStatus.rejected) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: service.isLoading 
                          ? null 
                          : () => _showUploadOptions(document.type, service),
                      icon: const Icon(Icons.upload_file, size: 18),
                      label: Text(
                        document.status == DocumentStatus.rejected ? 'Re-upload' : 'Upload',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(AppConstants.primaryColorValue),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ] else if (document.status == DocumentStatus.uploaded || 
                          document.status == DocumentStatus.underReview) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: service.isLoading 
                          ? null 
                          : () => _showDeleteConfirmation(document.type, service),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Remove'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: service.isLoading 
                          ? null 
                          : () => _showUploadOptions(document.type, service),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Replace'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ] else if (document.status == DocumentStatus.approved) ...[
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.withOpacity(0.3)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle, color: Colors.green, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Verified',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActions(DocumentVerificationService service) {
    if (service.isAllDocumentsApproved) {
      return Container(
        padding: const EdgeInsets.all(20.0),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => context.go('/home'),
            icon: const Icon(Icons.check_circle, size: 20),
            label: const Text(
              'Start Driving',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          if (service.errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      service.errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: service.isLoading ? null : () => context.go('/home'),
                  icon: const Icon(Icons.home, size: 18),
                  label: const Text('Skip for Now'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[600],
                    side: BorderSide(color: Colors.grey[300]!),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: service.isLoading 
                      ? null 
                      : () => _refreshVerificationStatus(service),
                  icon: service.isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.refresh, size: 18),
                  label: const Text('Refresh Status'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(AppConstants.primaryColorValue),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showUploadOptions(DocumentType documentType, DocumentVerificationService service) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Upload ${service.getDocument(documentType).title}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              service.getDocument(documentType).description,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildUploadOption(
                    icon: Icons.camera_enhance,
                    title: 'Smart Camera',
                    subtitle: 'AI-guided capture',
                    onTap: () {
                      Navigator.pop(context);
                      _captureWithSmartCamera(documentType, service);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildUploadOption(
                    icon: Icons.photo_library,
                    title: 'Gallery',
                    subtitle: 'Choose from photos',
                    onTap: () {
                      Navigator.pop(context);
                      _uploadDocument(documentType, ImageSource.gallery, service);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: const Color(AppConstants.primaryColorValue)),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(DocumentType documentType, DocumentVerificationService service) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Document'),
        content: Text(
          'Are you sure you want to remove your ${service.getDocument(documentType).title}? '
          'You will need to upload it again for verification.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteDocument(documentType, service);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadDocument(
    DocumentType documentType, 
    ImageSource source, 
    DocumentVerificationService service,
  ) async {
    final success = await service.uploadDocumentFlow(
      context: context,
      documentType: documentType,
    );

    if (success) {
      _updateProgressAnimation();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${service.getDocument(documentType).title} uploaded successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else if (service.errorMessage != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(service.errorMessage!),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _captureWithSmartCamera(
    DocumentType documentType,
    DocumentVerificationService service,
  ) async {
    await service.captureDocumentWithSmartCamera(
      context: context,
      documentType: documentType,
    );
    
    // Only update animation if the widget is still mounted and not disposed
    if (mounted && _progressController.isAnimating != null) {
      _updateProgressAnimation();
    }
  }

  Future<void> _deleteDocument(
    DocumentType documentType, 
    DocumentVerificationService service,
  ) async {
    final success = await service.deleteDocument(documentType);

    if (success) {
      _updateProgressAnimation();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${service.getDocument(documentType).title} removed successfully'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else if (service.errorMessage != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(service.errorMessage!),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _refreshVerificationStatus(DocumentVerificationService service) async {
    await service.loadDocumentStatus();
    _updateProgressAnimation();
  }

  // Helper methods for status display
  Color _getStatusColor(DocumentStatus status) {
    switch (status) {
      case DocumentStatus.notUploaded:
        return Colors.grey;
      case DocumentStatus.uploading:
        return Colors.blue;
      case DocumentStatus.uploaded:
        return Colors.blue;
      case DocumentStatus.underReview:
        return Colors.orange;
      case DocumentStatus.approved:
        return Colors.green;
      case DocumentStatus.rejected:
        return Colors.red;
    }
  }

  IconData _getStatusIcon(DocumentStatus status) {
    switch (status) {
      case DocumentStatus.notUploaded:
        return Icons.upload_file;
      case DocumentStatus.uploading:
        return Icons.cloud_upload;
      case DocumentStatus.uploaded:
        return Icons.cloud_upload;
      case DocumentStatus.underReview:
        return Icons.hourglass_empty;
      case DocumentStatus.approved:
        return Icons.check_circle;
      case DocumentStatus.rejected:
        return Icons.cancel;
    }
  }

  String _getStatusText(DocumentStatus status) {
    switch (status) {
      case DocumentStatus.notUploaded:
        return 'Not Uploaded';
      case DocumentStatus.uploading:
        return 'Uploading...';
      case DocumentStatus.uploaded:
        return 'Uploaded';
      case DocumentStatus.underReview:
        return 'Under Review';
      case DocumentStatus.approved:
        return 'Approved';
      case DocumentStatus.rejected:
        return 'Rejected';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}