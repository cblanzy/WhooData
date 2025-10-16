import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Service for extracting contact information from business card images using OCR
class OcrService {
  final _textRecognizer = TextRecognizer();

  /// Recognize text from an image and extract contact fields
  Future<OcrResult> recognizeText(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      // Extract fields using heuristics
      final email = _extractEmail(recognizedText.text);
      final phone = _extractPhone(recognizedText.text);
      final name = _extractName(recognizedText.text, recognizedText.blocks);

      // Calculate average confidence from all text elements
      var totalConfidence = 0.0;
      var elementCount = 0;
      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          for (final element in line.elements) {
            if (element.confidence != null) {
              totalConfidence += element.confidence!;
              elementCount++;
            }
          }
        }
      }
      final avgConfidence = elementCount > 0 ? totalConfidence / elementCount : 0.0;

      return OcrResult(
        name: name,
        phone: phone,
        email: email,
        rawText: recognizedText.text,
        confidence: avgConfidence,
      );
    } catch (e) {
      return OcrResult(
        name: null,
        phone: null,
        email: null,
        rawText: '',
        confidence: 0.0,
        error: e.toString(),
      );
    }
  }

  /// Extract email address from text using regex
  String? _extractEmail(String text) {
    // Email regex pattern
    final emailRegex = RegExp(
      r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}',
      caseSensitive: false,
    );

    final match = emailRegex.firstMatch(text);
    return match?.group(0);
  }

  /// Extract phone number from text (10-15 digits)
  String? _extractPhone(String text) {
    // Remove common phone number formatting characters
    final digitsOnly = text.replaceAll(RegExp(r'[\s\-\(\)\.]'), '');

    // Look for sequences of 10-15 digits
    final phoneRegex = RegExp(r'\d{10,15}');
    final match = phoneRegex.firstMatch(digitsOnly);

    if (match != null) {
      final phone = match.group(0)!;
      // Format as (XXX) XXX-XXXX for 10 digits, or return as-is
      if (phone.length == 10) {
        return '(${phone.substring(0, 3)}) ${phone.substring(3, 6)}-${phone.substring(6)}';
      }
      return phone;
    }

    return null;
  }

  /// Extract name from text blocks
  /// Heuristic: Find largest text block in top third of image without digits or @
  String? _extractName(String fullText, List<TextBlock> blocks) {
    if (blocks.isEmpty) return null;

    // Get image height from blocks
    var maxY = 0;
    for (final block in blocks) {
      final blockBottom = block.boundingBox.bottom.toInt();
      if (blockBottom > maxY) maxY = blockBottom;
    }

    final topThirdY = maxY / 3;

    // Find blocks in top third
    final topBlocks = blocks.where((block) {
      final blockTop = block.boundingBox.top.toInt();
      return blockTop <= topThirdY;
    }).toList();

    if (topBlocks.isEmpty) return null;

    // Filter out blocks with digits or @ (likely phone/email)
    final nameBlocks = topBlocks.where((block) {
      final text = block.text;
      return !text.contains(RegExp(r'[\d@]'));
    }).toList();

    if (nameBlocks.isEmpty) return null;

    // Find the largest (by text length) block
    nameBlocks.sort((a, b) => b.text.length.compareTo(a.text.length));
    final nameBlock = nameBlocks.first;

    // Clean up the name (capitalize words, trim)
    return _formatName(nameBlock.text);
  }

  /// Format name with proper capitalization
  String _formatName(String name) {
    // Split into words, capitalize each, rejoin
    final words = name.trim().split(RegExp(r'\s+'));
    final capitalizedWords = words.map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    });
    return capitalizedWords.join(' ');
  }

  /// Clean up resources
  void dispose() {
    _textRecognizer.close();
  }
}

/// Result of OCR text recognition
class OcrResult {
  const OcrResult({
    required this.rawText,
    required this.confidence,
    this.name,
    this.phone,
    this.email,
    this.error,
  });

  final String? name;
  final String? phone;
  final String? email;
  final String rawText;
  final double confidence; // 0.0 to 1.0
  final String? error;

  bool get hasError => error != null;
  bool get hasAnyData => name != null || phone != null || email != null;

  /// Get confidence as percentage (0-100)
  int get confidencePercent => (confidence * 100).round();

  @override
  String toString() {
    return 'OcrResult(name: $name, phone: $phone, email: $email, '
        'confidence: $confidencePercent%)';
  }
}
