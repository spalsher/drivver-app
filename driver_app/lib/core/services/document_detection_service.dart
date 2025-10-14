import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:camera/camera.dart';

/// Document Detection and Auto-Cropping Service
class DocumentDetectionService {
  
  /// Detect document in camera image and return cropped result
  static Future<DocumentDetectionResult> detectAndCropDocument({
    required File imageFile,
    required DocumentType documentType,
  }) async {
    try {
      debugPrint('🔍 Starting document detection and cropping...');
      
      // Load and decode image
      final bytes = await imageFile.readAsBytes();
      img.Image? originalImage = img.decodeImage(bytes);
      
      if (originalImage == null) {
        return DocumentDetectionResult(
          success: false,
          errorMessage: 'Failed to decode image',
        );
      }

      debugPrint('📐 Original image size: ${originalImage.width}x${originalImage.height}');

      // Step 1: Preprocessing for detection (use grayscale copy)
      final grayscaleImage = _preprocessImage(originalImage);
      
      // Step 2: Edge Detection on grayscale
      final edges = _detectEdges(grayscaleImage);
      
      // Step 3: Find Document Contours
      final documentBounds = _findDocumentContours(edges, originalImage.width, originalImage.height);
      
      if (documentBounds == null) {
        debugPrint('❌ No document detected, returning original COLOR image');
        // Return original COLOR image if no document detected
        return DocumentDetectionResult(
          success: true,
          croppedImage: originalImage, // Keep original colors
          confidence: 0.3,
          bounds: null,
        );
      }

      debugPrint('✅ Document detected with bounds: $documentBounds');

      // Step 4: Perspective Correction and Cropping (use ORIGINAL color image)
      final croppedImage = _cropAndCorrectPerspective(originalImage, documentBounds);
      
      // Step 5: Post-processing for better quality (preserve colors)
      final enhancedImage = _enhanceImage(croppedImage);

      debugPrint('🎯 Final cropped size: ${enhancedImage.width}x${enhancedImage.height}');

      return DocumentDetectionResult(
        success: true,
        croppedImage: enhancedImage,
        confidence: _calculateConfidence(documentBounds, originalImage.width, originalImage.height),
        bounds: documentBounds,
      );

    } catch (e) {
      debugPrint('❌ Document detection error: $e');
      return DocumentDetectionResult(
        success: false,
        errorMessage: 'Detection failed: $e',
      );
    }
  }

  /// Analyze camera frame for real-time driver's license detection
  static DocumentFrameAnalysis analyzeCameraFrame(CameraImage cameraImage) {
    try {
      // Convert CameraImage to a format we can process
      final width = cameraImage.width;
      final height = cameraImage.height;
      
      // Driver's License specific detection
      final hasLicense = _detectDriversLicense(width, height);
      
      if (hasLicense) {
        // Driver's license standard dimensions (3.375" x 2.125" = 1.59:1 ratio)
        final centerX = width / 2;
        final centerY = height / 2;
        final licenseWidth = width * 0.75; // 75% of frame width
        final licenseHeight = licenseWidth / 1.59; // Standard license aspect ratio
        
        // Ensure it fits in frame
        final adjustedHeight = licenseHeight > height * 0.8 ? height * 0.8 : licenseHeight;
        final adjustedWidth = adjustedHeight * 1.59;
        
        final bounds = Rect.fromCenter(
          center: Offset(centerX, centerY),
          width: adjustedWidth,
          height: adjustedHeight,
        );

        return DocumentFrameAnalysis(
          documentDetected: true,
          confidence: 0.85,
          bounds: bounds,
          quality: DocumentQuality.good,
        );
      }

      return DocumentFrameAnalysis(
        documentDetected: false,
        confidence: 0.0,
        bounds: null,
        quality: DocumentQuality.poor,
      );

    } catch (e) {
      debugPrint('❌ Driver\'s license detection error: $e');
      return DocumentFrameAnalysis(
        documentDetected: false,
        confidence: 0.0,
        bounds: null,
        quality: DocumentQuality.poor,
      );
    }
  }

  /// Preprocess image for better edge detection
  static img.Image _preprocessImage(img.Image image) {
    // Convert to grayscale
    var processed = img.grayscale(image);
    
    // Apply Gaussian blur to reduce noise
    processed = img.gaussianBlur(processed, radius: 1);
    
    // Enhance contrast
    processed = img.adjustColor(processed, contrast: 1.2);
    
    return processed;
  }

