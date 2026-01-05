import 'package:flutter/material.dart';
import '../mvc/controllers/notification_service.dart' as notification_service;

class NotificationTestScreen extends StatelessWidget {
  const NotificationTestScreen({super.key});

  Future<void> _testNotification(BuildContext context) async {
    final notificationService = notification_service.NotificationService();
    
    // Check if notifications are enabled
    final enabled = await notificationService.areNotificationsEnabled();
    
    if (!enabled) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enable notifications in device settings!'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }
    
    // Create a test notification
    final testNotification = notification_service.Notification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: 'test',
      title: 'Test Notification',
      message: 'This is a test notification from BAUST Project Showcase',
      type: notification_service.NotificationType.general,
      createdAt: DateTime.now(),
      isRead: false,
    );
    
    // Show it
    await notificationService.showLocalNotification(testNotification);
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test notification sent! Check your notification panel.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Test'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.notifications_active,
              size: 100,
              color: Colors.blue,
            ),
            const SizedBox(height: 32),
            const Text(
              'Test System Notifications',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Tap the button below to send a test notification to your phone\'s notification panel.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => _testNotification(context),
              icon: const Icon(Icons.send),
              label: const Text('Send Test Notification'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
