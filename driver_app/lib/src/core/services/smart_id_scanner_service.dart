import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

class SmartIdScanResult {
  final File imageFile;
  final String text;
  final List<Map<String, dynamic>> blocks;
  SmartIdScanResult({required this.imageFile, required this.text, required this.blocks});
}

class SmartIdScannerService {
  final ImagePicker _picker = ImagePicker();
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<SmartIdScanResult> scanDocument() async {
    try {
      // Pick image from camera
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 90,
      );

      if (pickedFile == null) {
        throw Exception('No image selected');
      }

      final File imageFile = File(pickedFile.path);

      // Perform OCR on the image
      final inputImage = InputImage.fromFilePath(imageFile.path);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      final blocks = recognizedText.blocks.map((block) {
        final boundingBox = block.boundingBox;
        return {
          'text': block.text,
          'boundingBox': boundingBox != null ? {
            'left': boundingBox.left,
            'top': boundingBox.top,
            'right': boundingBox.right,
            'bottom': boundingBox.bottom,
          } : null,
        };
      }).toList();

      return SmartIdScanResult(
        imageFile: imageFile,
        text: recognizedText.text,
        blocks: blocks,
      );
    } catch (e) {
      debugPrint('OCR scan error: $e');
      rethrow;
    } finally {
      await _textRecognizer.close();
    }
  }
}