  /// Detect edges using Sobel operator (simplified)
  static img.Image _detectEdges(img.Image image) {
    final width = image.width;
    final height = image.height;
    final edgeImage = img.Image(width: width, height: height);

    // Simplified edge detection
    for (int y = 1; y < height - 1; y++) {
      for (int x = 1; x < width - 1; x++) {
        // Get surrounding pixels
        final tl = img.getLuminance(image.getPixel(x - 1, y - 1));
        final tm = img.getLuminance(image.getPixel(x, y - 1));
        final tr = img.getLuminance(image.getPixel(x + 1, y - 1));
        final ml = img.getLuminance(image.getPixel(x - 1, y));
        final mr = img.getLuminance(image.getPixel(x + 1, y));
        final bl = img.getLuminance(image.getPixel(x - 1, y + 1));
        final bm = img.getLuminance(image.getPixel(x, y + 1));
        final br = img.getLuminance(image.getPixel(x + 1, y + 1));

        // Sobel X and Y
        final sobelX = (tr + 2 * mr + br) - (tl + 2 * ml + bl);
        final sobelY = (bl + 2 * bm + br) - (tl + 2 * tm + tr);
        
        // Magnitude
        final magnitude = sqrt(sobelX * sobelX + sobelY * sobelY);
        final intensity = (magnitude.clamp(0, 255)).toInt();
        
        edgeImage.setPixel(x, y, img.ColorRgb8(intensity, intensity, intensity));
      }
    }

    return edgeImage;
  }

  /// Find driver's license contours in edge image
  static Rect? _findDocumentContours(img.Image edges, int originalWidth, int originalHeight) {
    // Driver's License specific contour detection
    final width = edges.width;
    final height = edges.height;
    
    // Find rectangular regions that match driver's license characteristics
    int bestScore = 0;
    Rect? bestRect;
    
    // Driver's license aspect ratios (different countries/states)
    final licenseAspectRatios = [
      1.59, // Standard US (3.375" x 2.125")
      1.60, // Some variations
      1.58, // Pakistan/International variations
      1.55, // Older formats
    ];
    
    // Sample different rectangular regions looking for license-like shapes
    for (double scale = 0.5; scale <= 0.85; scale += 0.05) {
      for (final aspectRatio in licenseAspectRatios) {
        final rectWidth = width * scale;
        final rectHeight = rectWidth / aspectRatio;
        
        if (rectHeight > height * 0.9) continue;
        
        final left = (width - rectWidth) / 2;
        final top = (height - rectHeight) / 2;
        
        final rect = Rect.fromLTWH(left, top, rectWidth, rectHeight);
        final score = _calculateLicenseScore(edges, rect);
        
        if (score > bestScore) {
          bestScore = score;
          bestRect = rect;
        }
      }
    }
    
    // Higher threshold for license detection (more strict)
    if (bestScore > width * height * 0.03) { // Increased threshold
      debugPrint('🪪 Driver\'s license detected! Score: $bestScore');
      return bestRect;
    }
    
    debugPrint('❌ No driver\'s license pattern found. Score: $bestScore');
    return null;
  }

  /// Calculate score for driver's license based on specific characteristics
  static int _calculateLicenseScore(img.Image edges, Rect rect) {
    int score = 0;
    final left = rect.left.toInt();
    final top = rect.top.toInt();
    final right = rect.right.toInt();
    final bottom = rect.bottom.toInt();
    
    // Check edge density in different regions of the license
    // Driver's licenses typically have:
    // 1. Strong edges around the border
    // 2. Text areas with consistent spacing
    // 3. Photo area (usually left side)
    
    // Border edge detection (stronger weight)
    score += _checkBorderEdges(edges, rect) * 3;
    
    // Text area detection (right side typically has more text)
    score += _checkTextAreas(edges, rect) * 2;
    
    // Overall edge density
    for (int y = top; y < bottom && y < edges.height; y += 2) {
      for (int x = left; x < right && x < edges.width; x += 2) {
        final pixel = edges.getPixel(x, y);
        final intensity = img.getLuminance(pixel);
        if (intensity > 120) { // Edge threshold for license detection
          score++;
        }
      }
    }
    
    return score;
  }

  /// Check for strong border edges typical of driver's licenses
  static int _checkBorderEdges(img.Image edges, Rect rect) {
    int borderScore = 0;
    final left = rect.left.toInt();
    final top = rect.top.toInt();
    final right = rect.right.toInt();
    final bottom = rect.bottom.toInt();
    
    // Check top and bottom borders
    for (int x = left; x < right && x < edges.width; x += 3) {
      // Top border
      if (top < edges.height) {
        final topPixel = edges.getPixel(x, top);
        if (img.getLuminance(topPixel) > 150) borderScore++;
      }
      
      // Bottom border
      if (bottom - 1 < edges.height) {
        final bottomPixel = edges.getPixel(x, bottom - 1);
        if (img.getLuminance(bottomPixel) > 150) borderScore++;
      }
    }
    
    // Check left and right borders
    for (int y = top; y < bottom && y < edges.height; y += 3) {
      // Left border
      if (left < edges.width) {
        final leftPixel = edges.getPixel(left, y);
        if (img.getLuminance(leftPixel) > 150) borderScore++;
      }
      
      // Right border
      if (right - 1 < edges.width) {
        final rightPixel = edges.getPixel(right - 1, y);
        if (img.getLuminance(rightPixel) > 150) borderScore++;
      }
    }
    
    return borderScore;
  }

