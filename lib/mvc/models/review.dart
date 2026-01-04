class Review {
  final String id;
  final String projectId;
  final String reviewerId;
  final String reviewerName;
  final String? reviewerDesignation;
  final double rating;
  final String comment;
  final DateTime createdAt;

  Review({
    required this.id,
    required this.projectId,
    required this.reviewerId,
    required this.reviewerName,
    this.reviewerDesignation,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'projectId': projectId,
      'reviewerId': reviewerId,
      'reviewerName': reviewerName,
      'reviewerDesignation': reviewerDesignation,
      'rating': rating,
      'comment': comment,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Review.fromMap(Map<String, dynamic> map) {
    return Review(
      id: map['id'] ?? '',
      projectId: map['projectId'] ?? '',
      reviewerId: map['reviewerId'] ?? '',
      reviewerName: map['reviewerName'] ?? '',
      reviewerDesignation: map['reviewerDesignation'],
      rating: (map['rating'] ?? 0.0).toDouble(),
      comment: map['comment'] ?? '',
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Review copyWith({
    String? id,
    String? projectId,
    String? reviewerId,
    String? reviewerName,
    String? reviewerDesignation,
    double? rating,
    String? comment,
    DateTime? createdAt,
  }) {
    return Review(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      reviewerId: reviewerId ?? this.reviewerId,
      reviewerName: reviewerName ?? this.reviewerName,
      reviewerDesignation: reviewerDesignation ?? this.reviewerDesignation,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
