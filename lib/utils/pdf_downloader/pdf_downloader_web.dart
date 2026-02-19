import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class PdfDownloader {
  static Future<void> downloadPdf(BuildContext context, String url, String fileName) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Opening PDF in new tab...'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
         throw Exception('Could not launch URL');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open PDF: $e')),
        );
      }
    }
  }
}
