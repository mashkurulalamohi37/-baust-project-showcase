import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'dart:typed_data'; // Added for Uint8List
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:crypto/crypto.dart';
import 'package:projectshowcase/utils/file_helper/file_helper.dart'; // Import the helper

class CloudinaryService {
  // Credentials from user
  static const String _cloudName = 'dgbfi7ox4';
  static const String _apiKey = '158216586861927';
  static const String _apiSecret = 'oazEhR9G6WnxyskBFWXiIsOezIc';
  
  static final CloudinaryService _instance = CloudinaryService._internal();
  factory CloudinaryService() => _instance;
  CloudinaryService._internal();

  Future<String?> uploadFile(
    String filePath, {
    String resourceType = 'auto',
    String? folder,
    Uint8List? bytes,
    Function(double)? onProgress,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      
      final Map<String, String> validParams = {
        'timestamp': timestamp.toString(),
      };
      
      if (folder != null) {
        validParams['folder'] = folder;
      }
      
      final sortedKeys = validParams.keys.toList()..sort();
      final String stringToSign = sortedKeys.map((key) => '$key=${validParams[key]}').join('&') + _apiSecret;
      final signature = sha1.convert(utf8.encode(stringToSign)).toString();
      
      final uri = Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/$resourceType/upload');
      
      // Use custom request if onProgress is provided
      final request = onProgress != null 
          ? MultipartRequestWithProgress('POST', uri, onProgress: onProgress)
          : http.MultipartRequest('POST', uri);
      
      request.fields['api_key'] = _apiKey;
      request.fields['timestamp'] = timestamp.toString();
      request.fields['signature'] = signature;
      if (folder != null) {
        request.fields['folder'] = folder;
      }
      
      debugPrint('CloudinaryService: Uploading $resourceType from $filePath');
      
      if (bytes != null) {
        // Native Multipart mapping for raw Web buffers
        String ext = filePath.split('.').last.toLowerCase();
        if (ext.isEmpty || ext == filePath.toLowerCase()) {
           ext = resourceType == 'video' ? 'mp4' : (resourceType == 'image' ? 'jpeg' : 'pdf');
        }
        
        final fileName = filePath.contains('/') ? filePath.split('/').last : filePath;
        final safeFileName = fileName.isNotEmpty && fileName != 'Existing Video' ? fileName : 'upload.$ext';
        
        MediaType mediaType;
        if (resourceType == 'video' || ext == 'mp4' || ext == 'mkv' || ext == 'avi') {
          mediaType = MediaType('video', ext == 'mp4' ? 'mp4' : ext);
        } else if (resourceType == 'image' || ext == 'jpg' || ext == 'jpeg' || ext == 'png' || ext == 'webp') {
          mediaType = MediaType('image', ext == 'jpg' ? 'jpeg' : ext);
        } else {
          mediaType = MediaType('application', 'pdf');
        }

        final multipartFile = http.MultipartFile.fromBytes(
          'file', 
          bytes, 
          filename: safeFileName,
          contentType: mediaType,
        );
        request.files.add(multipartFile);
      } else {
        // Try file path approach for native platforms
        final multipartFile = await FileHelper.getMultipartFile(filePath, bytes: null);
        
        if (multipartFile != null) {
          request.files.add(multipartFile);
        } else {
          debugPrint('CloudinaryService: Failed to create MultipartFile.');
          return null;
        }
      }
      
      // Send request
      final streamedResponse = await request.send().timeout(const Duration(seconds: 300)); // Increased to 5 mins as progress is visible
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final secureUrl = data['secure_url'];
        debugPrint('CloudinaryService: Upload successful: $secureUrl');
        return secureUrl;
      } else {
        debugPrint('CloudinaryService: Upload failed with status ${response.statusCode}');
        debugPrint('CloudinaryService: Response body: ${response.body}');
        
        String errorMessage = 'Upload failed with status ${response.statusCode}';
        try {
          final data = jsonDecode(response.body);
          if (data['error'] != null && data['error']['message'] != null) {
            errorMessage = data['error']['message'];
          }
        } catch (_) {}
        
        throw Exception(errorMessage);
      }
    } on TimeoutException catch (_) {
      throw Exception('Upload timed out. Please try a faster network.');
    } catch (e) {
      if (!kIsWeb && e is SocketException) {
        debugPrint('CloudinaryService: Network error (SocketException): $e');
        throw Exception('Connection lost. Please check your internet and try again.');
      }
      if (e is http.ClientException) {
        debugPrint('CloudinaryService: HTTP Client error: $e');
        throw Exception('Network error during upload. Please try again.');
      }
      debugPrint('CloudinaryService: Error uploading file: $e');
      rethrow;
    }
  }

  /// Helper for multiple files
  Future<List<String>> uploadMultipleFiles(List<String> filePaths, {String? folder, Function(double)? onProgress}) async {
    final List<String> urls = [];
    for (int i = 0; i < filePaths.length; i++) {
      final path = filePaths[i];
      // Simple per-file progress partitioning for multiple files
      final url = await uploadFile(
        path, 
        resourceType: 'auto', 
        folder: folder,
        onProgress: onProgress != null ? (p) {
          onProgress((i + p) / filePaths.length);
        } : null,
      );
      if (url != null) {
        urls.add(url);
      }
    }
    return urls;
  }

  /// Static helper for video uploads
  static Future<String?> uploadVideo(String filePath, {Uint8List? data, String? folder, Function(double)? onProgress}) async {
    return _instance.uploadFile(filePath, resourceType: 'video', bytes: data, folder: folder, onProgress: onProgress);
  }
}

/// Custom MultipartRequest to track upload progress
class MultipartRequestWithProgress extends http.MultipartRequest {
  final Function(double) onProgress;

  MultipartRequestWithProgress(
    String method,
    Uri url, {
    required this.onProgress,
  }) : super(method, url);

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
