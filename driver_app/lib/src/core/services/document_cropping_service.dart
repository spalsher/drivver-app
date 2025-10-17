import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' show join;

/// Service for document processing and enhancement
class DocumentCroppingService {
  
  /// Process and enhance document image
  Future<File> cropDocumentFromImage(File imageFile) async {
    try {
      debugPrint('🔍 Starting document processing...');
      
      // 1. Load and decode the image
      final imageBytes = await imageFile.readAsBytes();
      final originalImage = img.decodeImage(imageBytes);
      
      if (originalImage == null) {
        debugPrint('❌ Failed to decode image, returning original');
        return imageFile;
      }
      
      debugPrint('📸 Original image size: ${originalImage.width}x${originalImage.height}');
      
      // 2. Enhance the image for better OCR
      final enhancedImage = _enhanceDocumentImage(originalImage);
      
      // 3. Save the enhanced image
      final processedFile = await _saveProcessedImage(enhancedImage, 'enhanced');
      
      debugPrint('✅ Document enhanced and saved: ${processedFile.path}');
      return processedFile;
      
    } catch (e) {
      debugPrint('❌ Document processing error: $e');
      debugPrint('🔄 Returning original file as fallback');
      return imageFile;
    }
  }
  
  /// Enhance document image for better OCR
  img.Image _enhanceDocumentImage(img.Image image) {
    debugPrint('✨ Enhancing document image...');
    
    // 1. Adjust contrast and brightness
    var enhanced = img.adjustColor(
      image,
      contrast: 1.2,
      brightness: 1.05,
      saturation: 0.95,
    );
    
    // 2. Apply sharpening
    enhanced = _applySharpeningFilter(enhanced);
    
    debugPrint('✅ Image enhancement completed');
    return enhanced;
  }
  
  /// Apply sharpening filter to enhance image
  img.Image _applySharpeningFilter(img.Image image) {
    final sharpenedImage = img.Image(width: image.width, height: image.height);
    
    // Sharpening kernel
    final kernel = [
      [0, -1, 0],
      [-1, 5, -1],
      [0, -1, 0]
    ];
    
    for (int y = 1; y < image.height - 1; y++) {
      for (int x = 1; x < image.width - 1; x++) {
        double r = 0, g = 0, b = 0;
        
        // Apply convolution
        for (int ky = -1; ky <= 1; ky++) {
          for (int kx = -1; kx <= 1; kx++) {
            final pixel = image.getPixel(x + kx, y + ky);
            final weight = kernel[ky + 1][kx + 1];
            
            r += pixel.r * weight;
            g += pixel.g * weight;
            b += pixel.b * weight;
          }
        }
        
        // Clamp values
        r = r.clamp(0, 255);
        g = g.clamp(0, 255);
        b = b.clamp(0, 255);
        
        sharpenedImage.setPixel(x, y, img.ColorRgb8(r.round(), g.round(), b.round()));
      }
    }
    
    // Copy border pixels
    for (int y = 0; y < image.height; y++) {
      sharpenedImage.setPixel(0, y, image.getPixel(0, y));
      sharpenedImage.setPixel(image.width - 1, y, image.getPixel(image.width - 1, y));
    }
    
    for (int x = 0; x < image.width; x++) {
      sharpenedImage.setPixel(x, 0, image.getPixel(x, 0));
      sharpenedImage.setPixel(x, image.height - 1, image.getPixel(x, image.height - 1));
    }
    
    return sharpenedImage;
  }
  
  /// Save processed image to temporary directory
  Future<File> _saveProcessedImage(img.Image processedImage, String suffix) async {
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = '$timestamp-$suffix.jpg';
    final filePath = join(tempDir.path, fileName);
    
    final jpegBytes = img.encodeJpg(processedImage, quality: 95);
    final file = File(filePath);
    await file.writeAsBytes(jpegBytes);
    
    debugPrint('💾 Saved processed image: $filePath (${jpegBytes.length} bytes)');
    return file;
  }
}