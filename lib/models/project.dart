class Project {
  final String id;
  final String title;
  final String abstract;
  final String authorId;
  final String authorName;
  final ProjectCategory category;
  final int year;
  final DateTime createdAt;
  final DateTime updatedAt;
  final ProjectStatus status;
  final double rating;
  final int reviewCount;
  final List<String> imageUrls;
  final String? videoUrl;
  final String? pdfUrl;
  final String? githubUrl;
  final List<String> tags;
  final bool isFeatured;
  final String? facultyId;
  final String? facultyName;
  final int version;
  final String? parentProjectId;
  final ProjectSubmissionType submissionType;
  final AcademicCourse? academicCourse;
  final String? assistantTeacherId;
  final String? rejectionReason;
  final List<ProjectFeedback> feedback;
  final List<ProjectVersion> versions;

  const Project({
    required this.id,
    required this.title,
    required this.abstract,
    required this.authorId,
    required this.authorName,
    required this.category,
    required this.year,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
    this.rating = 0.0,
    this.reviewCount = 0,
    this.imageUrls = const [],
    this.videoUrl,
    this.pdfUrl,
    this.githubUrl,
    this.tags = const [],
    this.isFeatured = false,
    this.facultyId,
    this.facultyName,
    this.version = 1,
    this.parentProjectId,
    this.submissionType = ProjectSubmissionType.projectShowcase,
    this.academicCourse,
    this.assistantTeacherId,
    this.rejectionReason,
    this.feedback = const [],
    this.versions = const [],
  });

  Project copyWith({
    String? id,
    String? title,
    String? abstract,
    String? authorId,
    String? authorName,
    ProjectCategory? category,
    int? year,
    DateTime? createdAt,
    DateTime? updatedAt,
    ProjectStatus? status,
    double? rating,
    int? reviewCount,
    List<String>? imageUrls,
    String? videoUrl,
    String? pdfUrl,
    String? githubUrl,
    List<String>? tags,
    bool? isFeatured,
    String? facultyId,
    String? facultyName,
    int? version,
    String? parentProjectId,
    String? rejectionReason,
    List<ProjectFeedback>? feedback,
    List<ProjectVersion>? versions,
  }) {
    return Project(
      id: id ?? this.id,
      title: title ?? this.title,
      abstract: abstract ?? this.abstract,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      category: category ?? this.category,
      year: year ?? this.year,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      imageUrls: imageUrls ?? this.imageUrls,
      videoUrl: videoUrl ?? this.videoUrl,
      pdfUrl: pdfUrl ?? this.pdfUrl,
      githubUrl: githubUrl ?? this.githubUrl,
      tags: tags ?? this.tags,
      isFeatured: isFeatured ?? this.isFeatured,
      facultyId: facultyId ?? this.facultyId,
      facultyName: facultyName ?? this.facultyName,
      version: version ?? this.version,
      parentProjectId: parentProjectId ?? this.parentProjectId,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      feedback: feedback ?? this.feedback,
      versions: versions ?? this.versions,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'abstract': abstract,
      'authorId': authorId,
      'authorName': authorName,
      'category': category.name,
      'year': year,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'status': status.name,
      'rating': rating,
      'reviewCount': reviewCount,
      'imageUrls': imageUrls,
      'videoUrl': videoUrl,
      'pdfUrl': pdfUrl,
      'githubUrl': githubUrl,
      'tags': tags,
      'isFeatured': isFeatured,
      'facultyId': facultyId,
      'facultyName': facultyName,
      'version': version,
      'parentProjectId': parentProjectId,
      'rejectionReason': rejectionReason,
      'feedback': feedback.map((f) => f.toMap()).toList(),
      'versions': versions.map((v) => v.toMap()).toList(),
    };
  }
}

enum ProjectCategory {
  ai,
  iot,
  marine,
  business,
  engineering,
  blockchain,
  mobile,
  energy,
  ar,
  security,
  web,
  other,
}

enum ProjectStatus {
  draft,
  pending,
  approved,
  rejected,
  featured,
  needsRevision,
  resubmitted,
}

extension ProjectCategoryExtension on ProjectCategory {
  String get displayName {
    switch (this) {
      case ProjectCategory.ai:
        return 'AI & Machine Learning';
      case ProjectCategory.iot:
        return 'IoT & Embedded Systems';
      case ProjectCategory.marine:
        return 'Marine Science';
      case ProjectCategory.business:
        return 'Business & Finance';
      case ProjectCategory.engineering:
        return 'Engineering';
      case ProjectCategory.blockchain:
        return 'Blockchain & Cryptocurrency';
      case ProjectCategory.mobile:
        return 'Mobile Development';
      case ProjectCategory.energy:
        return 'Energy & Sustainability';
      case ProjectCategory.ar:
        return 'AR/VR & Mixed Reality';
      case ProjectCategory.security:
        return 'Cybersecurity';
      case ProjectCategory.web:
        return 'Web Development';
      case ProjectCategory.other:
        return 'Other';
    }
  }
}

