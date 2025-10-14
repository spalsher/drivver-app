import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/document_verification_service.dart';

/// Professional Document Capture Button
class ProfessionalDocumentCaptureButton extends StatelessWidget {
  final DocumentType documentType;
  final VoidCallback? onSuccess;

  const ProfessionalDocumentCaptureButton({
    super.key,
    required this.documentType,
    this.onSuccess,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<DocumentVerificationService>(
      builder: (context, service, child) {
        final document = service.getDocument(documentType);
        final isProcessing = service.isProcessingDocument && 
                           service.currentProcessingDocument == documentType;

        return ElevatedButton.icon(
          onPressed: isProcessing ? null : () async {
            await service.scanDocumentWithGeniusScan(
              context: context,
              documentType: documentType,
            );
            if (service.errorMessage == null) {
              onSuccess?.call();
            }
          },
          icon: isProcessing 
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.document_scanner),
          label: Text(isProcessing 
              ? 'Scanning...' 
              : 'Scan ${document.title}'),
        );
      },
    );
  }
}

/// Professional Document Card
class ProfessionalDocumentCard extends StatelessWidget {
  final DocumentInfo document;
  final VoidCallback? onCapture;

  const ProfessionalDocumentCard({
    super.key,
    required this.document,
    this.onCapture,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getDocumentIcon(document.type),
                  size: 32,
                  color: _getStatusColor(document.status),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        document.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        document.description,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                _buildStatusChip(document.status),
              ],
            ),
            const SizedBox(height: 16),
            ProfessionalDocumentCaptureButton(
              documentType: document.type,
              onSuccess: onCapture,
            ),
          ],
        ),
      ),
    );
  }

  IconData _getDocumentIcon(DocumentType type) {
    switch (type) {
      case DocumentType.drivingLicenseFront:
      case DocumentType.drivingLicenseBack:
        return Icons.credit_card;
      case DocumentType.vehicleRegistration:
        return Icons.directions_car;
      case DocumentType.insuranceCertificate:
        return Icons.security;
      case DocumentType.driverPhoto:
        return Icons.person;
      case DocumentType.vehiclePhoto:
        return Icons.camera_alt;
    }
  }

  Color _getStatusColor(DocumentStatus status) {
    switch (status) {
      case DocumentStatus.approved:
        return Colors.green;
      case DocumentStatus.rejected:
        return Colors.red;
      case DocumentStatus.underReview:
      case DocumentStatus.uploaded:
        return Colors.orange;
      case DocumentStatus.uploading:
        return Colors.blue;
      case DocumentStatus.notUploaded:
        return Colors.grey;
    }
  }

  Widget _buildStatusChip(DocumentStatus status) {
    return Chip(
      label: Text(
        _getStatusText(status),
        style: const TextStyle(fontSize: 12),
      ),
      backgroundColor: _getStatusColor(status).withOpacity(0.1),
      side: BorderSide(color: _getStatusColor(status)),
    );
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
}

/// Country Selector Widget (placeholder)
class CountrySelector extends StatelessWidget {
  const CountrySelector({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.flag),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Country: Pakistan',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    'Document validation optimized for Pakistani documents',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Document Processing Indicator
class DocumentProcessingIndicator extends StatelessWidget {
  const DocumentProcessingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DocumentVerificationService>(
      builder: (context, service, child) {
        if (!service.isProcessingDocument) {
          return const SizedBox.shrink();
        }

        return Card(
          margin: const EdgeInsets.all(16),
          color: Colors.blue.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Processing Document...',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (service.currentProcessingDocument != null)
                        Text(
                          'Scanning ${service.getDocument(service.currentProcessingDocument!).title}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Extracted Data Widget (placeholder)
Widget ExtractedDataWidget({
  required Map<String, String> extractedData,
  required DocumentType documentType,
}) {
  return Card(
    margin: const EdgeInsets.all(16),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Extracted Data',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (extractedData.isEmpty)
            const Text('No data extracted yet')
          else
            ...extractedData.entries.map((entry) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 120,
                    child: Text(
                      '${entry.key}:',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  Expanded(child: Text(entry.value)),
                ],
              ),
            )),
        ],
      ),
    ),
  );
}