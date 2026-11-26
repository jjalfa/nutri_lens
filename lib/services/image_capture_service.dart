import 'dart:io';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';

class CapturedImage {
  const CapturedImage({
    required this.file,
    required this.bytes,
    required this.mimeType,
    required this.sizeKb,
  });

  final File file;
  final Uint8List bytes;
  final String mimeType;
  final double sizeKb;
}

class ImageCaptureService {
  ImageCaptureService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  Future<CapturedImage?> pickAndCompress(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 75,
    );

    if (picked == null) return null;

    final bytes = await picked.readAsBytes();
    return CapturedImage(
      file: File(picked.path),
      bytes: bytes,
      mimeType: 'image/jpeg',
      sizeKb: bytes.lengthInBytes / 1024,
    );
  }
}