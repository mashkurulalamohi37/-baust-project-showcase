import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Helper to create MultipartFile mainly for Cloudinary
class FileHelper {
  static Future<http.MultipartFile?> getMultipartFile(String path, {Uint8List? bytes}) async {
    if (bytes != null) {
      try {
        return http.MultipartFile.fromBytes('file', bytes, filename: path);
      } catch (e) {
        debugPrint('FileHelper: Error creating MultipartFile from bytes: $e');
        return null;
      }
    } else {
      debugPrint('FileHelper: Bytes are null on Web, cannot upload file from path: $path');
      return null;
    }
  }
}
