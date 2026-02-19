import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../mvc/models/user.dart';
import '../mvc/models/project.dart';

class ResumeService {
  Future<Uint8List> generateResume(User user, List<Project> projects) async {
    final pdf = pw.Document();

    final profileImage = user.profileImageUrl != null
        ? await networkImage(user.profileImageUrl!)
        : null;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          final pinnedIds = user.pinnedProjectIds ?? [];
          final pinnedProjects = projects.where((p) => pinnedIds.contains(p.id)).toList();
          final otherProjects = projects.where((p) => !pinnedIds.contains(p.id)).toList();

          return [
            _buildHeader(user, profileImage),
            pw.SizedBox(height: 20),
            _buildSectionTitle('Profile'),
            _buildProfileSection(user),
            pw.SizedBox(height: 20),
            if (user.skills != null && user.skills!.isNotEmpty) ...[
              _buildSectionTitle('Skills'),
              _buildSkillsSection(user.skills!),
              pw.SizedBox(height: 20),
            ],
            
            if (pinnedProjects.isNotEmpty) ...[
              _buildSectionTitle('Featured Projects'),
              ...pinnedProjects.map((project) => _buildProjectItem(project)),
              pw.SizedBox(height: 10),
            ],

            if (otherProjects.isNotEmpty) ...[
               _buildSectionTitle(pinnedProjects.isNotEmpty ? 'Recent Projects' : 'Projects'),
              ...otherProjects.map((project) => _buildProjectItem(project)),
            ],
            
            pw.SizedBox(height: 20),
            _buildFooter(),
          ];
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildHeader(User user, pw.ImageProvider? profileImage) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (profileImage != null)
          pw.Container(
            width: 60,
            height: 60,
            margin: const pw.EdgeInsets.only(right: 16),
            decoration: pw.BoxDecoration(
              shape: pw.BoxShape.circle,
              image: pw.DecorationImage(image: profileImage, fit: pw.BoxFit.cover),
            ),
          ),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                user.name,
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                user.email,
                style: const pw.TextStyle(
                  fontSize: 12,
                  color: PdfColors.grey700,
                ),
              ),
              if (user.linkedinUrl != null)
                pw.Text(
                  'LinkedIn: ${user.linkedinUrl}',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.blue),
                ),
              if (user.githubUrl != null)
                pw.Text(
                  'GitHub: ${user.githubUrl}',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.blue),
                ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildSectionTitle(String title) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 1)),
      ),
      child: pw.Row(
        children: [
          pw.Text(
            title.toUpperCase(),
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue800,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildProfileSection(User user) {
    return pw.Text(
      user.bio ?? 'No bio provided.',
      style: const pw.TextStyle(fontSize: 12, lineSpacing: 1.5),
    );
  }

  pw.Widget _buildSkillsSection(List<String> skills) {
    return pw.Wrap(
      spacing: 8,
      runSpacing: 4,
      children: skills.map((skill) {
        return pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Text(skill, style: const pw.TextStyle(fontSize: 10)),
        );
      }).toList(),
    );
  }

  pw.Widget _buildProjectItem(Project project) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 16),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                project.title,
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                project.year.toString(),
                style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          if (project.category != null)
            pw.Text(
              project.category.name.toUpperCase(),
              style: pw.TextStyle(fontSize: 8, color: PdfColors.blue600, fontWeight: pw.FontWeight.bold),
            ),
          pw.SizedBox(height: 4),
          pw.Text(
            project.abstract,
            style: const pw.TextStyle(fontSize: 10, lineSpacing: 1.4),
            maxLines: 3,
          ),
          if (project.tags.isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Text(
              'Tech: ${project.tags.join(", ")}',
              style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700, fontStyle: pw.FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

  pw.Widget _buildFooter() {
    return pw.Align(
      alignment: pw.Alignment.bottomCenter,
      child: pw.Text(
        'Generated by Project Showcase App',
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey400),
      ),
    );
  }
}
