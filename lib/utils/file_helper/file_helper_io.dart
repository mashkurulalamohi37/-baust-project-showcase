import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Helper to create MultipartFile mainly for Cloudinary
class FileHelper {
  static Future<http.MultipartFile?> getMultipartFile(String path, {Uint8List? bytes}) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        return await http.MultipartFile.fromPath('file', path);
      } else {
        debugPrint('FileHelper: File not found at $path');
        return null;
      }
    } catch (e) {
      debugPrint('FileHelper: Error creating MultipartFile from path: $e');
      return null;
    }
  }
}
