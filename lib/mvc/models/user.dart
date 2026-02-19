class User {
  final String id;
  final String name;
  final String email;
  final String password;
  final UserRole role;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? profileImageUrl;
  final bool isApproved; // For teacher approval system
  final DateTime? approvedAt;
  final String? approvedBy; // Admin ID who approved
  final String? department; // Department for teachers
  final String? employeeId; // Employee ID for teachers
  final String? studentId; // Student ID for students
  final int? year; // Academic year for students
  final String? phoneNumber; // Contact information
  final DateTime? lastLoginAt; // Track last login
  final bool isActive; // Account status
  final Designation? designation; // Designation for teachers
  final bool notificationsEnabled; // Notification preferences
  final String? bio; // Student portfolio bio
  final List<String>? skills; // Student skills
  final String? linkedinUrl; // LinkedIn profile
  final String? githubUrl; // GitHub profile
  final List<String>? pinnedProjectIds; // IDs of projects to highlight
  final bool isPublicProfile; // Whether the profile is visible to others

  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.password,
    required this.role,
    required this.createdAt,
    required this.updatedAt,
    this.profileImageUrl,
    this.isApproved = true, // Students and admins are approved by default
    this.approvedAt,
    this.approvedBy,
    this.department,
    this.employeeId,
    this.studentId,
    this.year,
    this.phoneNumber,
    this.lastLoginAt,
    this.isActive = true,
    this.designation,
    this.notificationsEnabled = true, // Notifications enabled by default
    this.bio,
    this.skills,
    this.linkedinUrl,
    this.githubUrl,
    this.pinnedProjectIds,
    this.isPublicProfile = false,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      password: json['password'] as String,
      role: _roleFrom(json['role']),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      profileImageUrl: json['profileImageUrl'] as String?,
      isApproved: json['isApproved'] as bool? ?? true,
      approvedAt: json['approvedAt'] != null
          ? DateTime.parse(json['approvedAt'] as String)
          : null,
      approvedBy: json['approvedBy'] as String?,
      department: json['department'] as String?,
      employeeId: json['employeeId'] as String?,
      studentId: json['studentId'] as String?,
      year: json['year'] as int?,
      phoneNumber: json['phoneNumber'] as String?,
      lastLoginAt: json['lastLoginAt'] != null
          ? DateTime.parse(json['lastLoginAt'] as String)
          : null,
      isActive: json['isActive'] as bool? ?? true,
      designation: json['designation'] != null
          ? Designation.values.firstWhere(
              (e) => e.name == json['designation'],
              orElse: () => Designation.lecturer,
            )
          : (json['role'] == 'teacher' ? Designation.lecturer : null),
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
      bio: json['bio'] as String?,
      skills: (json['skills'] as List<dynamic>?)?.map((e) => e as String).toList(),
      linkedinUrl: json['linkedinUrl'] as String?,
      githubUrl: json['githubUrl'] as String?,
      pinnedProjectIds: (json['pinnedProjectIds'] as List<dynamic>?)?.map((e) => e as String).toList(),
      isPublicProfile: json['isPublicProfile'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'password': password,
      'role': role.name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'profileImageUrl': profileImageUrl,
      'isApproved': isApproved,
      'approvedAt': approvedAt?.toIso8601String(),
      'approvedBy': approvedBy,
      'department': department,
      'employeeId': employeeId,
      'studentId': studentId,
      'year': year,
      'phoneNumber': phoneNumber,
      'lastLoginAt': lastLoginAt?.toIso8601String(),
      'isActive': isActive,
      'designation': designation?.name,
      'notificationsEnabled': notificationsEnabled,
      'bio': bio,
      'skills': skills,
      'linkedinUrl': linkedinUrl,
      'githubUrl': githubUrl,
      'pinnedProjectIds': pinnedProjectIds,
      'isPublicProfile': isPublicProfile,
    };
  }

  User copyWith({
    String? id,
    String? name,
    String? email,
    String? password,
    UserRole? role,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? profileImageUrl,
    bool? isApproved,
    DateTime? approvedAt,
    String? approvedBy,
    String? department,
    String? employeeId,
    String? studentId,
    int? year,
    String? phoneNumber,
    DateTime? lastLoginAt,
    bool? isActive,
    Designation? designation,
    bool? notificationsEnabled,
    String? bio,
    List<String>? skills,
    String? linkedinUrl,
    String? githubUrl,
    List<String>? pinnedProjectIds,
    bool? isPublicProfile,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      password: password ?? this.password,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      isApproved: isApproved ?? this.isApproved,
      approvedAt: approvedAt ?? this.approvedAt,
      approvedBy: approvedBy ?? this.approvedBy,
      department: department ?? this.department,
      employeeId: employeeId ?? this.employeeId,
      studentId: studentId ?? this.studentId,
      year: year ?? this.year,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      isActive: isActive ?? this.isActive,
      designation: designation ?? this.designation,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      bio: bio ?? this.bio,
      skills: skills ?? this.skills,
      linkedinUrl: linkedinUrl ?? this.linkedinUrl,
      githubUrl: githubUrl ?? this.githubUrl,
      pinnedProjectIds: pinnedProjectIds ?? this.pinnedProjectIds,
      isPublicProfile: isPublicProfile ?? this.isPublicProfile,
    );
  }

  static UserRole _roleFrom(dynamic value) {
    if (value is String) {
      return UserRole.values.byName(value);
    }
    if (value is int) {
      return UserRole.values[value];
    }
    throw ArgumentError('Invalid role value: $value');
  }
}

enum UserRole {
  student,
  teacher,
  admin,
}

enum Designation {
  departmentHead,
  professor,
  associateProfessor,
  assistantProfessor,
  lecturer,
}

extension DesignationExtension on Designation {
  String get displayName {
    switch (this) {
      case Designation.departmentHead:
        return 'Department Head';
      case Designation.professor:
        return 'Professor';
      case Designation.associateProfessor:
        return 'Associate Professor';
      case Designation.assistantProfessor:
        return 'Assistant Professor';
      case Designation.lecturer:
        return 'Lecturer';
    }
  }
}

extension UserRoleExtension on UserRole {
  String get displayName {
    switch (this) {
      case UserRole.student:
        return 'Student';
      case UserRole.teacher:
        return 'Teacher';
      case UserRole.admin:
        return 'Admin';
    }
  }

  String get description {
    switch (this) {
      case UserRole.student:
        return 'Upload projects, explore, bookmark projects';
      case UserRole.teacher:
        return 'Review, rate, comment, and provide feedback';
      case UserRole.admin:
        return 'Manage users, approve teachers, control all features';
    }
  }

  // Get permissions for each role
  List<String> get permissions {
    switch (this) {
      case UserRole.student:
        return [
          'Upload projects',
          'View all projects',
          'Bookmark projects',
          'Edit own projects',
          'Delete own projects',
        ];
      case UserRole.teacher:
        return [
          'View all projects',
          'Comment on projects',
          'Rate projects',
          'Provide feedback',
          'View project analytics',
        ];
      case UserRole.admin:
        return [
          'All student permissions',
          'All teacher permissions',
          'Manage all users',
          'Approve/reject teachers',
          'Delete any project',
          'Manage system settings',
          'View analytics',
        ];
    }
  }
}
