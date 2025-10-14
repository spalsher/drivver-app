import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Advanced image preprocessing service for optimal OCR results
class AdvancedImageProcessor {
  
  /// Process image for optimal OCR with multiple enhancement techniques
  static Future<File> processForOCR(File originalFile) async {
    try {
      debugPrint('🔧 Starting advanced image processing...');
      
      // Step 1: Load and decode image
      final bytes = await originalFile.readAsBytes();
      final originalImage = img.decodeImage(bytes);
      
      if (originalImage == null) {
        debugPrint('❌ Failed to decode image');
        return originalFile;
      }
      
      debugPrint('📐 Original image: ${originalImage.width}x${originalImage.height}');
      
      // Step 2: Resize for optimal OCR (if too large)
      img.Image processedImage = originalImage;
      if (originalImage.width > 2000 || originalImage.height > 2000) {
        final aspectRatio = originalImage.width / originalImage.height;
        final newWidth = aspectRatio > 1 ? 2000 : (2000 * aspectRatio).round();
        final newHeight = aspectRatio > 1 ? (2000 / aspectRatio).round() : 2000;
        
        processedImage = img.copyResize(
          originalImage,
          width: newWidth,
          height: newHeight,
          interpolation: img.Interpolation.cubic,
        );
        debugPrint('📏 Resized to: ${processedImage.width}x${processedImage.height}');
      }
      
      // Step 3: Convert to grayscale for better text recognition
      processedImage = img.grayscale(processedImage);
      debugPrint('🎨 Converted to grayscale');
      
      // Step 4: Enhance contrast using adaptive histogram equalization
      processedImage = _enhanceContrast(processedImage);
      debugPrint('📈 Enhanced contrast');
      
      // Step 5: Apply noise reduction
      processedImage = _reduceNoise(processedImage);
      debugPrint('🧹 Reduced noise');
      
      // Step 6: Sharpen text
      processedImage = _sharpenText(processedImage);
      debugPrint('🔪 Sharpened text');
      
      // Step 7: Apply morphological operations to clean up text
      processedImage = _morphologicalCleanup(processedImage);
      debugPrint('🧽 Applied morphological cleanup');
      
      // Step 8: Save processed image
      final processedBytes = img.encodeJpg(processedImage, quality: 95);
      final processedFile = File('${originalFile.path}_processed.jpg');
      await processedFile.writeAsBytes(processedBytes);
      
      debugPrint('✅ Advanced processing complete: ${processedFile.path}');
      return processedFile;
      
    } catch (e) {
      debugPrint('❌ Image processing error: $e');
      return originalFile; // Return original if processing fails
    }
  }
  
  /// Enhance contrast using adaptive methods
  static img.Image _enhanceContrast(img.Image image) {
    // Apply CLAHE (Contrast Limited Adaptive Histogram Equalization) simulation
    return img.adjustColor(
      image,
      contrast: 1.3,
      brightness: 1.05,
      gamma: 0.9,
    );
  }
  