extension ProjectStatusExtension on ProjectStatus {
  String get displayName {
    switch (this) {
      case ProjectStatus.draft:
        return 'Draft';
      case ProjectStatus.pending:
        return 'Pending Review';
      case ProjectStatus.approved:
        return 'Approved';
      case ProjectStatus.rejected:
        return 'Rejected';
      case ProjectStatus.featured:
        return 'Featured';
      case ProjectStatus.needsRevision:
        return 'Needs Revision';
      case ProjectStatus.resubmitted:
        return 'Resubmitted';
    }
  }
}

class Review {
  final String id;
  final String projectId;
  final String reviewerId;
  final String reviewerName;
  final double rating;
  final String comment;
  final DateTime createdAt;

  const Review({
    required this.id,
    required this.projectId,
    required this.reviewerId,
    required this.reviewerName,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });
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

  const ProjectFeedback({
    required this.id,
    required this.projectId,
    required this.reviewerId,
    required this.reviewerName,
    required this.comment,
    required this.type,
    required this.createdAt,
    this.isResolved = false,
  });

  ProjectFeedback copyWith({
    String? id,
    String? projectId,
    String? reviewerId,
    String? reviewerName,
    String? comment,
    FeedbackType? type,
    DateTime? createdAt,
    bool? isResolved,
  }) {
    return ProjectFeedback(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      reviewerId: reviewerId ?? this.reviewerId,
      reviewerName: reviewerName ?? this.reviewerName,
      comment: comment ?? this.comment,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      isResolved: isResolved ?? this.isResolved,
    );
  }

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
}

class ProjectVersion {
  final String id;
  final String projectId;
  final int versionNumber;
  final String title;
  final String abstract;
  final List<String> imageUrls;
  final String? pdfUrl;
  final String? githubUrl;
  final DateTime createdAt;
  final String? changeDescription;

  const ProjectVersion({
    required this.id,
    required this.projectId,
    required this.versionNumber,
    required this.title,
    required this.abstract,
    required this.imageUrls,
    this.pdfUrl,
    this.githubUrl,
    required this.createdAt,
    this.changeDescription,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'projectId': projectId,
      'versionNumber': versionNumber,
      'title': title,
      'abstract': abstract,
      'imageUrls': imageUrls,
      'pdfUrl': pdfUrl,
      'githubUrl': githubUrl,
      'createdAt': createdAt.toIso8601String(),
      'changeDescription': changeDescription,
    };
  }
}

enum FeedbackType {
  general,
  improvement,
  critical,
  approval,
}

extension FeedbackTypeExtension on FeedbackType {
  String get displayName {
    switch (this) {
      case FeedbackType.general:
        return 'General Feedback';
      case FeedbackType.improvement:
        return 'Needs Improvement';
      case FeedbackType.critical:
        return 'Critical Issues';
      case FeedbackType.approval:
        return 'Approval';
    }
  }
  
  String get icon {
    switch (this) {
      case FeedbackType.general:
        return '💬';
      case FeedbackType.improvement:
        return '🔧';
      case FeedbackType.critical:
        return '⚠️';
      case FeedbackType.approval:
        return '✅';
    }
  }
}

enum ProjectSubmissionType {
  projectShowcase,
  academic,
}

extension ProjectSubmissionTypeExtension on ProjectSubmissionType {
  String get displayName {
    switch (this) {
      case ProjectSubmissionType.projectShowcase:
        return 'Project Showcase';
      case ProjectSubmissionType.academic:
        return 'Academic';
    }
  }
}

enum AcademicCourse {
  softwareDevelopmentProject1,
  softwareDevelopmentProject2,
  softwareEngineeringSessional,
  databaseManagementSystemsSessional,
  webEngineeringSessional,
  machineLearningSessional,
  artificialIntelligenceSessional,
}

extension AcademicCourseExtension on AcademicCourse {
  String get displayName {
    switch (this) {
      case AcademicCourse.softwareDevelopmentProject1:
        return 'Software Development Project-I';
      case AcademicCourse.softwareDevelopmentProject2:
        return 'Software Development Project-II';
      case AcademicCourse.softwareEngineeringSessional:
        return 'Software Engineering Sessional';
      case AcademicCourse.databaseManagementSystemsSessional:
        return 'Database Management Systems Sessional';
      case AcademicCourse.webEngineeringSessional:
        return 'Web Engineering Sessional';
      case AcademicCourse.machineLearningSessional:
        return 'Machine Learning Sessional';
      case AcademicCourse.artificialIntelligenceSessional:
        return 'Artificial Intelligence Sessional';
    }
  }
}
