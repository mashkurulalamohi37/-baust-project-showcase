import 'review.dart';
import 'feedback.dart';

class Project {
  final String id;
  final String title;
  final String abstract;
  final String authorId;
  final String authorName;
  final ProjectCategory category;
  final int year;
  final String? supervisor;
  final DateTime createdAt;
  final DateTime updatedAt;
  final ProjectStatus status;
  final double rating;
  final int reviewCount;
  final List<String> imageUrls;
  final String? pdfUrl;
  final String? githubUrl;
  final List<String> tags;
  final bool isFeatured;
  final String? facultyId;
  final String? facultyName;
  final int version;
  final String? parentProjectId;
  final List<ProjectFeedback> feedback;
  final List<ProjectVersion> versions;
  final ProjectType projectType;

  const Project({
    required this.id,
    required this.title,
    required this.abstract,
    required this.authorId,
    required this.authorName,
    required this.category,
    required this.year,
    this.supervisor,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
    this.rating = 0.0,
    this.reviewCount = 0,
    this.imageUrls = const [],
    this.pdfUrl,
    this.githubUrl,
    this.tags = const [],
    this.isFeatured = false,
    this.facultyId,
    this.facultyName,
    this.version = 1,
    this.parentProjectId,
    this.feedback = const [],
    this.versions = const [],
    this.projectType = ProjectType.project,
  });

  Project copyWith({
    String? id,
    String? title,
    String? abstract,
    String? authorId,
    String? authorName,
    ProjectCategory? category,
    int? year,
    String? supervisor,
    DateTime? createdAt,
    DateTime? updatedAt,
    ProjectStatus? status,
    double? rating,
    int? reviewCount,
    List<String>? imageUrls,
    String? pdfUrl,
    String? githubUrl,
    List<String>? tags,
    bool? isFeatured,
    String? facultyId,
    String? facultyName,
    int? version,
    String? parentProjectId,
    List<ProjectFeedback>? feedback,
    List<ProjectVersion>? versions,
    ProjectType? projectType,
  }) {
    return Project(
      id: id ?? this.id,
      title: title ?? this.title,
      abstract: abstract ?? this.abstract,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      category: category ?? this.category,
      year: year ?? this.year,
      supervisor: supervisor ?? this.supervisor,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      imageUrls: imageUrls ?? this.imageUrls,
      pdfUrl: pdfUrl ?? this.pdfUrl,
      githubUrl: githubUrl ?? this.githubUrl,
      tags: tags ?? this.tags,
      isFeatured: isFeatured ?? this.isFeatured,
      facultyId: facultyId ?? this.facultyId,
      facultyName: facultyName ?? this.facultyName,
      version: version ?? this.version,
      parentProjectId: parentProjectId ?? this.parentProjectId,
      feedback: feedback ?? this.feedback,
      versions: versions ?? this.versions,
      projectType: projectType ?? this.projectType,
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
      'supervisor': supervisor,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'status': status.name,
      'rating': rating,
      'reviewCount': reviewCount,
      'imageUrls': imageUrls,
      'pdfUrl': pdfUrl,
      'githubUrl': githubUrl,
      'tags': tags,
      'isFeatured': isFeatured,
      'facultyId': facultyId,
      'facultyName': facultyName,
      'version': version,
      'parentProjectId': parentProjectId,
      'feedback': feedback.map((f) => f.toMap()).toList(),
      'versions': versions.map((v) => v.toMap()).toList(),
      'projectType': projectType.name,
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

enum ProjectType {
  project,
  thesis,
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

extension ProjectTypeExtension on ProjectType {
  String get displayName {
    switch (this) {
      case ProjectType.project:
        return 'Project';
      case ProjectType.thesis:
        return 'Thesis';
    }
  }
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