  /// Reduce noise while preserving text edges
  static img.Image _reduceNoise(img.Image image) {
    // Apply bilateral filter simulation (blur while preserving edges)
    final blurred = img.gaussianBlur(image, radius: 1);
    
    // Combine original and blurred for edge-preserving noise reduction
    final result = img.Image.from(image);
    
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final original = image.getPixel(x, y);
        final blur = blurred.getPixel(x, y);
        
        // Use original for high-contrast areas (text), blur for low-contrast (noise)
        final luminance = img.getLuminance(original);
        final blurLuminance = img.getLuminance(blur);
        final contrast = (luminance - blurLuminance).abs();
        
        if (contrast > 30) {
          result.setPixel(x, y, original); // Keep sharp text
        } else {
          result.setPixel(x, y, blur); // Reduce noise in smooth areas
        }
      }
    }
    
    return result;
  }
  
  /// Sharpen text for better OCR recognition
  static img.Image _sharpenText(img.Image image) {
    // Unsharp mask filter for text enhancement
    final kernel = [
      0.0, -1.0, 0.0,
      -1.0, 5.0, -1.0,
      0.0, -1.0, 0.0
    ];
    
    return img.convolution(image, filter: kernel);
  }
  
  /// Apply morphological operations to clean up text
  static img.Image _morphologicalCleanup(img.Image image) {
    // Apply closing operation to connect broken text parts
    final structuringElement = [
      [1, 1, 1],
      [1, 1, 1],
      [1, 1, 1]
    ];
    
    // Simulate morphological closing (dilation followed by erosion)
    img.Image dilated = _dilate(image, structuringElement);
    img.Image closed = _erode(dilated, structuringElement);
    
    return closed;
  }
  
  /// Morphological dilation
  static img.Image _dilate(img.Image image, List<List<int>> kernel) {
    final result = img.Image.from(image);
    final kernelSize = kernel.length;
    final offset = kernelSize ~/ 2;
    
    for (int y = offset; y < image.height - offset; y++) {
      for (int x = offset; x < image.width - offset; x++) {
        int maxValue = 0;
        
        for (int ky = 0; ky < kernelSize; ky++) {
          for (int kx = 0; kx < kernelSize; kx++) {
            if (kernel[ky][kx] == 1) {
              final pixelValue = img.getLuminance(image.getPixel(x + kx - offset, y + ky - offset));
              if (pixelValue > maxValue) {
                maxValue = pixelValue.round();
              }
            }
          }
        }
        
        final color = img.ColorRgb8(maxValue, maxValue, maxValue);
        result.setPixel(x, y, color);
      }
    }
    
    return result;
  }
  
  /// Morphological erosion
  static img.Image _erode(img.Image image, List<List<int>> kernel) {
    final result = img.Image.from(image);
    final kernelSize = kernel.length;
    final offset = kernelSize ~/ 2;
    
    for (int y = offset; y < image.height - offset; y++) {
      for (int x = offset; x < image.width - offset; x++) {
        int minValue = 255;
        
        for (int ky = 0; ky < kernelSize; ky++) {
          for (int kx = 0; kx < kernelSize; kx++) {
            if (kernel[ky][kx] == 1) {
              final pixelValue = img.getLuminance(image.getPixel(x + kx - offset, y + ky - offset));
              if (pixelValue < minValue) {
                minValue = pixelValue.round();
              }
            }
          }
        }
        
        final color = img.ColorRgb8(minValue, minValue, minValue);
        result.setPixel(x, y, color);
      }
    }
    
    return result;
  }
  
  /// Compress image while maintaining quality for OCR
  static Future<File?> compressForUpload(File file) async {
    try {
      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        '${file.path}_compressed.jpg',
        quality: 90,
        minWidth: 1000,
        minHeight: 1000,
        format: CompressFormat.jpeg,
      );
      
      if (result != null) {
        debugPrint('🗜️ Compressed image: ${result.path}');
        return File(result.path);
      }
      
      return file;
    } catch (e) {
      debugPrint('❌ Compression error: $e');
      return file;
    }
  }
  
  /// Detect and correct document perspective
  static Future<img.Image?> correctPerspective(img.Image image) async {
    try {
      // Simplified perspective correction - detect document edges
      final edges = _detectDocumentEdges(image);
      
      if (edges.length == 4) {
        // Apply perspective transformation to straighten document
        return _applyPerspectiveTransform(image, edges);
      }
      
      return image;
    } catch (e) {
      debugPrint('❌ Perspective correction error: $e');
      return image;
    }
  }
  
  /// Detect document edges for perspective correction
  static List<Point<int>> _detectDocumentEdges(img.Image image) {
    // Simplified edge detection - find the largest rectangular contour
    // This is a basic implementation - in production, you'd use more sophisticated algorithms
    
    final edges = <Point<int>>[];
    
    // Apply edge detection (Canny-like)
    final edgeImage = img.sobel(image);
    
    // Find corners (simplified)
    final width = image.width;
    final height = image.height;
    
    // Return approximate document corners
    edges.add(Point(width ~/ 10, height ~/ 10)); // Top-left
    edges.add(Point(width - width ~/ 10, height ~/ 10)); // Top-right  
    edges.add(Point(width - width ~/ 10, height - height ~/ 10)); // Bottom-right
    edges.add(Point(width ~/ 10, height - height ~/ 10)); // Bottom-left
    
    return edges;
  }
  
  /// Apply perspective transformation to straighten document
  static img.Image _applyPerspectiveTransform(img.Image image, List<Point<int>> corners) {
    // Simplified perspective correction
    // In production, you'd use a proper perspective transformation matrix
    
    // For now, return the original image
    // TODO: Implement proper perspective transformation
    return image;
  }
}

/// Point class for coordinate handling
class Point<T extends num> {
  final T x;
  final T y;
  
  const Point(this.x, this.y);
  
  @override
  String toString() => 'Point($x, $y)';
}
