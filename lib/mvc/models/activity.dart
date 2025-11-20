import 'package:flutter/material.dart';

enum ActivityType {
  projectUploaded,
  projectApproved,
  projectRejected,
  projectFeatured,
  projectNeedsRevision,
  projectReviewed,
  teacherRegistered,
  teacherApproved,
  teacherRejected,
  userCreated,
  projectUpdated,
}

class Activity {
  final String id;
  final ActivityType type;
  final String title;
  final String subtitle;
  final DateTime timestamp;
  final String? userId;
  final String? userName;
  final String? projectId;
  final String? projectTitle;
  final Map<String, dynamic>? metadata;

  const Activity({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.timestamp,
    this.userId,
    this.userName,
    this.projectId,
    this.projectTitle,
    this.metadata,
  });

  Activity copyWith({
    String? id,
    ActivityType? type,
    String? title,
    String? subtitle,
    DateTime? timestamp,
    String? userId,
    String? userName,
    String? projectId,
    String? projectTitle,
    Map<String, dynamic>? metadata,
  }) {
    return Activity(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      timestamp: timestamp ?? this.timestamp,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      projectId: projectId ?? this.projectId,
      projectTitle: projectTitle ?? this.projectTitle,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'title': title,
      'subtitle': subtitle,
      'timestamp': timestamp.toIso8601String(),
      'userId': userId,
      'userName': userName,
      'projectId': projectId,
      'projectTitle': projectTitle,
      'metadata': metadata,
    };
  }

  factory Activity.fromMap(Map<String, dynamic> map, String docId) {
    // Handle timestamp - could be String, Timestamp, or DateTime
    DateTime timestamp;
    try {
      if (map['timestamp'] is String) {
        timestamp = DateTime.parse(map['timestamp']);
      } else if (map['timestamp'] != null) {
        // Handle Firestore Timestamp
        final ts = map['timestamp'];
        if (ts is DateTime) {
          timestamp = ts;
        } else {
          // Try to convert to DateTime
          timestamp = ts.toDate();
        }
      } else {
        timestamp = DateTime.now();
      }
    } catch (e) {
      print('ERROR: Failed to parse timestamp: $e, using current time');
      timestamp = DateTime.now();
    }
    
    return Activity(
      id: docId,
      type: ActivityType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => ActivityType.projectUploaded,
      ),
      title: map['title'] ?? '',
      subtitle: map['subtitle'] ?? '',
      timestamp: timestamp,
      userId: map['userId'],
      userName: map['userName'],
      projectId: map['projectId'],
      projectTitle: map['projectTitle'],
      metadata: map['metadata'] != null ? Map<String, dynamic>.from(map['metadata']) : null,
    );
  }

  IconData get icon {
    switch (type) {
      case ActivityType.projectUploaded:
      case ActivityType.projectUpdated:
        return Icons.upload;
      case ActivityType.projectApproved:
        return Icons.check_circle;
      case ActivityType.projectRejected:
        return Icons.cancel;
      case ActivityType.projectFeatured:
        return Icons.star;
      case ActivityType.projectNeedsRevision:
        return Icons.edit;
      case ActivityType.projectReviewed:
        return Icons.rate_review;
      case ActivityType.teacherRegistered:
      case ActivityType.userCreated:
        return Icons.person_add;
      case ActivityType.teacherApproved:
        return Icons.verified;
      case ActivityType.teacherRejected:
        return Icons.block;
    }
  }

  String getTimeAgo() {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else {
      return 'Just now';
    }
  }
}

