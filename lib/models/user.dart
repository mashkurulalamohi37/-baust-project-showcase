class User {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final DateTime createdAt;
  final String? profileImageUrl;
  final bool isApproved; // For teacher approval system
  final DateTime? approvedAt;
  final String? approvedBy; // Admin ID who approved
  final String? department; // Department for teachers
  final String? employeeId; // Employee ID for teachers
  final String? phoneNumber; // Contact information
  final DateTime? lastLoginAt; // Track last login
  final bool isActive; // Account status

  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.createdAt,
    this.profileImageUrl,
    this.isApproved = true, // Students and admins are approved by default
    this.approvedAt,
    this.approvedBy,
    this.department,
    this.employeeId,
    this.phoneNumber,
    this.lastLoginAt,
    this.isActive = true,
  });

  User copyWith({
    String? id,
    String? name,
    String? email,
    UserRole? role,
    DateTime? createdAt,
    String? profileImageUrl,
    bool? isApproved,
    DateTime? approvedAt,
    String? approvedBy,
    String? department,
    String? employeeId,
    String? phoneNumber,
    DateTime? lastLoginAt,
    bool? isActive,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      isApproved: isApproved ?? this.isApproved,
      approvedAt: approvedAt ?? this.approvedAt,
      approvedBy: approvedBy ?? this.approvedBy,
      department: department ?? this.department,
      employeeId: employeeId ?? this.employeeId,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      isActive: isActive ?? this.isActive,
    );
  }
}

enum UserRole {
  student,
  teacher,
  admin,
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
