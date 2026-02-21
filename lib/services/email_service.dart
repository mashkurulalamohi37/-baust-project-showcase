import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class EmailService {
  // EmailJS Configuration
  static const String _serviceId = 'service_v9t8gbr';
  static const String _publicKey = '7qiVe32FB0QXfuhBu';
  static const String _teacherTemplateId = 'teacher_assignment';
  static const String _approvalTemplateId = 'project_approval';

  /// Send email via EmailJS REST API
  static Future<bool> _sendEmailJS({
    required String templateId,
    required Map<String, dynamic> templateParams,
  }) async {
    final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');
    try {
      final response = await http.post(
        url,
        headers: {
          'origin': 'http://localhost',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'service_id': _serviceId,
          'template_id': templateId,
          'user_id': _publicKey,
          'template_params': templateParams,
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ EmailJS: Email sent successfully using template $templateId');
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
    debugPrint('📧 Sending teacher assignment email via EmailJS to $teacherEmail...');
    
    return _sendEmailJS(
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
    debugPrint('📧 Sending approval email via EmailJS to $studentEmail...');
    
    return _sendEmailJS(
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