  /// Check for text areas typical in driver's licenses
  static int _checkTextAreas(img.Image edges, Rect rect) {
    int textScore = 0;
    final width = rect.width.toInt();
    final height = rect.height.toInt();
    
    // Right side of license typically has more text (60-95% of width)
    final textAreaLeft = rect.left + (width * 0.6);
    final textAreaRight = rect.left + (width * 0.95);
    final textAreaTop = rect.top + (height * 0.2);
    final textAreaBottom = rect.top + (height * 0.8);
    
    for (int y = textAreaTop.toInt(); y < textAreaBottom.toInt() && y < edges.height; y += 4) {
      for (int x = textAreaLeft.toInt(); x < textAreaRight.toInt() && x < edges.width; x += 4) {
        final pixel = edges.getPixel(x, y);
        final intensity = img.getLuminance(pixel);
        if (intensity > 100) { // Text typically creates moderate edges
          textScore++;
        }
      }
    }
    
    return textScore;
  }

  /// Driver's License specific detection for camera frames
  static bool _detectDriversLicense(int width, int height) {
    // Simulate driver's license detection based on frame characteristics
    // In reality, you'd analyze the actual YUV camera data for:
    // 1. Rectangular shapes with correct aspect ratio
    // 2. Text patterns typical of licenses
    // 3. Color patterns (blue/red headers, etc.)
    // 4. Holographic elements detection
    
    // For now, use improved random detection with license-specific logic
    final random = Random();
    final aspectRatio = width / height;
    
    // Camera frames that could contain a license (landscape orientation preferred)
    if (aspectRatio > 1.2 && aspectRatio < 2.0) {
      return random.nextDouble() > 0.5; // 50% chance of "detecting" license
    }
    
    return random.nextDouble() > 0.7; // 30% chance for other orientations
  }

  /// Crop and correct perspective
  static img.Image _cropAndCorrectPerspective(img.Image original, Rect bounds) {
    // For now, do a simple crop
    // In a more advanced implementation, you'd do perspective transformation
    
    final left = bounds.left.toInt().clamp(0, original.width - 1);
    final top = bounds.top.toInt().clamp(0, original.height - 1);
    final width = bounds.width.toInt().clamp(1, original.width - left);
    final height = bounds.height.toInt().clamp(1, original.height - top);
    
    return img.copyCrop(original, x: left, y: top, width: width, height: height);
  }

  /// Enhance cropped image quality
  static img.Image _enhanceImage(img.Image image) {
    // Adjust contrast and brightness for better readability
    var enhanced = img.adjustColor(image, 
      contrast: 1.1, 
      brightness: 1.05,
      saturation: 1.1
    );
    
    // Note: img.sharpen is not available in this version of the image package
    // Enhanced image will still have improved contrast and brightness
    
    return enhanced;
  }

  /// Calculate confidence score based on detected bounds
  static double _calculateConfidence(Rect bounds, int imageWidth, int imageHeight) {
    final area = bounds.width * bounds.height;
    final imageArea = imageWidth * imageHeight;
    final areaRatio = area / imageArea;
    
    // Good confidence if document takes 20-70% of image
    if (areaRatio >= 0.2 && areaRatio <= 0.7) {
      return 0.9;
    } else if (areaRatio >= 0.1 && areaRatio <= 0.8) {
      return 0.7;
    } else {
      return 0.5;
    }
  }

  /// Save cropped image to file
  static Future<File> saveCroppedImage(img.Image croppedImage, String originalPath) async {
    final croppedBytes = img.encodeJpg(croppedImage, quality: 95);
    final croppedPath = originalPath.replaceAll('.jpg', '_cropped.jpg');
    final croppedFile = File(croppedPath);
    await croppedFile.writeAsBytes(croppedBytes);
    return croppedFile;
  }
}

/// Result of document detection and cropping
class DocumentDetectionResult {
  final bool success;
  final img.Image? croppedImage;
  final double confidence;
  final Rect? bounds;
  final String? errorMessage;

  DocumentDetectionResult({
    required this.success,
    this.croppedImage,
    this.confidence = 0.0,
    this.bounds,
    this.errorMessage,
  });
}

/// Real-time camera frame analysis result
class DocumentFrameAnalysis {
  final bool documentDetected;
  final double confidence;
  final Rect? bounds;
  final DocumentQuality quality;

  DocumentFrameAnalysis({
    required this.documentDetected,
    required this.confidence,
    this.bounds,
    required this.quality,
  });
}

/// Document quality assessment
enum DocumentQuality {
  poor,
  fair,
  good,
  excellent,
}

/// Document types for aspect ratio calculation
enum DocumentType {
  drivingLicenseFront,
  drivingLicenseBack,
  vehicleRegistration,
  insuranceCertificate,
  driverPhoto,
  vehiclePhoto,
}
