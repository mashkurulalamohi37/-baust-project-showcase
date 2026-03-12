import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

/// Helper to create MultipartFile mainly for Cloudinary
class FileHelper {
  static Future<http.MultipartFile?> getMultipartFile(String path, {Uint8List? bytes}) async {
    if (bytes != null) {
      try {
        final ext = path.split('.').last.toLowerCase();
        MediaType? mediaType;
        if (ext == 'mp4' || ext == 'mkv' || ext == 'avi') {
          mediaType = MediaType('video', ext == 'mp4' ? 'mp4' : ext);
        } else if (ext == 'jpg' || ext == 'jpeg' || ext == 'png' || ext == 'gif' || ext == 'webp') {
          mediaType = MediaType('image', ext == 'jpg' ? 'jpeg' : ext);
        } else if (ext == 'pdf') {
          mediaType = MediaType('application', 'pdf');
        }
        return http.MultipartFile.fromBytes('file', bytes, filename: path, contentType: mediaType);
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
