enum FeedbackType {
  suggestion,
  issue,
  improvement,
  question,
}

extension FeedbackTypeExtension on FeedbackType {
  String get icon {
    switch (this) {
      case FeedbackType.suggestion:
        return '💡';
      case FeedbackType.issue:
        return '⚠️';
      case FeedbackType.improvement:
        return '📈';
      case FeedbackType.question:
        return '❓';
    }
  }

  String get displayName {
    switch (this) {
      case FeedbackType.suggestion:
        return 'Suggestion';
      case FeedbackType.issue:
        return 'Issue';
      case FeedbackType.improvement:
        return 'Improvement';
      case FeedbackType.question:
        return 'Question';
    }
  }
}

class ProjectFeedback {
  final String id;
  final String projectId;
  final String reviewerId;
  final String reviewerName;
  final String comment;
  final FeedbackType type;
  final DateTime createdAt;
  final bool isResolved;

  ProjectFeedback({
    required this.id,
    required this.projectId,
    required this.reviewerId,
    required this.reviewerName,
    required this.comment,
    required this.type,
    required this.createdAt,
    this.isResolved = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'projectId': projectId,
      'reviewerId': reviewerId,
      'reviewerName': reviewerName,
      'comment': comment,
      'type': type.name,
      'createdAt': createdAt.toIso8601String(),
      'isResolved': isResolved,
    };
  }

  factory ProjectFeedback.fromMap(Map<String, dynamic> map) {
    return ProjectFeedback(
      id: map['id'] ?? '',
      projectId: map['projectId'] ?? '',
      reviewerId: map['reviewerId'] ?? '',
      reviewerName: map['reviewerName'] ?? '',
      comment: map['comment'] ?? '',
      type: FeedbackType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => FeedbackType.suggestion,
      ),
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
      isResolved: map['isResolved'] ?? false,
    );
  }
}
