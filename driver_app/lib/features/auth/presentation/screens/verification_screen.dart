import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final Map<String, bool> _documentStatus = {
    'driving_license': false,
    'vehicle_registration': false,
    'insurance_certificate': false,
    'driver_photo': false,
    'vehicle_photo': false,
  };
  
  final Map<String, String> _documentTitles = {
    'driving_license': 'Driving License',
    'vehicle_registration': 'Vehicle Registration',
    'insurance_certificate': 'Insurance Certificate',
    'driver_photo': 'Driver Photo',
    'vehicle_photo': 'Vehicle Photo',
  };
  
  final Map<String, String> _documentDescriptions = {
    'driving_license': 'Valid driving license (front and back)',
    'vehicle_registration': 'Vehicle registration certificate',
    'insurance_certificate': 'Valid vehicle insurance',
    'driver_photo': 'Clear photo of yourself',
    'vehicle_photo': 'Photo of your vehicle',
  };
  
  final Map<String, IconData> _documentIcons = {
    'driving_license': Icons.badge,
    'vehicle_registration': Icons.description,
    'insurance_certificate': Icons.security,
    'driver_photo': Icons.person,
    'vehicle_photo': Icons.directions_car,
  };

  void _uploadDocument(String documentType) {
    // TODO: Implement image picker and upload
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Upload ${_documentTitles[documentType]}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.of(context).pop();
                _simulateUpload(documentType);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.of(context).pop();
                _simulateUpload(documentType);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
  
  void _simulateUpload(String documentType) {
    // Simulate document upload
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Uploading document...'),
          ],
        ),
      ),
    );
    
    Future.delayed(const Duration(seconds: 2), () {
      Navigator.of(context).pop();
      setState(() {
        _documentStatus[documentType] = true;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_documentTitles[documentType]} uploaded successfully'),
          backgroundColor: Colors.green,
        ),
      );
    });
  }

  void _submitForReview() {
    if (_documentStatus.values.every((uploaded) => uploaded)) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Documents Submitted'),
          content: const Text(
            'Your documents have been submitted for review. You\'ll receive a notification within 24-48 hours.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.go('/home');
              },
              child: const Text('Continue'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload all required documents'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final uploadedCount = _documentStatus.values.where((uploaded) => uploaded).length;
    final totalCount = _documentStatus.length;
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Driver Verification'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Progress header
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B5E20).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.verified_user,
                        color: Color(0xFF1B5E20),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Document Verification',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Upload $uploadedCount of $totalCount documents',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    CircularProgressIndicator(
                      value: uploadedCount / totalCount,
                      backgroundColor: Colors.grey[200],
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: uploadedCount / totalCount,
                  backgroundColor: Colors.grey[200],
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
                ),
              ],
            ),
          ),
          
          // Documents list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _documentStatus.length,
              itemBuilder: (context, index) {
                final documentType = _documentStatus.keys.elementAt(index);
                final isUploaded = _documentStatus[documentType]!;
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: isUploaded 
                              ? const Color(0xFF4CAF50).withOpacity(0.1)
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isUploaded ? Icons.check_circle : _documentIcons[documentType],
                          color: isUploaded ? const Color(0xFF4CAF50) : Colors.grey[600],
                          size: 28,
                        ),
                      ),
                      title: Text(
                        _documentTitles[documentType]!,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            _documentDescriptions[documentType]!,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          if (isUploaded) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4CAF50).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Uploaded',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF4CAF50),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      trailing: isUploaded
                          ? const Icon(
                              Icons.check_circle,
                              color: Color(0xFF4CAF50),
                            )
                          : IconButton(
                              onPressed: () => _uploadDocument(documentType),
                              icon: const Icon(Icons.upload),
                              style: IconButton.styleFrom(
                                backgroundColor: const Color(0xFF1B5E20).withOpacity(0.1),
                              ),
                            ),
                      onTap: isUploaded ? null : () => _uploadDocument(documentType),
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Submit button
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: uploadedCount == totalCount ? _submitForReview : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: uploadedCount == totalCount 
                        ? const Color(0xFF1B5E20)
                        : Colors.grey[300],
                  ),
                  child: Text(
                    uploadedCount == totalCount
                        ? 'Submit for Review'
                        : 'Upload all documents ($uploadedCount/$totalCount)',
                    style: TextStyle(
                      color: uploadedCount == totalCount ? Colors.white : Colors.grey[600],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
}
