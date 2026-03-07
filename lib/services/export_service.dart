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
      'Project Type',      // Thesis / Hardware / Project ✅
      'Submission Type',
      'Course',
      'Group/Individual',
      'Group Name',
    ]);

    // Data Rows
    for (var project in projects) {
      // For group projects, list all member IDs and names
      final studentNames = project.isGroupProject
          ? project.teamMembers.map((m) => m.name).join(', ')
          : project.authorName;
      final studentIds = project.isGroupProject
          ? project.teamMembers.map((m) => m.id).join(', ')
          : (project.studentId?.isNotEmpty == true ? '=\"${project.studentId!}\"' : 'N/A');

      rows.add([
        project.title,
        studentNames,
        studentIds,
        project.facultyName ?? 'N/A',
        project.semester.displayName,
        project.year,
        project.category.displayName,
        project.status.displayName,
        project.projectType.displayName,  // Thesis / Hardware / Project ✅
        project.submissionType.displayName,
        project.academicCourse?.displayName ?? 'N/A',
        project.isGroupProject ? 'Group' : 'Individual',
        project.isGroupProject ? (project.groupName ?? 'N/A') : 'N/A',
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

  /// Exports showcase evaluation markings for a list of projects.
  /// Each row = one project. All teachers' marks are shown in a single
  /// summary column, plus individual columns per teacher for detail.
  static Future<void> exportEvaluations(List<Project> projects, {String? fileName}) async {
    // Collect unique teacher names across all projects (for column headers)
    final teacherNames = <String>{};
    for (final p in projects) {
      for (final e in p.evaluations) {
        if (e.teacherName.isNotEmpty) teacherNames.add(e.teacherName);
      }
    }
    final sortedTeachers = teacherNames.toList()..sort();

    // Build header
    final header = <dynamic>[
      'Project Title',
      'Student Name',
      'Student ID',
      'Semester',
      'Year',
      'Category',
      'Type',
      'Award',
      'Overall Avg Score',   // average of all teachers
      'All Markings Summary', // e.g. "Teacher A: 8.2, Teacher B: 7.0"
    ];
    // Per-teacher columns
    for (final t in sortedTeachers) {
      header.add('$t - Innovation');
      header.add('$t - Technical');
      header.add('$t - Presentation');
      header.add('$t - Avg');
      header.add('$t - Feedback');
    }

    final List<List<dynamic>> rows = [header];

    for (final project in projects) {
      if (project.evaluations.isEmpty) continue; // skip unevaluated projects

      // Student info
      final studentName = project.isGroupProject
          ? project.teamMembers.map((m) => m.name).join(' / ')
          : (project.studentName?.isNotEmpty == true ? project.studentName! : project.authorName);
      final studentId = project.isGroupProject
          ? project.teamMembers.map((m) => m.id).join(' / ')
          : (project.studentId?.isNotEmpty == true ? '="${project.studentId!}"' : 'N/A');

      // Overall average across all evaluations
      double totalAvg = 0;
      final summaryParts = <String>[];
      for (final e in project.evaluations) {
        final avg = e.criteria.isNotEmpty
            ? e.criteria.values.fold<double>(0.0, (double a, double b) => a + b) / e.criteria.length
            : e.mark;
        totalAvg += avg;
        summaryParts.add('${e.teacherName}: ${avg.toStringAsFixed(1)}');
      }
      final overallAvg = project.evaluations.isNotEmpty
          ? totalAvg / project.evaluations.length
          : 0.0;

      final row = <dynamic>[
        project.title,
        studentName,
        studentId,
        project.semester.displayName,
        project.year,
        project.category.displayName,
        project.projectType.displayName,
        project.award == ProjectAward.none ? '' : project.award.displayName,
        overallAvg.toStringAsFixed(2),
        summaryParts.join(' | '),
      ];

      // Per-teacher columns
      for (final teacherName in sortedTeachers) {
        final eval = project.evaluations.firstWhere(
          (e) => e.teacherName == teacherName,
          orElse: () => ShowcaseEvaluation(teacherId: '', teacherName: '', mark: 0, updatedAt: DateTime.now()),
        );
        final hasMark = eval.teacherId.isNotEmpty;
        if (hasMark) {
          final avg = eval.criteria.isNotEmpty
              ? eval.criteria.values.fold<double>(0.0, (double a, double b) => a + b) / eval.criteria.length
              : eval.mark;
          row.add((eval.criteria['Innovation'] ?? eval.mark).toStringAsFixed(1));
          row.add((eval.criteria['Technical'] ?? eval.mark).toStringAsFixed(1));
          row.add((eval.criteria['Presentation'] ?? eval.mark).toStringAsFixed(1));
          row.add(avg.toStringAsFixed(2));
          row.add(eval.feedback ?? '');
        } else {
          row.addAll(['-', '-', '-', '-', '']);
        }
      }

      rows.add(row);
    }

    final csvContent = const ListToCsvConverter().convert(rows);
    final name = fileName ?? 'evaluation_markings_${DateTime.now().millisecondsSinceEpoch}.csv';
    debugPrint('ExportService: Downloading evaluations $name');
    try {
      await downloadFile(csvContent, name);
    } catch (e) {
      debugPrint('ExportService: Evaluation download failed: $e');
    }
  }
}
