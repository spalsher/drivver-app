import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data'; // Added for Uint8List
import 'package:flutter/material.dart';
import 'package:flutter/animation.dart';
import 'package:camera/camera.dart';
import 'package:drivrr_driver/src/core/services/document_processing_service.dart';
import 'package:drivrr_driver/src/core/services/smart_id_scanner_service.dart';
import 'package:path_provider/path_provider.dart'; // Added for getTemporaryDirectory
import 'package:path/path.dart' as p; // Alias to avoid name clash with BuildContext

/// An intelligent document scanner that uses a native, high-performance
/// library for edge detection, quality analysis, and auto-capture.
class SmartDocumentScanner extends StatefulWidget {
  final String documentType;
  final Function(File imageFile, Map<String, dynamic> extractedData) onDocumentScanned;

  const SmartDocumentScanner({
    super.key,
    required this.documentType,
    required this.onDocumentScanned,
  });

  @override
  State<SmartDocumentScanner> createState() => _SmartDocumentScannerState();
}

enum DocumentState { none, detecting, ready, processing }

class _SmartDocumentScannerState extends State<SmartDocumentScanner>
    with TickerProviderStateMixin {
  final _processingService = DocumentProcessingService();
  final _nativeScanner = SmartIdScannerService();

  // Camera controller
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;

  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _progressController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _progressAnimation;

  DocumentState _documentState = DocumentState.none;
  Timer? _detectionTimer;
  Timer? _autoScanTimer;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _initializeAnimations();
    _startDocumentDetection();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _pulseController.dispose();
    _progressController.dispose();
    _detectionTimer?.cancel();
    _autoScanTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras!.isNotEmpty) {
        _cameraController = CameraController(
          _cameras![0], // Use back camera
          ResolutionPreset.high,
          enableAudio: false,
        );

        await _cameraController!.initialize();
        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
          });
        }
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  void _initializeAnimations() {
    // Pulse animation for "Ready" state
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.3,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    // Progress animation for processing state
    _progressController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    ));
  }

  void _startDocumentDetection() {
    setState(() {
      _documentState = DocumentState.detecting;
    });

    _detectionTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted && _documentState == DocumentState.detecting && _isCameraInitialized) {
        setState(() {
          _documentState = DocumentState.ready;
          _pulseController.forward();
        });
        
        // Start auto-scan timer when ready
        _autoScanTimer = Timer(const Duration(seconds: 5), () {
          if (mounted && _documentState == DocumentState.ready) {
            _scanDocument();
          }
        });
      }
    });
  }

  Future<void> _scanDocument() async {
    if (_documentState == DocumentState.processing || _cameraController == null) return;

    setState(() {
      _documentState = DocumentState.processing;
      _progressController.forward();
    });

    try {
      // Take picture with camera
      final XFile imageFile = await _cameraController!.takePicture();
      final File file = File(imageFile.path);

      // Process with our document processing service
      final processingResult = await _processingService.processImage(file);

      if (!mounted) return;

      // Check if extraction quality is good enough
      if (processingResult.validationResult?.needsRetry == true) {
        // Show dialog asking user to rescan for better quality
        if (mounted) {
          await _showRetryDialog();
          setState(() {
            _documentState = DocumentState.ready;
            _progressController.stop();
          });
          return;
        }
      }

      // Extraction is good, proceed
      _progressController.stop();
      widget.onDocumentScanned(processingResult.imageFile, processingResult.extractedData);
    } catch (e) {
      debugPrint('Camera scan error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scan failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _documentState = DocumentState.ready;
          _progressController.stop();
        });
      }
    }
  }

  Future<void> _showRetryDialog() async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Better Quality Needed'),
          ],
        ),
        content: const Text(
          'The document scan could be clearer. Please rescan for better extraction accuracy.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continue Anyway'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _scanDocument(); // Retry scan
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
            ),
            child: const Text('Rescan'),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Scan ${widget.documentType}'),
        actions: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _documentState == DocumentState.ready ? _pulseAnimation.value : 1.0,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _documentState == DocumentState.ready
                        ? Colors.green.withOpacity(0.3)
                        : Colors.transparent,
                    border: Border.all(
                      color: _documentState == DocumentState.ready
                          ? Colors.green
                          : Colors.white,
                      width: 2,
                    ),
                  ),
                  child: IconButton(
                    icon: Icon(
                      _documentState == DocumentState.processing
                          ? Icons.hourglass_empty
                          : Icons.camera_alt,
                      color: _documentState == DocumentState.ready
                          ? Colors.green
                          : Colors.white,
                    ),
                    onPressed: _scanDocument,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Real camera preview
          if (_isCameraInitialized && _cameraController != null)
            Positioned.fill(
              child: CameraPreview(_cameraController!),
            )
          else
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
                ),
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Initializing Camera...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),

          // Document detection overlay with correct ID card proportions (3.5" x 2.5")
          Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: _getDetectionAreaWidth(),
              height: _getDetectionAreaHeight(),
              decoration: BoxDecoration(
                border: Border.all(
                  color: _getBorderColor(),
                  width: _getBorderWidth(),
                  style: BorderStyle.solid,
                ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: _documentState == DocumentState.ready
                    ? [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.5),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ]
                    : null,
              ),
              child: _buildDetectionContent(),
            ),
          ),

          // Status indicator at top
          Positioned(
            top: 100,
            left: 0,
            right: 0,
            child: Center(
              child: _buildStatusIndicator(),
            ),
          ),

          // Processing overlay
          if (_documentState == DocumentState.processing)
            AnimatedBuilder(
              animation: _progressAnimation,
              builder: (context, child) {
                return Container(
                  color: Colors.black.withOpacity(0.7),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Futuristic progress animation
                        SizedBox(
                          width: 80,
                          height: 40,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: List.generate(3, (index) {
                              return AnimatedBuilder(
                                animation: _progressAnimation,
                                builder: (context, child) {
                                  double delay = index * 0.2;
                                  double opacity = (sin((_progressAnimation.value + delay) * 2 * pi) + 1) / 2;
                                  return Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white.withOpacity(opacity),
                                    ),
                                  );
                                },
                              );
                            }),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Processing Document...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Extracting data with AI',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ID card dimensions: 3.5" x 2.5" (aspect ratio 1.4:1)
  double _getDetectionAreaWidth() {
    double screenWidth = MediaQuery.of(context).size.width;
    double maxWidth = screenWidth * 0.8; // Max 80% of screen width
    
    double baseWidth = 280; // Base width that works well on most phones
    if (baseWidth > maxWidth) baseWidth = maxWidth;
    
    switch (_documentState) {
      case DocumentState.detecting:
        return baseWidth;
      case DocumentState.ready:
        return baseWidth + 20;
      case DocumentState.processing:
        return baseWidth + 40;
      default:
        return baseWidth - 20;
    }
  }

  double _getDetectionAreaHeight() {
    // ID card aspect ratio: 3.5" width to 2.5" height = 1.4:1
    // So height = width / 1.4
    return _getDetectionAreaWidth() / 1.4;
  }

  Color _getBorderColor() {
    switch (_documentState) {
      case DocumentState.detecting:
        return Colors.blue;
      case DocumentState.ready:
        return Colors.green;
      case DocumentState.processing:
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  double _getBorderWidth() {
    switch (_documentState) {
      case DocumentState.detecting:
        return 2;
      case DocumentState.ready:
        return 3;
      case DocumentState.processing:
        return 4;
      default:
        return 1;
    }
  }

  Widget _buildDetectionContent() {
    switch (_documentState) {
      case DocumentState.detecting:
        return Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.document_scanner,
                  size: 40,
                  color: Colors.blue,
                ),
                SizedBox(height: 8),
                Text(
                  'Position ID Card',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      case DocumentState.ready:
        return Container(
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle,
                  size: 40,
                  color: Colors.green,
                ),
                SizedBox(height: 8),
                Text(
                  'Ready to Scan!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      case DocumentState.processing:
        return Container(
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Scanning...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStatusIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _getStatusColor().withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getStatusIcon(),
            size: 16,
            color: Colors.white,
          ),
          const SizedBox(width: 8),
          Text(
            _getStatusText(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor() {
    switch (_documentState) {
      case DocumentState.detecting:
        return Colors.blue;
      case DocumentState.ready:
        return Colors.green;
      case DocumentState.processing:
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon() {
    switch (_documentState) {
      case DocumentState.detecting:
        return Icons.search;
      case DocumentState.ready:
        return Icons.check_circle;
      case DocumentState.processing:
        return Icons.sync;
      default:
        return Icons.help;
    }
  }

  String _getStatusText() {
    switch (_documentState) {
      case DocumentState.detecting:
        return 'DETECTING DOCUMENT';
      case DocumentState.ready:
        return 'READY TO SCAN';
      case DocumentState.processing:
        return 'PROCESSING...';
      default:
        return 'WAITING';
    }
  }
}