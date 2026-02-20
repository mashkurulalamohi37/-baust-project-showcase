import 'review.dart';
import 'feedback.dart';
import 'team_member.dart';

class Project {
  final String id;
  final String title;
  final String abstract;
  final String authorId;
  final String authorName;
  final ProjectCategory category;
  final String? customCategory; // For when category is 'Other'
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
  
  // Group/Individual project fields
  final bool isGroupProject; // true for group, false for individual
  final String? groupName; // Only for group projects
  final List<TeamMember> teamMembers; // Empty for individual, filled for group
  final String? driveLink; // Google Drive link for additional resources
  final String? youtubeUrl; // YouTube video link for project demo
  
  // Individual project student details
  final String? studentId; // For individual projects
  final int? batch; // For individual projects
  final int? level; // For individual projects
  final int? term; // For individual projects
  final Semester semester; // Summer or Winter
  final ProjectSubmissionType submissionType;
  final AcademicCourse? academicCourse;
  final String? assistantTeacherId;
  final ProjectAward award;
  final double? showcaseMark; // Hidden mark out of 10
  final List<ShowcaseEvaluation> evaluations; // List of evaluations by different teachers
  final String? rejectionReason; // Reason for rejection/revision

  const Project({
    required this.id,
    required this.title,
    required this.abstract,
    required this.authorId,
    required this.authorName,
    required this.category,
    this.customCategory,
    required this.year,
    required this.semester,
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
    this.isGroupProject = false,
    this.groupName,
    this.teamMembers = const [],
    this.driveLink,
    this.youtubeUrl,
    this.studentId,
    this.batch,
    this.level,
    this.term,
    this.award = ProjectAward.none,
    this.submissionType = ProjectSubmissionType.projectShowcase,
    this.academicCourse,
    this.assistantTeacherId,
    this.rejectionReason,
    this.showcaseMark,
    this.evaluations = const [],
  });

  Project copyWith({
    String? id,
    String? title,
    String? abstract,
    String? authorId,
    String? authorName,
    ProjectCategory? category,
    String? customCategory,
    int? year,
    Semester? semester,
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
    bool? isGroupProject,
    String? groupName,
    List<TeamMember>? teamMembers,
    String? driveLink,
    String? youtubeUrl,
    String? studentId,
    int? batch,
    int? level,
    int? term,
    ProjectAward? award,
    ProjectSubmissionType? submissionType,
    AcademicCourse? academicCourse,
    String? assistantTeacherId,
    String? rejectionReason,
    double? showcaseMark,
    List<ShowcaseEvaluation>? evaluations,
  }) {
    return Project(
      id: id ?? this.id,
      title: title ?? this.title,
      abstract: abstract ?? this.abstract,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      category: category ?? this.category,
      customCategory: customCategory ?? this.customCategory,
      year: year ?? this.year,
      semester: semester ?? this.semester,
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
      isGroupProject: isGroupProject ?? this.isGroupProject,
      groupName: groupName ?? this.groupName,
      teamMembers: teamMembers ?? this.teamMembers,
      driveLink: driveLink ?? this.driveLink,
      youtubeUrl: youtubeUrl ?? this.youtubeUrl,
      studentId: studentId ?? this.studentId,
      batch: batch ?? this.batch,
      level: level ?? this.level,
      term: term ?? this.term,
      award: award ?? this.award,
      submissionType: submissionType ?? this.submissionType,
      academicCourse: academicCourse ?? this.academicCourse,
      assistantTeacherId: assistantTeacherId ?? this.assistantTeacherId,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      showcaseMark: showcaseMark ?? this.showcaseMark,
      evaluations: evaluations ?? this.evaluations,
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
      'customCategory': customCategory,
      'year': year,
      'semester': semester.name,
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
      'isGroupProject': isGroupProject,
      'groupName': groupName,
      'teamMembers': teamMembers.map((m) => m.toMap()).toList(),
      'driveLink': driveLink,
      'youtubeUrl': youtubeUrl,
      'studentId': studentId,
      'batch': batch,
      'level': level,
      'term': term,
      'award': award.name,
      'submissionType': submissionType.name,
      'academicCourse': academicCourse?.name,
      'assistantTeacherId': assistantTeacherId,
      'rejectionReason': rejectionReason,
      'showcaseMark': showcaseMark,
      'evaluations': evaluations.map((e) => e.toMap()).toList(),
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
  hardware,
}

enum Semester {
  summer,
  winter,
}

enum ProjectStatus {
  draft,
  pending,
  approved,
  rejected,
  featured,
  needsRevision,
  resubmitted,
  hidden,
}

enum ProjectAward {
  none,
  winner,
  firstRunnerUp,
  secondRunnerUp,
  thirdRunnerUp,
}

enum ProjectSubmissionType {
  projectShowcase,
  academic,
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

extension ProjectTypeExtension on ProjectType {
  String get displayName {
    switch (this) {
      case ProjectType.project:
        return 'Project';
      case ProjectType.thesis:
        return 'Thesis';
      case ProjectType.hardware:
        return 'Hardware';
    }
  }
}

extension SemesterExtension on Semester {
  String get displayName {
    switch (this) {
      case Semester.summer:
        return 'Summer';
      case Semester.winter:
        return 'Winter';
    }
  }
}

extension ProjectAwardExtension on ProjectAward {
  String get displayName {
    switch (this) {
      case ProjectAward.none:
        return '';
      case ProjectAward.winner:
        return 'Winner';
      case ProjectAward.firstRunnerUp:
        return '1st Runner Up';
      case ProjectAward.secondRunnerUp:
        return '2nd Runner Up';
      case ProjectAward.thirdRunnerUp:
        return '3rd Runner Up';
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
      case ProjectStatus.hidden:
        return 'Hidden';
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



class ShowcaseEvaluation {
  final String teacherId;
  final String teacherName;
  final double mark;
  final Map<String, double> criteria; // e.g., {'Innovation': 8.0, 'Technical': 9.0}
  final String? feedback;
  final DateTime updatedAt;

  const ShowcaseEvaluation({
    required this.teacherId,
    required this.teacherName,
    required this.mark,
    this.criteria = const {},
    this.feedback,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'teacherId': teacherId,
      'teacherName': teacherName,
      'mark': mark,
      'criteria': criteria,
      'feedback': feedback,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory ShowcaseEvaluation.fromMap(Map<String, dynamic> map) {
    return ShowcaseEvaluation(
      teacherId: map['teacherId'] ?? '',
      teacherName: map['teacherName'] ?? 'Unknown',
      mark: (map['mark'] ?? 0.0).toDouble(),
      criteria: (map['criteria'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(key, (value as num).toDouble()),
          ) ?? {},
      feedback: map['feedback'],
      updatedAt: DateTime.tryParse(map['updatedAt'] ?? '') ?? DateTime.now(),
    );
  }
}
