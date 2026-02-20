import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> downloadFile(String content, String fileName) async {
  final directory = await getTemporaryDirectory();
  final path = '${directory.path}/$fileName';
  final file = File(path);
  final bytes = [0xEF, 0xBB, 0xBF, ...utf8.encode(content)];
  await file.writeAsBytes(bytes);
  final xFile = XFile(path, mimeType: 'text/csv');
  await Share.shareXFiles([xFile], subject: 'Project Showcase Export');
}
