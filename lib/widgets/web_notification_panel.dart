import 'package:flutter/material.dart';
import '../mvc/controllers/notification_service.dart' as notification_service;
import '../mvc/controllers/auth_service.dart';
import '../mvc/controllers/project_service.dart';
import '../mvc/controllers/firestore_service.dart';
import '../screens/project_detail.dart';
import '../screens/profile_settings_screen.dart';

class WebNotificationPanel extends StatefulWidget {
  final notification_service.NotificationService notificationService;
  final VoidCallback onViewAll;

  const WebNotificationPanel({
    super.key,
    required this.notificationService,
    required this.onViewAll,
  });

  @override
  State<WebNotificationPanel> createState() => _WebNotificationPanelState();
}

class _WebNotificationPanelState extends State<WebNotificationPanel> {
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        popupMenuTheme: PopupMenuThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          surfaceTintColor: Theme.of(context).colorScheme.surface,
        ),
      ),
      child: Badge(
        label: Text('${widget.notificationService.unreadCount}'),
        isLabelVisible: widget.notificationService.unreadCount > 0,
        child: PopupMenuButton<String>(
          tooltip: 'Notifications',
          icon: const Icon(Icons.notifications_outlined, size: 28),
          offset: const Offset(0, 45), // Push down below app bar
          constraints: const BoxConstraints(
            minWidth: 360,
            maxWidth: 360,
            maxHeight: 600,
          ),
          onSelected: (value) {
            if (value == 'view_all') {
              widget.onViewAll();
            }
          },
          itemBuilder: (context) {
            final notifications = widget.notificationService.notifications;
            
            return [
              // Header (Non-interactive item containing interactive button)
              PopupMenuItem<String>(
                enabled: false,
                padding: EdgeInsets.zero,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Notifications',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.done_all, size: 20),
                        onPressed: () async {
                          final userId = _authService.currentUser?.id;
                          if (userId != null) {
                            await widget.notificationService.markAllAsRead(userId);
                            if (mounted) Navigator.pop(context); // Close menu on action
                          }
                        },
                        tooltip: 'Mark all as read',
                      ),
                    ],
                  ),
                ),
              ),
              
              const PopupMenuDivider(),
              
              // Empty State
              if (notifications.isEmpty)
                PopupMenuItem<String>(
                  enabled: false,
                  height: 150,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_off, size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No notifications yet',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Notification List
              ...notifications.take(10).map((notification) {
                return PopupMenuItem<String>(
                  padding: EdgeInsets.zero,
                  onTap: () {
                    // We must handle tap manually here if we want custom behavior before closing
                    // But PopupMenu automatically closes.
                    // handling tap is done via 'onSelected'? 
                    // No, 'onSelected' gives us the value.
                    // We'll process the value in onSelected, but we need unique values.
                    // Actually, let's just handle logic right here using a Future.delayed to allow menu to close?
                    // Or execute immediately.
                     Future.delayed(Duration.zero, () {
                       _handleNotificationTap(context, notification);
                     });
                  },
                  child: Container(
                    color: notification.isRead 
                        ? Colors.transparent 
                        : Theme.of(context).colorScheme.primaryContainer.withOpacity(0.1),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Icon
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _getNotificationColor(context, notification.type).withOpacity(0.2),
                          ),
                          child: Icon(
                            _getNotificationIcon(notification.type),
                            color: _getNotificationColor(context, notification.type),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Text
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                notification.title,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                notification.message,
                                style: Theme.of(context).textTheme.bodySmall,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatDateTime(notification.createdAt),
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Dot
                        if (!notification.isRead)
                          Container(
                            margin: const EdgeInsets.only(top: 8, left: 8),
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }),

              const PopupMenuDivider(),
              
              // Footer
              PopupMenuItem<String>(
                value: 'view_all',
                child: Center(
                  child: Text(
                    'See previous notifications',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ];
          },
        ),
      ),
    );
  }

  void _handleNotificationTap(BuildContext context, notification_service.Notification notification) async {
    // Mark as read
    if (!notification.isRead) {
      widget.notificationService.markAsRead(notification.id);
    }

    // Handle navigation logic (copied from NotificationsScreen to ensure consistency)
    final projectService = ProjectService();
    
    switch (notification.type) {
      case notification_service.NotificationType.projectApproved:
      case notification_service.NotificationType.projectRejected:
      case notification_service.NotificationType.projectNeedsRevision:
      case notification_service.NotificationType.projectFeatured:
      case notification_service.NotificationType.newReview:
      case notification_service.NotificationType.newProjectPending:
      case notification_service.NotificationType.projectReviewed:
        if (notification.projectId != null) {
          // Show loading snackbar or indicator could be nice
          final project = await FirestoreService.getProjectById(notification.projectId!);
          if (project != null && mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ProjectDetailScreen(
                  project: project,
                  projectService: projectService,
                  authService: _authService,
                ),
              ),
            );
          }
        }
        break;
      case notification_service.NotificationType.accountApproved:
      case notification_service.NotificationType.accountRejected:
      case notification_service.NotificationType.teacherApprovalRequest:
        if (mounted) {
           Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const ProfileSettingsScreen()),
          );
        }
        break;
      default:
        break;
    }
  }

  Color _getNotificationColor(BuildContext context, notification_service.NotificationType type) {
    switch (type) {
      case notification_service.NotificationType.projectApproved:
      case notification_service.NotificationType.accountApproved:
        return Colors.green;
      case notification_service.NotificationType.projectRejected:
      case notification_service.NotificationType.accountRejected:
        return Colors.red;
      case notification_service.NotificationType.projectNeedsRevision:
        return Colors.orange;
      case notification_service.NotificationType.projectFeatured:
        return Colors.purple; 
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  IconData _getNotificationIcon(notification_service.NotificationType type) {
    switch (type) {
      case notification_service.NotificationType.projectApproved:
      case notification_service.NotificationType.accountApproved:
        return Icons.check_circle;
      case notification_service.NotificationType.projectRejected:
      case notification_service.NotificationType.accountRejected:
        return Icons.cancel;
      case notification_service.NotificationType.projectNeedsRevision:
        return Icons.edit_note;
      case notification_service.NotificationType.projectFeatured:
        return Icons.star;
      case notification_service.NotificationType.newReview:
        return Icons.rate_review;
      case notification_service.NotificationType.newProjectPending:
        return Icons.upload_file;
      default:
        return Icons.notifications;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
