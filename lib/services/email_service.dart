import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class EmailService {
  // EmailJS Configuration - Connected to: 0802320405101082@baust.edu.bd
  // Service: Gmail (500 emails per day)
  // Templates: teacher_assignment, project_approval
  
  static const String _publicKey = '7qiVe32FB0QXfuhBu';
  static const String _serviceId = 'service_v9t8gbr';
  static const String _teacherTemplateId = 'teacher_assignment';
  static const String _approvalTemplateId = 'project_approval';
  
  static const String _apiUrl = 'https://api.emailjs.com/api/v1.0/email/send';

  /// Send email via direct HTTP request for reliability
  static Future<bool> _sendEmail({
    required String templateId,
    required Map<String, dynamic> templateParams,
  }) async {
    try {
      final url = Uri.parse(_apiUrl);
      final response = await http.post(
        url,
        headers: {
          'origin': 'http://localhost', // Helps with CORS if needed
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'service_id': _serviceId,
          'template_id': templateId,
          'user_id': _publicKey,
          'template_params': templateParams,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('✅ EmailJS: Email sent successfully! Template: $templateId');
        return true;
      } else {
        debugPrint('❌ EmailJS Error: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ EmailJS Exception: $e');
      return false;
    }
  }

  /// Send email to teacher when assigned to review a project
  static Future<bool> sendTeacherAssignmentEmail({
    required String teacherEmail,
    required String teacherName,
    required String projectTitle,
    required String studentName,
    required String submissionType,
  }) async {
    debugPrint('📧 Sending teacher assignment email to $teacherEmail...');
    return _sendEmail(
      templateId: _teacherTemplateId,
      templateParams: {
        'to_email': teacherEmail,
        'teacher_name': teacherName,
        'project_title': projectTitle,
        'student_name': studentName,
        'submission_type': submissionType,
      },
    );
  }

  /// Send email to student when their project is approved
  static Future<bool> sendProjectApprovalEmail({
    required String studentEmail,
    required String studentName,
    required String projectTitle,
    required String teacherName,
  }) async {
    debugPrint('📧 Sending approval email to $studentEmail...');
    return _sendEmail(
      templateId: _approvalTemplateId,
      templateParams: {
        'to_email': studentEmail,
        'student_name': studentName,
        'project_title': projectTitle,
        'teacher_name': teacherName,
      },
    );
  }
}
