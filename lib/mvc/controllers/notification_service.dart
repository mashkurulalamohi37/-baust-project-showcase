import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/project.dart';
import '../models/user.dart';
import 'firestore_service.dart';
import 'auth_service.dart';

class NotificationService extends ChangeNotifier {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final List<Notification> _notifications = [];
  bool _isLoading = false;
  StreamSubscription? _notificationsSubscription;
  String? _currentListeningUserId;
  
  // Local Notifications
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final Set<String> _processedIds = {};
  bool _isInitialized = false;

  List<Notification> get notifications => List.unmodifiable(_notifications);
  bool get isLoading => _isLoading;

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // Initialize local notifications
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('NotificationService: Already initialized');
      return;
    }

    debugPrint('NotificationService: Starting initialization...');

    // Request permissions (Android/iOS only)
    if (!kIsWeb) {
      final permissionStatus = await Permission.notification.request();
      debugPrint('NotificationService: Permission status: $permissionStatus');
      
      if (permissionStatus.isDenied || permissionStatus.isPermanentlyDenied) {
        debugPrint('NotificationService: WARNING - Notification permission denied!');
        debugPrint('NotificationService: User needs to enable notifications in device settings');
      }
    } else {
      debugPrint('NotificationService: Skipping permission request on Web');
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    final initialized = await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('Notification tapped: ${response.payload}');
      },
    );

    debugPrint('NotificationService: Plugin initialization result: $initialized');

    _isInitialized = true;
    debugPrint('NotificationService: Local notifications initialized successfully');
  }

  // Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    final status = await Permission.notification.status;
    return status.isGranted;
  }

  // Show a system notification
  Future<void> showLocalNotification(Notification notification) async {
    try {
      debugPrint('NotificationService: Attempting to show local notification: ${notification.title}');
      
      // Respect user's notification settings from profile
      final currentUser = AuthService().currentUser;
      if (currentUser == null || !currentUser.notificationsEnabled) {
        debugPrint('NotificationService: Skipping local notification - Disabled by user');
        return;
      }

      debugPrint('NotificationService: User has notifications enabled, proceeding...');
      debugPrint('NotificationService: Initialized status: $_isInitialized');

      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'project_showcase_channel',
        'Project Showcase Notifications',
        channelDescription: 'Notifications for project approvals, reviews and updates',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        playSound: true,
        enableVibration: true,
      );
      
      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
      );

      debugPrint('NotificationService: Calling _localNotifications.show()...');
      await _localNotifications.show(
        notification.id.hashCode,
        notification.title,
        notification.message,
        platformChannelSpecifics,
        payload: notification.projectId,
      );
      debugPrint('NotificationService: Local notification shown successfully!');
    } catch (e, stackTrace) {
      debugPrint('NotificationService: ERROR showing local notification: $e');
      debugPrint('NotificationService: Stack trace: $stackTrace');
    }
  }

  // Start listening to real-time notifications
  void startListening(String userId) {
    if (_currentListeningUserId == userId && _notificationsSubscription != null) {
      return; // Already listening to this user
    }

    _stopListening();
    _currentListeningUserId = userId;
    
    debugPrint('NotificationService: Starting real-time listener for user $userId');
    
    _notificationsSubscription = FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .listen((snapshot) {
          final List<Notification> newNotifications = snapshot.docs.map((doc) {
            final data = doc.data();
            if (data['id'] == null) data['id'] = doc.id;
            return Notification.fromMap(data);
          }).toList();
          
          newNotifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          
          // Check for brand new notifications to show system alert
          if (_notifications.isNotEmpty || _processedIds.isNotEmpty) {
            for (var notification in newNotifications) {
              if (!_processedIds.contains(notification.id) && !notification.isRead) {
                // This is a new unread notification
                showLocalNotification(notification);
                _processedIds.add(notification.id);
              }
            }
          } else {
            // First load: just populate processed IDs so we don't spam old ones
            for (var notification in newNotifications) {
              _processedIds.add(notification.id);
            }
          }
          
          _notifications.clear();
          _notifications.addAll(newNotifications);
          notifyListeners();
          debugPrint('NotificationService: Current unread count: $unreadCount');
          debugPrint('NotificationService: Total notifications: ${_notifications.length}');
        }, onError: (error) {
          debugPrint('NotificationService: Stream error: $error');
        });
  }

  // Stop listening and clear data
  void clearNotifications() {
    _stopListening();
    _notifications.clear();
    _processedIds.clear();
    notifyListeners();
  }

  void _stopListening() {
    _notificationsSubscription?.cancel();
    _notificationsSubscription = null;
    _currentListeningUserId = null;
  }

  @override
  void dispose() {
    _stopListening();
    super.dispose();
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
      // Check if user has notifications enabled
      final user = await FirestoreService.getUserById(userId);
      if (user == null || !user.notificationsEnabled) {
        debugPrint('Notification not sent: User $userId has notifications disabled');
        return false;
      }

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
      debugPrint('NotificationService: Marking notification $notificationId as read');
      
      await FirestoreService.markNotificationAsRead(notificationId);
      
      debugPrint('NotificationService: Firestore updated successfully for $notificationId');
      
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        _notifications[index] = _notifications[index].copyWith(isRead: true);
        notifyListeners();
        debugPrint('NotificationService: Local notification list updated. Unread count: $unreadCount');
      } else {
        debugPrint('NotificationService: WARNING - Notification $notificationId not found in local list');
      }
      
      return true;
    } catch (e) {
      debugPrint('NotificationService: ERROR marking notification as read: $e');
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

  // New notification methods for the three scenarios

  /// Notify all approved teachers when a new project is submitted for approval
  Future<bool> notifyTeachersNewProjectPending(Project project) async {
    try {
      // Get all approved teachers
      final teachers = await FirestoreService.getAllUsers();
      final approvedTeachers = teachers.where(
        (user) => user.role == UserRole.teacher && user.isApproved,
      ).toList();

      // Send notification to each teacher
      for (final teacher in approvedTeachers) {
        await sendNotification(
          userId: teacher.id,
          title: 'New Project for Review 📝',
          message: 'A new project "${project.title}" by ${project.authorName} is pending approval.',
          type: NotificationType.newProjectPending,
          projectId: project.id,
        );
      }

      return true;
    } catch (e) {
      debugPrint('Error notifying teachers of new project: $e');
      return false;
    }
  }

  /// Notify student when their project is reviewed/approved/rejected by a teacher
  Future<bool> notifyStudentProjectReviewed(
    String studentId,
    Project project,
    String teacherName,
    ProjectStatus newStatus,
  ) async {
    String title = '';
    String message = '';

    switch (newStatus) {
      case ProjectStatus.approved:
        title = 'Project Approved! 🎉';
        message = 'Your project "${project.title}" has been approved by $teacherName and is now visible to everyone.';
        break;
      case ProjectStatus.rejected:
        title = 'Project Feedback ❌';
        message = 'Your project "${project.title}" was reviewed by $teacherName. Please check the feedback and make improvements.';
        break;
      case ProjectStatus.needsRevision:
        title = 'Project Needs Revision 🔄';
        message = 'Your project "${project.title}" needs revision based on feedback from $teacherName.';
        break;
      case ProjectStatus.featured:
        title = 'Project Featured! ⭐';
        message = 'Congratulations! Your project "${project.title}" has been featured by $teacherName!';
        break;
      default:
        title = 'Project Status Updated';
        message = 'Your project "${project.title}" was reviewed by $teacherName.';
    }

    return await sendNotification(
      userId: studentId,
      title: title,
      message: message,
      type: NotificationType.projectReviewed,
      projectId: project.id,
    );
  }

  /// Notify all admins when a teacher requests approval
  Future<bool> notifyAdminsTeacherApprovalRequest(User teacher) async {
    try {
      debugPrint('NotificationService: Starting teacher approval notification for ${teacher.name}');
      
      // Get all admins
      final users = await FirestoreService.getAllUsers();
      debugPrint('NotificationService: Retrieved ${users.length} total users from database');
      
      final admins = users.where((user) => user.role == UserRole.admin).toList();
      debugPrint('NotificationService: Found ${admins.length} admin(s)');

      if (admins.isEmpty) {
        debugPrint('NotificationService: WARNING - No admins found in database!');
        return false;
      }

      // Send notification to each admin
      int successCount = 0;
      for (final admin in admins) {
        debugPrint('NotificationService: Sending notification to admin: ${admin.name} (${admin.email})');
        debugPrint('NotificationService: Admin notifications enabled: ${admin.notificationsEnabled}');
        
        final success = await sendNotification(
          userId: admin.id,
          title: 'New Teacher Approval Request 👨‍🏫',
          message: '${teacher.name} (${teacher.email}) has requested teacher account approval.',
          type: NotificationType.teacherApprovalRequest,
        );
        
        if (success) {
          successCount++;
          debugPrint('NotificationService: ✅ Notification sent to ${admin.name}');
        } else {
          debugPrint('NotificationService: ❌ Failed to send notification to ${admin.name}');
        }
      }

      debugPrint('NotificationService: Sent ${successCount}/${admins.length} notifications successfully');
      return successCount > 0;
    } catch (e) {
      debugPrint('NotificationService: ❌ ERROR notifying admins of teacher approval request: $e');
      debugPrint('NotificationService: Stack trace: ${StackTrace.current}');
      return false;
    }
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
