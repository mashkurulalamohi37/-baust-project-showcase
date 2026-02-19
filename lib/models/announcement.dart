enum AnnouncementType {
  info,
  alert,
  deadline,
  event,
}

enum AnnouncementPriority {
  low,
  normal,
  high,
}

class Announcement {
  final String id;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final AnnouncementType type;
  final AnnouncementPriority priority;
  final bool isVisible;
  final String authorId;
  final String authorName;

  const Announcement({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    this.expiresAt,
    this.type = AnnouncementType.info,
    this.priority = AnnouncementPriority.normal,
    this.isVisible = true,
    required this.authorId,
    required this.authorName,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
      'type': type.name,
      'priority': priority.name,
      'isVisible': isVisible,
      'authorId': authorId,
      'authorName': authorName,
    };
  }

  factory Announcement.fromMap(Map<String, dynamic> map) {
    return Announcement(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      expiresAt: map['expiresAt'] != null ? DateTime.tryParse(map['expiresAt']) : null,
      type: AnnouncementType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => AnnouncementType.info,
      ),
      priority: AnnouncementPriority.values.firstWhere(
        (e) => e.name == map['priority'],
        orElse: () => AnnouncementPriority.normal,
      ),
      isVisible: map['isVisible'] ?? true,
      authorId: map['authorId'] ?? '',
      authorName: map['authorName'] ?? '',
    );
  }

  Announcement copyWith({
    String? id,
    String? title,
    String? content,
    DateTime? createdAt,
    DateTime? expiresAt,
    AnnouncementType? type,
    AnnouncementPriority? priority,
    bool? isVisible,
    String? authorId,
    String? authorName,
  }) {
    return Announcement(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      isVisible: isVisible ?? this.isVisible,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
    );
  }
}

extension AnnouncementTypeExtension on AnnouncementType {
  String get displayName {
    switch (this) {
      case AnnouncementType.info:
        return 'Information';
      case AnnouncementType.alert:
        return 'Alert';
      case AnnouncementType.deadline:
        return 'Deadline';
      case AnnouncementType.event:
        return 'Event';
    }
  }
}

extension AnnouncementPriorityExtension on AnnouncementPriority {
  String get displayName {
    switch (this) {
      case AnnouncementPriority.low:
        return 'Low';
      case AnnouncementPriority.normal:
        return 'Normal';
      case AnnouncementPriority.high:
        return 'High';
    }
  }
}
