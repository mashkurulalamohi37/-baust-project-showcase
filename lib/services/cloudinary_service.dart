import 'dart:convert';
import 'dart:typed_data'; // Added for Uint8List
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
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

  /// Uploads a file to Cloudinary
  /// [filePath] is the local path to the file (on mobile) or identifier (on web)
  /// [bytes] is the file content (required on web)
  /// [resourceType] can be 'image', 'video', or 'raw'
  Future<String?> uploadFile(String filePath, {String resourceType = 'auto', String? folder, Uint8List? bytes}) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      
      // Prepare parameters for signature
      final Map<String, String> validParams = {
        'timestamp': timestamp.toString(),
      };
      
      if (folder != null) {
        validParams['folder'] = folder;
      }
      
      // Generate signature
      final sortedKeys = validParams.keys.toList()..sort();
      final String stringToSign = sortedKeys.map((key) => '$key=${validParams[key]}').join('&') + _apiSecret;
      
      final signature = sha1.convert(utf8.encode(stringToSign)).toString();
      
      // Create multipart request
      final uri = Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/$resourceType/upload');
      final request = http.MultipartRequest('POST', uri);
      
      // Add fields
      request.fields['api_key'] = _apiKey;
      request.fields['timestamp'] = timestamp.toString();
      request.fields['signature'] = signature;
      if (folder != null) {
        request.fields['folder'] = folder;
      }
      
      // Add file using helper
      debugPrint('CloudinaryService: Uploading $resourceType from $filePath');
      
      final multipartFile = await FileHelper.getMultipartFile(filePath, bytes: bytes);
      
      if (multipartFile != null) {
        request.files.add(multipartFile);
      } else {
        debugPrint('CloudinaryService: Failed to create MultipartFile. Bytes provided: ${bytes != null}');
        return null;
      }
      
      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final secureUrl = data['secure_url'];
        debugPrint('CloudinaryService: Upload successful: $secureUrl');
        return secureUrl;
      } else {
        debugPrint('CloudinaryService: Upload failed with status ${response.statusCode}');
        debugPrint('CloudinaryService: Response body: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('CloudinaryService: Error uploading file: $e');
      return null;
    }
  }

  /// Helper for multiple files
  Future<List<String>> uploadMultipleFiles(List<String> filePaths, {String? folder}) async {
    final List<String> urls = [];
    for (final path in filePaths) {
      // Note: This currently only supports paths (mobile). 
      // For web support with multiple files, we'd need to pass a List<Uint8List> or similar structure.
      final url = await uploadFile(path, resourceType: 'auto', folder: folder);
      if (url != null) {
        urls.add(url);
      }
    }
    return urls;
  }
}
