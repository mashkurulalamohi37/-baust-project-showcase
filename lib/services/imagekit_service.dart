import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class ImageKitService {
  static const String _urlEndpoint = 'https://ik.imagekit.io/fuzq89rsq/';
  static const String _publicKey = 'public_upbkdIKHCw4l8kl+jRDsvO7nqpo=';
  static const String _privateKey = 'private_0HXhfFCpvR4UJxck8vNOiPayDcU=';

  static final ImageKitService _instance = ImageKitService._internal();
  factory ImageKitService() => _instance;
  ImageKitService._internal();

  Future<String?> uploadFile(
    String filePath, {
    required String fileName,
    String? folder,
    Uint8List? bytes,
    Function(double)? onProgress,
  }) async {
    try {
      final uri = Uri.parse('https://upload.imagekit.io/api/v1/files/upload');
      
      // Authorization header (Basic Auth with Private Key)
      final String basicAuth = 'Basic ' + base64Encode(utf8.encode('$_privateKey:'));

      // Use custom request if onProgress is provided
      final request = onProgress != null
          ? MultipartRequestWithProgress('POST', uri, onProgress: onProgress)
          : http.MultipartRequest('POST', uri);
      
      request.headers['Authorization'] = basicAuth;

      request.fields['fileName'] = fileName;
      if (folder != null) {
        request.fields['folder'] = folder;
      }

      if (bytes != null) {
        request.files.add(http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: fileName,
        ));
      } else if (!kIsWeb && filePath.isNotEmpty) {
        request.files.add(await http.MultipartFile.fromPath(
          'file',
          filePath,
          filename: fileName,
        ));
      } else if (kIsWeb && filePath.isNotEmpty) {
        debugPrint('ImageKitService: Warning - fromPath is not supported on web. Use bytes instead.');
      }

      debugPrint('ImageKitService: Uploading $fileName to folder: $folder');
      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final url = data['url'];
        debugPrint('ImageKitService: Upload successful: $url');
        return url;
      } else {
        debugPrint('ImageKitService: Upload failed (${response.statusCode}): ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('ImageKitService: Error uploading file: $e');
      return null;
    }
  }

  static Future<String?> uploadVideo(String filePath, {Uint8List? data, String? folder, Function(double)? onProgress}) async {
    String fileName = filePath.contains('/') ? filePath.split('/').last : filePath;
    if (fileName == 'video.mp4' || fileName.isEmpty) {
      fileName = 'video_${DateTime.now().millisecondsSinceEpoch}.mp4';
    }
    return _instance.uploadFile(filePath, fileName: fileName, bytes: data, folder: folder, onProgress: onProgress);
  }
}

/// Custom MultipartRequest to track upload progress
class MultipartRequestWithProgress extends http.MultipartRequest {
  final Function(double) onProgress;

  MultipartRequestWithProgress(
    super.method,
    super.url, {
    required this.onProgress,
  });

  @override
  http.ByteStream finalize() {
    final byteStream = super.finalize();
    final totalLength = contentLength;
    int bytesSent = 0;

    final transformer = StreamTransformer.fromHandlers(
      handleData: (List<int> data, EventSink<List<int>> sink) {
        bytesSent += data.length;
        if (totalLength > 0) {
          onProgress(bytesSent / totalLength);
        }
        sink.add(data);
      },
    );

    return http.ByteStream(byteStream.transform(transformer));
  }
}
