import 'package:flutter/material.dart';
import '../mvc/models/notification.dart' as model;
import 'package:timeago/timeago.dart' as timeago;

class NotificationDropdown extends StatelessWidget {
  final List<model.Notification> notifications;
  final Function(String) onNotificationTap;
  final VoidCallback onMarkAllRead;
  final VoidCallback onClose;

  const NotificationDropdown({
    super.key,
    required this.notifications,
    required this.onNotificationTap,
    required this.onMarkAllRead,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return TapRegion(
      onTapOutside: (_) => onClose(),
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 400,
          constraints: const BoxConstraints(maxHeight: 600),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withOpacity(0.5),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: theme.colorScheme.outlineVariant.withOpacity(0.3),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      'Notifications',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: onMarkAllRead,
                      child: Text(
                        'Mark all read',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Notifications List
              Flexible(
                child: notifications.isEmpty
                    ? _buildEmptyState(theme)
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: notifications.length,
                        padding: EdgeInsets.zero,
                        itemBuilder: (context, index) {
                          return _buildNotificationItem(
                            context,
                            notifications[index],
                            theme,
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_none,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No notifications',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationItem(
    BuildContext context,
    model.Notification notification,
    ThemeData theme,
  ) {
    return Material(
      color: notification.isRead
          ? Colors.transparent
          : theme.colorScheme.primaryContainer.withOpacity(0.1),
      child: InkWell(
        onTap: () {
          onNotificationTap(notification.id);
          onClose();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.outlineVariant.withOpacity(0.2),
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _getNotificationColor(notification.type, theme)
                      .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  _getNotificationIcon(notification.type),
                  size: 20,
                  color: _getNotificationColor(notification.type, theme),
                ),
              ),
              const SizedBox(width: 12),
              
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: notification.isRead
                            ? FontWeight.w400
                            : FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (notification.message.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        notification.message,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      timeago.format(notification.createdAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Unread indicator
              if (!notification.isRead)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(left: 8, top: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getNotificationIcon(model.NotificationType type) {
    switch (type) {
      case model.NotificationType.projectApproved:
      case model.NotificationType.accountApproved:
        return Icons.check_circle_outline;
      case model.NotificationType.projectRejected:
      case model.NotificationType.accountRejected:
        return Icons.highlight_off;
      case model.NotificationType.projectNeedsRevision:
        return Icons.loop;
      case model.NotificationType.projectFeatured:
        return Icons.star_border;
      case model.NotificationType.newReview:
      case model.NotificationType.projectReviewed:
        return Icons.rate_review_outlined;
      case model.NotificationType.newProjectPending:
      case model.NotificationType.teacherApprovalRequest:
        return Icons.pending_actions;
      case model.NotificationType.systemMessage:
        return Icons.info_outline;
      case model.NotificationType.general:
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _getNotificationColor(model.NotificationType type, ThemeData theme) {
    switch (type) {
      case model.NotificationType.projectApproved:
      case model.NotificationType.accountApproved:
        return Colors.green;
      case model.NotificationType.projectRejected:
      case model.NotificationType.accountRejected:
        return Colors.red;
      case model.NotificationType.projectNeedsRevision:
        return Colors.orange;
      case model.NotificationType.projectFeatured:
        return Colors.amber;
      case model.NotificationType.newReview:
      case model.NotificationType.projectReviewed:
        return Colors.blue;
      case model.NotificationType.newProjectPending:
      case model.NotificationType.teacherApprovalRequest:
        return Colors.purple;
      case model.NotificationType.systemMessage:
      case model.NotificationType.general:
      default:
        return theme.colorScheme.primary;
    }
  }
}
