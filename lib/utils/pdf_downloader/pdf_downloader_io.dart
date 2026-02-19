import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class PdfDownloader {
  static Future<void> downloadPdf(BuildContext context, String url, String fileName) async {
    try {
      // Request storage permission
      // Note: On Android 13+, photos/videos/audio permissions are separate, 
      // but for generic files logic might differ. storage usually works for older android.
      // For simplified logic:
      var status = await Permission.storage.request();
      
      // On Android 13 (SDK 33), READ_EXTERNAL_STORAGE is deprecated for media, 
      // but generic file writing to app specific dirs doesn't always need it.
      // However, if we want to write to public Download folder, it's tricky.
      // We will stick to the existing logic which was writing to App Documents or External Storage.
      
      if (!status.isGranted) {
        // Try manage external storage for Android 11+ if strictly needed, but let's just show msg
        // Actually, let's proceed if we are writing to app-specific directory which might not need permission.
        // But user code had permission check, so we keep it to be safe, but we warn if denied.
        if (context.mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Storage permission denied. attempting to save to app storage...')),
          );
        }
      }

      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        throw Exception('Failed to download PDF: ${response.statusCode}');
      }

      Directory? directory;
      if (Platform.isAndroid) {
         // Use getExternalStorageDirectory for visibility or getApplicationDocumentsDirectory
         directory = await getExternalStorageDirectory();
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      if (directory == null) {
          throw Exception('Could not access storage directory');
      }

      final cleanFileName = fileName.replaceAll(RegExp(r'[^\w\s]+'), '_') + '.pdf';
      final filePath = '${directory.path}/$cleanFileName';
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF downloaded to: $filePath'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error downloading PDF: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
