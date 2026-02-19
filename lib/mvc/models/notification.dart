import 'package:cloud_firestore/cloud_firestore.dart';

class Notification {
  final String id;
  final String userId;
  final String title;
  final String message;
  final NotificationType type;
  final String? projectId;
  final String? actionData;
  final DateTime createdAt;
  final bool isRead;

  Notification({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    this.projectId,
    this.actionData,
    required this.createdAt,
    required this.isRead,
  });

  Notification copyWith({
    String? id,
    String? userId,
    String? title,
    String? message,
    NotificationType? type,
    String? projectId,
    String? actionData,
    DateTime? createdAt,
    bool? isRead,
  }) {
    return Notification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      projectId: projectId ?? this.projectId,
      actionData: actionData ?? this.actionData,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'message': message,
      'type': type.name,
      'projectId': projectId,
      'actionData': actionData,
      'createdAt': createdAt.toIso8601String(),
      'isRead': isRead,
    };
  }

  factory Notification.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic date) {
      if (date == null) return DateTime.now();
      if (date is DateTime) return date;
      if (date is String) return DateTime.tryParse(date) ?? DateTime.now();
      if (date is Timestamp) return date.toDate();
      // Try parsing if it's a specific Firestore timestamp structure
      try {
        if (date is Map && date.containsKey('_seconds')) {
          return DateTime.fromMillisecondsSinceEpoch(date['_seconds'] * 1000);
        }
      } catch (_) {}
      return DateTime.now();
    }

    return Notification(
      id: map['id']?.toString() ?? map['id']?.toString() ?? '',
      userId: map['userId'] ?? map['user_id'] ?? '',
      title: map['title'] ?? '',
      message: map['message'] ?? '',
      type: NotificationType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => NotificationType.general,
      ),
      projectId: map['projectId'] ?? map['project_id'],
      actionData: map['actionData'],
      createdAt: parseDate(map['createdAt'] ?? map['created_at']),
      isRead: map['isRead'] ?? map['is_read'] ?? false,
    );
  }
}

enum NotificationType {
  projectApproved,
  projectRejected,
  projectNeedsRevision,
  projectFeatured,
  newReview,
  accountApproved,
  accountRejected,
  systemMessage,
  general,
  newProjectPending,      // For teachers when a project needs approval
  projectReviewed,        // For students when teacher reviews their project
  teacherApprovalRequest; // For admins when a teacher requests approval

  String get displayName {
    switch (this) {
      case NotificationType.projectApproved:
        return 'Project Approved';
      case NotificationType.projectRejected:
        return 'Project Rejected';
      case NotificationType.projectNeedsRevision:
        return 'Project Revision';
      case NotificationType.projectFeatured:
        return 'Project Featured';
      case NotificationType.newReview:
        return 'New Review';
      case NotificationType.accountApproved:
        return 'Account Approved';
      case NotificationType.accountRejected:
        return 'Account Rejected';
      case NotificationType.systemMessage:
        return 'System Message';
      case NotificationType.general:
        return 'General';
      case NotificationType.newProjectPending:
        return 'New Project for Review';
      case NotificationType.projectReviewed:
        return 'Project Reviewed';
      case NotificationType.teacherApprovalRequest:
        return 'Teacher Approval Request';
    }
  }

  String get icon {
    switch (this) {
      case NotificationType.projectApproved:
        return '✅';
      case NotificationType.projectRejected:
        return '❌';
      case NotificationType.projectNeedsRevision:
        return '🔄';
      case NotificationType.projectFeatured:
        return '⭐';
      case NotificationType.newReview:
        return '💬';
      case NotificationType.accountApproved:
        return '🎉';
      case NotificationType.accountRejected:
        return '⚠️';
      case NotificationType.systemMessage:
        return '🔔';
      case NotificationType.general:
        return '📢';
      case NotificationType.newProjectPending:
        return '📝';
      case NotificationType.projectReviewed:
        return '✍️';
      case NotificationType.teacherApprovalRequest:
        return '👨‍🏫';
    }
  }
}
