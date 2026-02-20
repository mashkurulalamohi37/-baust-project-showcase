import 'package:csv/csv.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../mvc/models/project.dart';
import '../models/user.dart';

// Conditional imports for web vs native
import 'export_service_web.dart' if (dart.library.io) 'export_service_native.dart';

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

    // 2. Handle File Download/Sharing via conditional platform stub
    final name = fileName ?? 'project_showcase_export_${DateTime.now().millisecondsSinceEpoch}.csv';
    debugPrint('ExportService: Downloading $name (kIsWeb=$kIsWeb)');
    try {
      await downloadFile(csvContent, name);
    } catch (e) {
      debugPrint('ExportService: Download failed: $e');
    }
  }
}
