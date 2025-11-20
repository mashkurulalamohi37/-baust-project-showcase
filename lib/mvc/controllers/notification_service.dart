import 'package:flutter/foundation.dart';
import '../models/project.dart';
import '../models/user.dart';
import 'firestore_service.dart';

class NotificationService extends ChangeNotifier {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final List<Notification> _notifications = [];
  bool _isLoading = false;

  List<Notification> get notifications => List.unmodifiable(_notifications);
  bool get isLoading => _isLoading;

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // Load notifications for a user
  Future<void> loadUserNotifications(String userId) async {
    _setLoading(true);
    
    try {
      final notificationsData = await FirestoreService.getNotifications(userId);
      final notifications = notificationsData.map((data) => Notification.fromMap({
        'id': data['id'].toString(),
        'userId': data['user_id'],
        'title': data['title'],
        'message': data['message'],
        'type': data['type'],
        'projectId': data['project_id'],
        'actionData': null,
        'createdAt': data['created_at'],
        'isRead': data['is_read'] ?? false,
      })).toList();
      _notifications.clear();
      _notifications.addAll(notifications);
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading notifications: $e');
      _setLoading(false);
    }
  }

  // Send notification to a user
  Future<bool> sendNotification({
    required String userId,
    required String title,
    required String message,
    required NotificationType type,
    String? projectId,
    String? actionData,
  }) async {
    try {
      final notification = Notification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId,
        title: title,
        message: message,
        type: type,
        projectId: projectId,
        actionData: actionData,
        createdAt: DateTime.now(),
        isRead: false,
      );

      await FirestoreService.saveNotification(
        userId: notification.userId,
        title: notification.title,
        message: notification.message,
        type: notification.type.name,
        projectId: notification.projectId,
      );
      
      // Add to local list if it's for the current user
      _notifications.insert(0, notification);
      notifyListeners();
      
      return true;
    } catch (e) {
      debugPrint('Error sending notification: $e');
      return false;
    }
  }

  // Mark notification as read
  Future<bool> markAsRead(String notificationId) async {
    try {
      await FirestoreService.markNotificationAsRead(notificationId);
      
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        _notifications[index] = _notifications[index].copyWith(isRead: true);
        notifyListeners();
      }
      
      return true;
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
      return false;
    }
  }

  // Mark all notifications as read
  Future<bool> markAllAsRead(String userId) async {
    try {
      // Mark all notifications as read in Firestore
      final notificationsData = await FirestoreService.getNotifications(userId);
      for (final notification in notificationsData) {
        if (!(notification['is_read'] ?? false)) {
          final id = notification['id'];
          await FirestoreService.markNotificationAsRead(id is String ? id : id.toString());
        }
      }
      
      for (int i = 0; i < _notifications.length; i++) {
        _notifications[i] = _notifications[i].copyWith(isRead: true);
      }
      notifyListeners();
      
      return true;
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
      return false;
    }
  }

  // Delete notification
  Future<bool> deleteNotification(String notificationId) async {
    try {
      // Note: Firestore doesn't have a delete notification method, so we'll just remove from local list
      // You can add delete functionality to FirestoreService if needed
      
      _notifications.removeWhere((n) => n.id == notificationId);
      notifyListeners();
      
      return true;
    } catch (e) {
      debugPrint('Error deleting notification: $e');
      return false;
    }
  }

  // Get unread count
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  // Project-related notifications
  Future<bool> notifyProjectApproved(String userId, Project project) async {
    return await sendNotification(
      userId: userId,
      title: 'Project Approved! 🎉',
      message: 'Your project "${project.title}" has been approved and is now visible to everyone.',
      type: NotificationType.projectApproved,
      projectId: project.id,
    );
  }

  Future<bool> notifyProjectRejected(String userId, Project project) async {
    return await sendNotification(
      userId: userId,
      title: 'Project Feedback',
      message: 'Your project "${project.title}" needs some improvements. Please check the feedback.',
      type: NotificationType.projectRejected,
      projectId: project.id,
    );
  }

  Future<bool> notifyProjectNeedsRevision(String userId, Project project) async {
    return await sendNotification(
      userId: userId,
      title: 'Project Revision Required',
      message: 'Your project "${project.title}" needs revision based on teacher feedback.',
      type: NotificationType.projectNeedsRevision,
      projectId: project.id,
    );
  }

  Future<bool> notifyProjectFeatured(String userId, Project project) async {
    return await sendNotification(
      userId: userId,
      title: 'Project Featured! ⭐',
      message: 'Congratulations! Your project "${project.title}" has been featured on the homepage.',
      type: NotificationType.projectFeatured,
      projectId: project.id,
    );
  }

  Future<bool> notifyNewReview(String userId, Project project, String reviewerName) async {
    return await sendNotification(
      userId: userId,
      title: 'New Review',
      message: '$reviewerName reviewed your project "${project.title}".',
      type: NotificationType.newReview,
      projectId: project.id,
    );
  }

  Future<bool> notifyTeacherApproved(String userId) async {
    return await sendNotification(
      userId: userId,
      title: 'Account Approved! ✅',
      message: 'Your teacher account has been approved. You can now review and rate projects.',
      type: NotificationType.accountApproved,
    );
  }

  Future<bool> notifyTeacherRejected(String userId) async {
    return await sendNotification(
      userId: userId,
      title: 'Account Application',
      message: 'Your teacher account application needs additional information. Please contact admin.',
      type: NotificationType.accountRejected,
    );
  }
}

// Notification model
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
    return Notification(
      id: map['id'],
      userId: map['userId'],
      title: map['title'],
      message: map['message'],
      type: NotificationType.values.firstWhere((e) => e.name == map['type']),
      projectId: map['projectId'],
      actionData: map['actionData'],
      createdAt: DateTime.parse(map['createdAt']),
      isRead: map['isRead'] ?? false,
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
  general;

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
    }
  }
}
