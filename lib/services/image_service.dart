import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Service for handling image capture, processing, and storage
class ImageService {
  final ImagePicker _picker = ImagePicker();
  static const int _maxLongEdge = 2000;
  static const int _jpegQuality = 85;

  /// Capture image from camera
  Future<File?> captureFromCamera() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: _maxLongEdge.toDouble(),
        maxHeight: _maxLongEdge.toDouble(),
        imageQuality: _jpegQuality,
      );

      if (photo == null) return null;

      // Process and save the image
      return _processAndSaveImage(File(photo.path));
    } catch (e) {
      throw Exception('Failed to capture from camera: $e');
    }
  }

  /// Pick image from gallery
  Future<File?> pickFromGallery() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.gallery,
      );

      if (photo == null) return null;

      // Process and save the image
      return _processAndSaveImage(File(photo.path));
    } catch (e) {
      throw Exception('Failed to pick from gallery: $e');
    }
  }

  /// Process image: resize to max 2000px long edge and compress
  Future<File> _processAndSaveImage(File imageFile) async {
    // Read the image
    final bytes = await imageFile.readAsBytes();
    img.Image? image = img.decodeImage(bytes);

    if (image == null) {
      throw Exception('Failed to decode image');
    }

    // Resize if necessary (keeping aspect ratio)
    if (image.width > _maxLongEdge || image.height > _maxLongEdge) {
      if (image.width > image.height) {
        image = img.copyResize(image, width: _maxLongEdge);
      } else {
        image = img.copyResize(image, height: _maxLongEdge);
      }
    }

    // Encode as JPEG with quality 85
    final processedBytes = img.encodeJpg(image, quality: _jpegQuality);

    // Save to temporary file and return
    final tempFile = File(imageFile.path);
    await tempFile.writeAsBytes(processedBytes);

    return tempFile;
  }

  /// Save image to app's media directory
  /// [type] can be 'cards' or 'faces'
  /// [filename] should include contactId and optionally front/back designation
  Future<String> saveToMediaDirectory(
    File imageFile,
    String type,
    String filename,
  ) async {
    final appDir = await getApplicationDocumentsDirectory();
    final mediaDir = Directory(p.join(appDir.path, 'media', type));

    // Create directory if it doesn't exist
    if (!await mediaDir.exists()) {
      await mediaDir.create(recursive: true);
    }

    // Ensure filename has .jpg extension
    if (!filename.endsWith('.jpg')) {
      filename = '$filename.jpg';
    }

    final targetPath = p.join(mediaDir.path, filename);
    final targetFile = await imageFile.copy(targetPath);

    // Delete the temporary file
    try {
      await imageFile.delete();
    } catch (e) {
      // Ignore errors deleting temp file
    }

    return targetPath;
  }

  /// Delete image file
  Future<void> deleteImage(String? imagePath) async {
    if (imagePath == null || imagePath.isEmpty) return;

    try {
      final file = File(imagePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // Log error but don't throw - file might already be deleted
      print('Error deleting image: $e');
    }
  }

  /// Delete all images associated with a contact
  Future<void> deleteContactImages({
    String? cardFrontPath,
    String? cardBackPath,
    String? personPhotoPath,
  }) async {
    await Future.wait([
      deleteImage(cardFrontPath),
      deleteImage(cardBackPath),
      deleteImage(personPhotoPath),
    ]);
  }

  /// Get the media directory path
  Future<String> getMediaDirectoryPath() async {
    final appDir = await getApplicationDocumentsDirectory();
    return p.join(appDir.path, 'media');
  }

  /// Check if file exists at path
  Future<bool> imageExists(String? imagePath) async {
    if (imagePath == null || imagePath.isEmpty) return false;
    return File(imagePath).exists();
  }
}
