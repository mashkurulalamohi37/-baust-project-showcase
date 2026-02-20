import 'dart:convert';
import 'package:universal_html/html.dart' as html;

Future<void> downloadFile(String content, String fileName) async {
  final bytes = [0xEF, 0xBB, 0xBF, ...content.codeUnits];
  final blob = html.Blob([content], 'text/csv;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..click();
  html.Url.revokeObjectUrl(url);
}
