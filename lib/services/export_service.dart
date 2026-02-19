import 'package:csv/csv.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:universal_html/html.dart' as html;
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import '../mvc/models/project.dart';
import '../models/user.dart';

class ExportService {
  static Future<void> exportProjects(List<Project> projects, {String? fileName}) async {
    // 1. Create CSV Data
    List<List<dynamic>> rows = [];

    // Header Row
    rows.add([
      'Project Title',
      'Student Name',
      'Student ID',
      'Supervisor',
      'Semester',
      'Year',
      'Category',
      'Status',
      'Submission Type',
      'Course',
    ]);

    // Data Rows
    for (var project in projects) {
      rows.add([
        project.title,
        project.isGroupProject 
            ? project.teamMembers.map((m) => m.name).join(', ') 
            : project.authorName,
        project.isGroupProject 
            ? project.teamMembers.map((m) => m.id).join(', ') 
            : project.authorId,
        project.facultyName ?? 'N/A',
        project.semester.displayName,
        project.year,
        project.category.displayName,
        project.status.displayName,
        project.submissionType.displayName,
        project.academicCourse?.displayName ?? 'N/A',
      ]);
    }

    // Verify data
    debugPrint('ExportService: Generated ${rows.length} rows for CSV (including header)');
    
    String csvContent = const ListToCsvConverter().convert(rows);
    debugPrint('ExportService: CSV content length: ${csvContent.length}');

    // 2. Handle File Download/Sharing
    if (kIsWeb) {
      await _downloadWeb(csvContent, fileName: fileName);
    } else {
      await _downloadMobile(csvContent, fileName: fileName);
    }
  }

  static Future<void> _downloadWeb(String content, {String? fileName}) async {
    final name = fileName ?? 'project_showcase_export_${DateTime.now().millisecondsSinceEpoch}.csv';
    debugPrint('ExportService (Web): Download started for $name');
    
    // Add BOM for Excel compatibility
    final bytes = [0xEF, 0xBB, 0xBF, ...utf8.encode(content)];
    final blob = html.Blob(bytes, 'text/csv;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', name)
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  static Future<void> _downloadMobile(String content, {String? fileName}) async {
    final name = fileName ?? 'project_showcase_export_${DateTime.now().millisecondsSinceEpoch}.csv';
    debugPrint('ExportService (Mobile): Download started for $name');

    // Request storage permission if needed (Android < 10 typically)
    if (!kIsWeb && Platform.isAndroid) {
       var status = await Permission.storage.status;
       if (!status.isGranted) {
         status = await Permission.storage.request();
         debugPrint('ExportService (Mobile): Storage permission status: $status');
       }
    }

    try {
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/$name';
      final file = File(path);
      
      // Write as bytes with BOM for Excel compatibility
      final bytes = [0xEF, 0xBB, 0xBF, ...utf8.encode(content)];
      await file.writeAsBytes(bytes);
      debugPrint('ExportService (Mobile): File written to $path (${bytes.length} bytes)');

      // Share the file
      final xFile = XFile(path, mimeType: 'text/csv');
      await Share.shareXFiles([xFile], subject: 'Project Showcase Export');
      debugPrint('ExportService (Mobile): Share dialog opened');
    } catch (e) {
      debugPrint('Error exporting on mobile: $e');
    }
  }
}
