import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/user.dart';
import '../models/project.dart';
import '../models/review.dart';
import '../models/team_member.dart';
import '../models/feedback.dart' as feedback_models;
import 'notification_service.dart';

class FirestoreService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
  );
  static final FirebaseStorage _storage = FirebaseStorage.instanceFor(
    bucket: 'projectshowcase-b2748.firebasestorage.app',
  );

  // Collection names
  static const String _usersCollection = 'users';
  static const String _projectsCollection = 'projects';
  static const String _reviewsCollection = 'reviews';
  static const String _bookmarksCollection = 'bookmarks';

  // Helper utilities for safely reading Firestore data
  static String _normalizeEmail(String value) => value.trim().toLowerCase();

  static DateTime? _tryParseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  static DateTime _parseDateOrNow(dynamic value, {DateTime? fallback}) {
    return _tryParseDate(value) ?? fallback ?? DateTime.now();
  }

  static String? _optionalString(Map<String, dynamic> data, String key) {
    if (!data.containsKey(key)) return null;
    final value = data[key];
    if (value == null) return null;
    final str = value.toString().trim();
    return str.isEmpty ? null : str;
  }

  static bool _boolField(
    Map<String, dynamic> data,
    String key, {
    bool defaultValue = false,
  }) {
    if (!data.containsKey(key) || data[key] == null) return defaultValue;
    final value = data[key];
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final lower = value.toLowerCase();
      if (lower == 'true') return true;
      if (lower == 'false') return false;
    }
    return defaultValue;
  }

  static int? _intField(Map<String, dynamic> data, String key) {
    if (!data.containsKey(key) || data[key] == null) return null;
    final value = data[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String && value.isNotEmpty) {
      return int.tryParse(value);
    }
    return null;
  }

  static DateTime _userFreshness(User user) {
    return user.updatedAt.isAfter(user.createdAt)
        ? user.updatedAt
        : user.createdAt;
  }

  // User operations
  static Future<void> saveUser(User user) async {
    try {
      final normalizedEmail = user.email.trim().toLowerCase();
      print('Saving user to Firestore: $normalizedEmail');
      await _firestore.collection(_usersCollection).doc(user.id).set({
        'id': user.id,
        'email': normalizedEmail,
        'emailLowercase': normalizedEmail,
        'password': user.password,
        'role': user.role.name,
        'name': user.name,
        'studentId': user.studentId,
        'department': user.department,
        'year': user.year,
        'phoneNumber': user.phoneNumber,
        'isApproved': user.isApproved,
        'profileImageUrl': user.profileImageUrl,
        'approvedAt': user.approvedAt?.toIso8601String(),
        'approvedBy': user.approvedBy,
        'employeeId': user.employeeId,
        'lastLoginAt': user.lastLoginAt?.toIso8601String(),
        'isActive': user.isActive,
        'createdAt': user.createdAt.toIso8601String(),
        'updatedAt': user.updatedAt.toIso8601String(),
        'designation': user.designation?.name,
      });
      print('User saved successfully: $normalizedEmail');
    } catch (e) {
      print('ERROR: Failed to save user: $e');
      rethrow;
    }
  }

  static Future<User?> getUserByEmail(String email) async {
    try {
      final normalizedEmail = _normalizeEmail(email);
      print('FirestoreService: ========== START getUserByEmail ==========');
      print('FirestoreService: Looking up user by email: $normalizedEmail');

      if (normalizedEmail.isEmpty) {
        print('FirestoreService: Email is empty after normalization');
        return null;
      }

      // Try exact match on 'email' field
      print('FirestoreService: Attempting query 1: email field');
      final exactMatch = await _findUserByField('email', normalizedEmail);
      if (exactMatch != null) {
        print('FirestoreService: ✓ Found user via email field query');
        return exactMatch;
      }

      // Try exact match on 'emailLowercase' field
      print('FirestoreService: Attempting query 2: emailLowercase field');
      final normalizedFieldMatch = await _findUserByField(
        'emailLowercase',
        normalizedEmail,
      );
      if (normalizedFieldMatch != null) {
        print('FirestoreService: ✓ Found user via emailLowercase field query');
        return normalizedFieldMatch;
      }

      // Fallback: scan all users (for legacy data)
      print(
        'FirestoreService: No direct match found, performing fallback scan for legacy data...',
      );
      try {
        print('FirestoreService: Attempting to fetch all users (limit 300)...');
        final allUsers = await _firestore
            .collection(_usersCollection)
            .limit(300)
            .get();
        
        print('FirestoreService: ✓ Successfully fetched ${allUsers.docs.length} users from Firestore');

        print(
          'FirestoreService: Scanning ${allUsers.docs.length} user documents for case-insensitive match',
        );
        final matchingDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];

        for (final doc in allUsers.docs) {
          try {
            final data = doc.data();
            final storedEmail = _optionalString(data, 'email') ?? '';
            if (storedEmail.isEmpty) {
              print('FirestoreService: Skipping doc ${doc.id} - no email field');
              continue;
            }
            final storedNormalized = _normalizeEmail(storedEmail);
            print('FirestoreService: Checking doc ${doc.id}: storedEmail="$storedEmail", normalized="$storedNormalized", target="$normalizedEmail"');
            if (storedNormalized == normalizedEmail) {
              print('FirestoreService: ✓ MATCH FOUND in doc ${doc.id}: $storedEmail');
              matchingDocs.add(doc);
              final updates = <String, dynamic>{};
              if (storedEmail.trim() != normalizedEmail) {
                updates['email'] = normalizedEmail;
              }
              updates['emailLowercase'] = normalizedEmail;
              if (updates.isNotEmpty) {
                doc.reference.update(updates).catchError((e) {
                  print(
                    'FirestoreService: Warning - Could not update email normalization for ${doc.id}: $e',
                  );
                });
              }
            }
          } catch (e) {
            print(
              'FirestoreService: Error processing user document during fallback scan: $e',
            );
          }
        }
        
        print('FirestoreService: Fallback scan complete. Found ${matchingDocs.length} matching documents.');

        final fallbackUser = _extractMostRecentUser(
          matchingDocs,
          normalizedEmail,
        );
        if (fallbackUser != null) {
          print(
            'FirestoreService: Legacy user found after fallback scan: ${fallbackUser.email}',
          );
          return fallbackUser;
        }

        print(
          'FirestoreService: No user found with email: $normalizedEmail (checked ${allUsers.docs.length} users)',
        );
      } catch (e) {
        print('FirestoreService: Error in case-insensitive fallback scan: $e');
      }

      return null;
    } catch (e, stackTrace) {
      print('ERROR: Failed to get user by email: $e');
      print('ERROR: Stack trace: $stackTrace');
      return null;
    }
  }

  static Future<User?> _findUserByField(
    String field,
    String normalizedEmail,
  ) async {
    try {
      print(
        'FirestoreService: Executing query: collection=$_usersCollection, where $field == "$normalizedEmail"',
      );
      final query = await _firestore
          .collection(_usersCollection)
          .where(field, isEqualTo: normalizedEmail)
          .get();

      print(
        'FirestoreService: Query on $field returned ${query.docs.length} documents',
      );
      if (query.docs.isNotEmpty) {
        print('FirestoreService: Found documents:');
        for (var doc in query.docs) {
          final data = doc.data();
          print('  - Doc ID: ${doc.id}, email: ${data['email']}, name: ${data['name']}');
        }
      }
      return _extractMostRecentUser(query.docs, normalizedEmail);
    } catch (e, stackTrace) {
      print('FirestoreService: Error querying $field for $normalizedEmail: $e');
      print('FirestoreService: Stack trace: $stackTrace');
      return null;
    }
  }

  static User? _extractMostRecentUser(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String normalizedEmail,
  ) {
    if (docs.isEmpty) return null;

    User? selectedUser;
    for (final doc in docs) {
      try {
        final user = _userFromData(
          doc.data(),
          doc.id,
          normalizedEmailOverride: normalizedEmail,
        );
        if (selectedUser == null) {
          selectedUser = user;
          continue;
        }
        if (_userFreshness(user).isAfter(_userFreshness(selectedUser))) {
          selectedUser = user;
        }
      } catch (e) {
        print('FirestoreService: Skipping invalid user document ${doc.id}: $e');
      }
    }

    return selectedUser;
  }

  static User _userFromData(
    Map<String, dynamic> data,
    String docId, {
    String? normalizedEmailOverride,
  }) {
    final normalizedEmail = normalizedEmailOverride?.isNotEmpty == true
        ? normalizedEmailOverride!.trim().toLowerCase()
        : _normalizeEmail(_optionalString(data, 'email') ?? '');

    final createdAt = _parseDateOrNow(data['createdAt']);
    final updatedAt = _parseDateOrNow(data['updatedAt'], fallback: createdAt);

    UserRole parseRole() {
      final roleValue = _optionalString(data, 'role') ?? 'student';
      try {
        return UserRole.values.firstWhere(
          (e) => e.name.toLowerCase() == roleValue.toLowerCase(),
          orElse: () => UserRole.student,
        );
      } catch (_) {
        return UserRole.student;
      }
    }

    final role = parseRole();

    return User(
      id: _optionalString(data, 'id') ?? docId,
      name: _optionalString(data, 'name') ?? 'User',
      email: normalizedEmail,
      password: _optionalString(data, 'password') ?? '',
      role: role,
      createdAt: createdAt,
      updatedAt: updatedAt,
      profileImageUrl: _optionalString(data, 'profileImageUrl'),
      isApproved: _boolField(data, 'isApproved', defaultValue: true),
      approvedAt: _tryParseDate(data['approvedAt']),
      approvedBy: _optionalString(data, 'approvedBy'),
      department: _optionalString(data, 'department'),
      employeeId: _optionalString(data, 'employeeId'),
      studentId: _optionalString(data, 'studentId'),
      year: _intField(data, 'year'),
      phoneNumber: _optionalString(data, 'phoneNumber'),
      lastLoginAt: _tryParseDate(data['lastLoginAt']),
      isActive: _boolField(data, 'isActive', defaultValue: true),
      designation: data['designation'] != null
          ? Designation.values.firstWhere(
              (e) => e.name == data['designation'],
              orElse: () => Designation.lecturer,
            )
          : (role == UserRole.teacher ? Designation.lecturer : null),
    );
  }

  static Future<User?> getUserByEmployeeId(String employeeId) async {
    try {
      print('Looking up user by employee ID: $employeeId');
      final query = await _firestore
          .collection(_usersCollection)
          .where('employeeId', isEqualTo: employeeId)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        print('No user found with employee ID: $employeeId');
        return null;
      }

      final doc = query.docs.first;
      final data = doc.data();
      print('User found with employee ID: ${data['employeeId']}');

      return _userFromData(
        data,
        doc.id,
        normalizedEmailOverride: _normalizeEmail(
          _optionalString(data, 'email') ?? '',
        ),
      );
    } catch (e) {
      print('ERROR: Failed to get user by employee ID: $e');
      return null;
    }
  }

  static Future<List<User>> getAllUsers() async {
    try {
      final query = await _firestore.collection(_usersCollection).get();
      final users = <User>[];
      for (final doc in query.docs) {
        try {
          users.add(_userFromData(doc.data(), doc.id));
        } catch (e) {
          print('ERROR: Failed to parse user ${doc.id}: $e');
        }
      }
      return users;
    } catch (e) {
      print('ERROR: Failed to get all users: $e');
      return [];
    }
  }

  static Future<void> updateUser(User user) async {
    try {
      final normalizedEmail = _normalizeEmail(user.email);
      final updatedAt = user.updatedAt;
      await _firestore.collection(_usersCollection).doc(user.id).update({
        'email': normalizedEmail,
        'emailLowercase': normalizedEmail,
        'password': user.password,
        'role': user.role.name,
        'name': user.name,
        'studentId': user.studentId,
        'department': user.department,
        'year': user.year,
        'phoneNumber': user.phoneNumber,
        'isApproved': user.isApproved,
        'profileImageUrl': user.profileImageUrl,
        'approvedAt': user.approvedAt?.toIso8601String(),
        'approvedBy': user.approvedBy,
        'employeeId': user.employeeId,
        'isActive': user.isActive,
        'updatedAt': updatedAt.toIso8601String(),
        'designation': user.designation?.name,
      });
      print('User updated successfully: $normalizedEmail');
    } catch (e) {
      print('ERROR: Failed to update user: $e');
      rethrow;
    }
  }

  static Future<User?> getUser(String userId) async {
    try {
      final doc = await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        return _userFromData(
          data,
          doc.id,
          normalizedEmailOverride: _normalizeEmail(
            _optionalString(data, 'email') ?? '',
          ),
        );
      }
      return null;
    } catch (e) {
      print('ERROR: Failed to get user: $e');
      return null;
    }
  }

  static Future<User?> getUserById(String id) async {
    return getUser(id);
  }

  static Future<List<User>> getPendingTeachers() async {
    try {
      final query = await _firestore
          .collection(_usersCollection)
          .where('role', isEqualTo: 'teacher')
          .where('isApproved', isEqualTo: false)
          .get();

      final users = <User>[];
      for (final doc in query.docs) {
        try {
          final user = _userFromData(doc.data(), doc.id);
          if (user.isActive) {
            users.add(user);
          }
        } catch (e) {
          print('ERROR: Failed to parse pending teacher ${doc.id}: $e');
        }
      }

      // Sort by creation date locally
      users.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return users;
    } catch (e) {
      print('ERROR: Failed to get pending teachers: $e');
      return [];
    }
  }

  static Future<void> approveTeacher(String userId, String approvedBy) async {
    try {
      await _firestore.collection(_usersCollection).doc(userId).update({
        'isApproved': true,
        'approvedAt': DateTime.now().toIso8601String(),
        'approvedBy': approvedBy,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('ERROR: Failed to approve teacher: $e');
      rethrow;
    }
  }

  static Future<void> deleteUser(String userId) async {
    try {
      await _firestore.collection(_usersCollection).doc(userId).delete();
      print('User deleted successfully: $userId');
    } catch (e) {
      print('ERROR: Failed to delete user: $e');
      rethrow;
    }
  }

  // Project operations
  static Future<void> saveProject(Project project) async {
    try {
      print('FirestoreService: Starting to save project: ${project.title}');
      print('FirestoreService: Project ID: ${project.id}');
      print('FirestoreService: Project status: ${project.status.name}');

      // Check for duplicate projects in Firestore
      final duplicateQuery = await _firestore
          .collection(_projectsCollection)
          .where('title', isEqualTo: project.title)
          .where('authorId', isEqualTo: project.authorId)
          .get();

      if (duplicateQuery.docs.isNotEmpty) {
        throw Exception(
          'A project with this title already exists by the same author',
        );
      }

      // Helper function to validate URL
      String? validateUrl(String? url) {
        if (url == null || url.isEmpty) return null;
        // Only accept HTTP/HTTPS URLs, not local file paths
        if (url.startsWith('http://') || url.startsWith('https://')) {
          return url;
        }
        // If it's a local file path, return null
        return null;
      }

      await _firestore.collection(_projectsCollection).doc(project.id).set({
        'id': project.id,
        'title': project.title,
        'abstract': project.abstract,
        'authorId': project.authorId,
        'authorName': project.authorName,
        'category': project.category.name,
        'year': project.year,
        'semester': project.semester.name,
        'supervisor': project.supervisor,
        'githubUrl': project.githubUrl,
        'imageUrls': project.imageUrls,
        'pdfUrl': validateUrl(project.pdfUrl), // Only save valid URLs
        'status': project.status.name,
        'rating': project.rating,
        'reviewCount': project.reviewCount,
        'isFeatured': project.isFeatured,
        'facultyId': project.facultyId,
        'facultyName': project.facultyName,
        'createdAt': project.createdAt.toIso8601String(),
        'updatedAt': project.updatedAt.toIso8601String(),
        'feedback': project.feedback.map((f) => f.toMap()).toList(),
        'projectType': project.projectType.name,
        'isGroupProject': project.isGroupProject,
        'groupName': project.groupName,
        'teamMembers': project.teamMembers.map((m) => m.toMap()).toList(),
        'driveLink': project.driveLink,
        'youtubeUrl': project.youtubeUrl,
        'studentId': project.studentId,
        'batch': project.batch,
        'level': project.level,
        'term': project.term,
        'award': project.award.name,
        'submissionType': project.submissionType.name,
        'academicCourse': project.academicCourse?.name,
        'assistantTeacherId': project.assistantTeacherId,
        'rejectionReason': project.rejectionReason,
      });
      print('Project saved successfully: ${project.title} (facultyId: ${project.facultyId}, facultyName: ${project.facultyName})');
    } catch (e) {
      print('ERROR: Failed to save project: $e');
      rethrow;
    }
  }

  static Future<List<Project>> getAllProjects() async {
    try {
      final query = await _firestore.collection(_projectsCollection).get();
      return query.docs.map((doc) {
        final data = doc.data();
        return Project(
          id: data['id'],
          title: data['title'],
          abstract: data['abstract'],
          authorId: data['authorId'],
          authorName: data['authorName'],
          category: ProjectCategory.values.firstWhere(
            (e) => e.name == data['category'],
          ),
          year: data['year'],
          semester: data['semester'] != null
              ? Semester.values.firstWhere(
                  (e) => e.name == data['semester'],
                  orElse: () => Semester.summer,
                )
              : Semester.summer,
          supervisor: data['supervisor'],
          githubUrl: data['githubUrl'],
          imageUrls: List<String>.from(data['imageUrls'] ?? []),
          // Filter out local file paths - only keep valid HTTP/HTTPS URLs
          pdfUrl:
              data['pdfUrl'] != null &&
                  data['pdfUrl'].toString().isNotEmpty &&
                  (data['pdfUrl'].toString().startsWith('http://') ||
                      data['pdfUrl'].toString().startsWith('https://'))
              ? data['pdfUrl']
              : null,
          status: ProjectStatus.values.firstWhere(
            (e) => e.name == data['status'],
          ),
          rating: (data['rating'] ?? 0.0).toDouble(),
          reviewCount: data['reviewCount'] ?? 0,
          createdAt: DateTime.parse(data['createdAt']),
          updatedAt: DateTime.parse(data['updatedAt']),
          feedback:
              (data['feedback'] as List<dynamic>?)
                  ?.map((f) => feedback_models.ProjectFeedback.fromMap(f))
                  .toList() ??
              [],
          projectType: data['projectType'] != null
              ? ProjectType.values.firstWhere(
                  (e) => e.name == data['projectType'],
                  orElse: () => ProjectType.project,
                )
              : ProjectType.project,
          isGroupProject: data['isGroupProject'] ?? false,
          groupName: data['groupName'],
          teamMembers: (data['teamMembers'] as List<dynamic>?)
                  ?.map((m) => TeamMember.fromMap(m))
                  .toList() ??
              [],
          driveLink: data['driveLink'],
          youtubeUrl: data['youtubeUrl'],
          studentId: data['studentId'],
          batch: data['batch'],
          level: data['level'],
          term: data['term'],
          award: data['award'] != null
              ? ProjectAward.values.firstWhere(
                  (e) => e.name == data['award'],
                  orElse: () => ProjectAward.none,
                )
              : ProjectAward.none,
          submissionType: data['submissionType'] != null
              ? ProjectSubmissionType.values.firstWhere(
                  (e) => e.name == data['submissionType'],
                  orElse: () => ProjectSubmissionType.projectShowcase,
                )
              : ProjectSubmissionType.projectShowcase,
          academicCourse: data['academicCourse'] != null
              ? AcademicCourse.values.firstWhere(
                  (e) => e.name == data['academicCourse'],
                  orElse: () => AcademicCourse.softwareDevelopmentProject1,
                )
              : null,
          assistantTeacherId: data['assistantTeacherId'],
          rejectionReason: data['rejectionReason'],
        );
      }).toList();
    } catch (e) {
      print('ERROR: Failed to get all projects: $e');
      return [];
    }
  }

  static Future<List<Project>> getProjects({
    ProjectStatus? status,
    ProjectCategory? category,
    int? year,
    String? authorId,
    bool? isFeatured,
    int? limit,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _firestore.collection(
        _projectsCollection,
      );

      if (status != null) {
        query = query.where('status', isEqualTo: status.name);
      }
      if (category != null) {
        query = query.where('category', isEqualTo: category.name);
      }
      if (year != null) {
        query = query.where('year', isEqualTo: year);
      }
      // Note: We can add semester filter here later if needed, but for now filtering happens in UI or specific queries
      if (authorId != null) {
        query = query.where('authorId', isEqualTo: authorId);
      }
      if (isFeatured != null) {
        query = query.where('isFeatured', isEqualTo: isFeatured);
      }

      Query<Map<String, dynamic>> orderedQuery = query.orderBy(
        'createdAt',
        descending: true,
      );

      final snapshot = limit != null
          ? await orderedQuery.limit(limit).get()
          : await orderedQuery.get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return Project(
          id: data['id'] ?? doc.id,
          title: data['title'] ?? '',
          abstract: data['abstract'] ?? '',
          authorId: data['authorId'] ?? '',
          authorName: data['authorName'] ?? '',
          category: ProjectCategory.values.firstWhere(
            (e) => e.name == data['category'],
            orElse: () => ProjectCategory.other,
          ),

          year: data['year'] ?? DateTime.now().year,
          semester: data['semester'] != null
              ? Semester.values.firstWhere(
                  (e) => e.name == data['semester'],
                  orElse: () => Semester.summer,
                )
              : Semester.summer,
          supervisor: data['supervisor'],
          status: ProjectStatus.values.firstWhere(
            (e) => e.name == data['status'],
            orElse: () => ProjectStatus.pending,
          ),
          rating: (data['rating'] ?? 0.0).toDouble(),
          reviewCount: data['reviewCount'] ?? 0,
          imageUrls: List<String>.from(data['imageUrls'] ?? []),
          pdfUrl: data['pdfUrl'],
          githubUrl: data['githubUrl'],
          tags: List<String>.from(data['tags'] ?? []),
          isFeatured: data['isFeatured'] ?? false,
          facultyId: data['facultyId'],
          facultyName: data['facultyName'],
          version: data['version'] ?? 1,
          parentProjectId: data['parentProjectId'],
          projectType: data['projectType'] != null
              ? ProjectType.values.firstWhere(
                  (e) => e.name == data['projectType'],
                  orElse: () => ProjectType.project,
                )
              : ProjectType.project,
          createdAt: DateTime.parse(data['createdAt']),
          updatedAt: DateTime.parse(data['updatedAt']),
          feedback:
              (data['feedback'] as List<dynamic>?)
                  ?.map((f) => feedback_models.ProjectFeedback.fromMap(f))
                  .toList() ??
              [],
          versions: const [],
          isGroupProject: data['isGroupProject'] ?? false,
          groupName: data['groupName'],
          teamMembers: (data['teamMembers'] as List<dynamic>?)
                  ?.map((m) => TeamMember.fromMap(m))
                  .toList() ??
              [],
          driveLink: data['driveLink'],
          youtubeUrl: data['youtubeUrl'],
          studentId: data['studentId'],
          batch: data['batch'],
          level: data['level'],
          term: data['term'],
          award: data['award'] != null
              ? ProjectAward.values.firstWhere(
                  (e) => e.name == data['award'],
                  orElse: () => ProjectAward.none,
                )
              : ProjectAward.none,
          submissionType: data['submissionType'] != null
              ? ProjectSubmissionType.values.firstWhere(
                  (e) => e.name == data['submissionType'],
                  orElse: () => ProjectSubmissionType.projectShowcase,
                )
              : ProjectSubmissionType.projectShowcase,
          academicCourse: data['academicCourse'] != null
              ? AcademicCourse.values.firstWhere(
                  (e) => e.name == data['academicCourse'],
                  orElse: () => AcademicCourse.softwareDevelopmentProject1,
                )
              : null,
          assistantTeacherId: data['assistantTeacherId'],
          rejectionReason: data['rejectionReason'],
        );
      }).toList();
    } catch (e) {
      print('ERROR: Failed to get projects: $e');
      return [];
    }
  }

  static Future<Project?> getProjectById(String id) async {
    try {
      final doc = await _firestore
          .collection(_projectsCollection)
          .doc(id)
          .get();
      if (!doc.exists) return null;

      final data = doc.data()!;
      return Project(
        id: data['id'] ?? doc.id,
        title: data['title'] ?? '',
        abstract: data['abstract'] ?? '',
        authorId: data['authorId'] ?? '',
        authorName: data['authorName'] ?? '',
        category: ProjectCategory.values.firstWhere(
          (e) => e.name == data['category'],
          orElse: () => ProjectCategory.other,
        ),
        year: data['year'] ?? DateTime.now().year,
        semester: data['semester'] != null
            ? Semester.values.firstWhere(
                (e) => e.name == data['semester'],
                orElse: () => Semester.summer,
              )
            : Semester.summer,
        supervisor: data['supervisor'],
        status: ProjectStatus.values.firstWhere(
          (e) => e.name == data['status'],
          orElse: () => ProjectStatus.pending,
        ),
        rating: (data['rating'] ?? 0.0).toDouble(),
        reviewCount: data['reviewCount'] ?? 0,
        imageUrls: List<String>.from(data['imageUrls'] ?? []),
        pdfUrl: data['pdfUrl'],
        githubUrl: data['githubUrl'],
        tags: List<String>.from(data['tags'] ?? []),
        isFeatured: data['isFeatured'] ?? false,
        facultyId: data['facultyId'],
        facultyName: data['facultyName'],
        version: data['version'] ?? 1,
        parentProjectId: data['parentProjectId'],
        projectType: data['projectType'] != null
            ? ProjectType.values.firstWhere(
                (e) => e.name == data['projectType'],
                orElse: () => ProjectType.project,
              )
            : ProjectType.project,
        createdAt: DateTime.parse(data['createdAt']),
        updatedAt: DateTime.parse(data['updatedAt']),
        feedback:
            (data['feedback'] as List<dynamic>?)
                ?.map((f) => feedback_models.ProjectFeedback.fromMap(f))
                .toList() ??
            [],
        versions: const [],
        isGroupProject: data['isGroupProject'] ?? false,
        groupName: data['groupName'],
        teamMembers: (data['teamMembers'] as List<dynamic>?)
                ?.map((m) => TeamMember.fromMap(m))
                .toList() ??
            [],
        driveLink: data['driveLink'],
        youtubeUrl: data['youtubeUrl'],
        studentId: data['studentId'],
        batch: data['batch'],
        level: data['level'],
        term: data['term'],
        award: data['award'] != null
            ? ProjectAward.values.firstWhere(
                (e) => e.name == data['award'],
                orElse: () => ProjectAward.none,
              )
            : ProjectAward.none,
        submissionType: data['submissionType'] != null
            ? ProjectSubmissionType.values.firstWhere(
                (e) => e.name == data['submissionType'],
                orElse: () => ProjectSubmissionType.projectShowcase,
              )
            : ProjectSubmissionType.projectShowcase,
        academicCourse: data['academicCourse'] != null
            ? AcademicCourse.values.firstWhere(
                (e) => e.name == data['academicCourse'],
                orElse: () => AcademicCourse.softwareDevelopmentProject1,
              )
            : null,
        assistantTeacherId: data['assistantTeacherId'],
        rejectionReason: data['rejectionReason'],
      );
    } catch (e) {
      print('ERROR: Failed to get project by id: $e');
      return null;
    }
  }

  static Future<void> deleteProject(String id) async {
    try {
      await _firestore.collection(_projectsCollection).doc(id).delete();
    } catch (e) {
      print('ERROR: Failed to delete project: $e');
      rethrow;
    }
  }

  static Future<void> updateProject(Project project) async {
    try {
      await _firestore.collection(_projectsCollection).doc(project.id).update({
        'title': project.title,
        'abstract': project.abstract,
        'authorId': project.authorId,
        'authorName': project.authorName,
        'category': project.category.name,
        'year': project.year,
        'supervisor': project.supervisor,
        'githubUrl': project.githubUrl,
        'imageUrls': project.imageUrls,
        'pdfUrl': project.pdfUrl,
        'status': project.status.name,
        'rating': project.rating,
        'reviewCount': project.reviewCount,
        'isFeatured': project.isFeatured,
        'facultyId': project.facultyId,
        'facultyName': project.facultyName,
        'submissionType': project.submissionType.name,
        'academicCourse': project.academicCourse?.name,
        'assistantTeacherId': project.assistantTeacherId,
        'facultyName': project.facultyName,
        'version': project.version,
        'updatedAt': project.updatedAt.toIso8601String(),
        'feedback': project.feedback.map((f) => f.toMap()).toList(),
        'projectType': project.projectType.name,
        'isGroupProject': project.isGroupProject,
        'groupName': project.groupName,
        'teamMembers': project.teamMembers.map((m) => m.toMap()).toList(),
        'driveLink': project.driveLink,
        'studentId': project.studentId,
        'batch': project.batch,
        'level': project.level,
        'term': project.term,
        'award': project.award.name,
        'rejectionReason': project.rejectionReason,
      });
      print('Project updated successfully: ${project.title} (version: ${project.version}, isFeatured: ${project.isFeatured}, facultyId: ${project.facultyId})');
    } catch (e) {
      print('ERROR: Failed to update project: $e');
      rethrow;
    }
  }

  // Review operations
  static Future<void> saveReview(Review review) async {
    try {
      await _firestore.collection(_reviewsCollection).doc(review.id).set(review.toMap());
      print('Review saved successfully for project: ${review.projectId}');
    } catch (e) {
      print('ERROR: Failed to save review: $e');
      rethrow;
    }
  }

  static Future<List<Review>> getReviewsForProject(String projectId) async {
    try {
      final query = await _firestore
          .collection(_reviewsCollection)
          .where('projectId', isEqualTo: projectId)
          .orderBy('createdAt', descending: true)
          .get();

      return query.docs.map((doc) => Review.fromMap(doc.data())).toList();
    } catch (e) {
      print('ERROR: Failed to get reviews for project: $e');
      return [];
    }
  }

  static Future<List<Review>> getReviewsByProjectId(String projectId) async {
    return getReviewsForProject(projectId);
  }

  static Future<void> deleteReview(String reviewId) async {
    try {
      await _firestore.collection(_reviewsCollection).doc(reviewId).delete();
      print('Review deleted successfully: $reviewId');
    } catch (e) {
      print('ERROR: Failed to delete review: $e');
      rethrow;
    }
  }

  static Future<List<Review>> getReviewsByReviewerId(String reviewerId) async {
    try {
      final query = await _firestore
          .collection(_reviewsCollection)
          .where('reviewerId', isEqualTo: reviewerId)
          .orderBy('createdAt', descending: true)
          .get();

      return query.docs.map((doc) => Review.fromMap(doc.data())).toList();
    } catch (e) {
      print('ERROR: Failed to get reviews by reviewer: $e');
      return [];
    }
  }

  static Future<List<Review>> getAllReviews() async {
    try {
      final query = await _firestore.collection(_reviewsCollection).get();
      return query.docs.map((doc) => Review.fromMap(doc.data())).toList();
    } catch (e) {
      print('ERROR: Failed to get all reviews: $e');
      return [];
    }
  }

  // Bookmark operations
  static Future<void> addBookmark(String userId, String projectId) async {
    await _firestore.collection(_bookmarksCollection).add({
      'userId': userId,
      'projectId': projectId,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  static Future<void> removeBookmark(String userId, String projectId) async {
    final query = await _firestore
        .collection(_bookmarksCollection)
        .where('userId', isEqualTo: userId)
        .where('projectId', isEqualTo: projectId)
        .get();

    for (final doc in query.docs) {
      await doc.reference.delete();
    }
  }

  static Future<List<String>> getUserBookmarks(String userId) async {
    try {
      final query = await _firestore
          .collection(_bookmarksCollection)
          .where('userId', isEqualTo: userId)
          .get();

      return query.docs
          .map((doc) => doc.data()['projectId'] as String)
          .toList();
    } catch (e) {
      print('ERROR: Failed to get user bookmarks: $e');
      return [];
    }
  }

  static Future<bool> isBookmarked(String userId, String projectId) async {
    final query = await _firestore
        .collection(_bookmarksCollection)
        .where('userId', isEqualTo: userId)
        .where('projectId', isEqualTo: projectId)
        .limit(1)
        .get();

    return query.docs.isNotEmpty;
  }

  // Feedback operations
  static Future<void> saveFeedback(
    feedback_models.ProjectFeedback feedback,
  ) async {
    try {
      await _firestore.collection('project_feedback').doc(feedback.id).set({
        'id': feedback.id,
        'projectId': feedback.projectId,
        'reviewerId': feedback.reviewerId,
        'reviewerName': feedback.reviewerName,
        'comment': feedback.comment,
        'type': feedback.type.name,
        'createdAt': feedback.createdAt.toIso8601String(),
        'isResolved': feedback.isResolved,
      });
      print('Feedback saved successfully for project: ${feedback.projectId}');
    } catch (e) {
      print('ERROR: Failed to save feedback: $e');
      rethrow;
    }
  }

  static Future<List<feedback_models.ProjectFeedback>> getFeedbackForProject(
    String projectId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('project_feedback')
          .where('projectId', isEqualTo: projectId)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return feedback_models.ProjectFeedback(
          id: data['id'],
          projectId: data['projectId'],
          reviewerId: data['reviewerId'],
          reviewerName: data['reviewerName'],
          comment: data['comment'],
          type: feedback_models.FeedbackType.values.firstWhere(
            (e) => e.name == data['type'],
          ),
          createdAt: DateTime.parse(data['createdAt']),
          isResolved: data['isResolved'] ?? false,
        );
      }).toList();
    } catch (e) {
      print('ERROR: Failed to get feedback for project: $e');
      return [];
    }
  }

  static Future<void> deleteFeedback(String feedbackId) async {
    try {
      await _firestore.collection('project_feedback').doc(feedbackId).delete();
      print('Feedback deleted successfully: $feedbackId');
    } catch (e) {
      print('ERROR: Failed to delete feedback: $e');
      rethrow;
    }
  }

  // Notification operations

  // Get projects by status
  static Future<List<Project>> getProjectsByStatus(ProjectStatus status) async {
    try {
      final snapshot = await _firestore
          .collection('projects')
          .where('status', isEqualTo: status.name)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return Project(
          id: data['id'] ?? '',
          title: data['title'] ?? '',
          abstract: data['description'] ?? '',
          authorId: data['authorId'] ?? '',
          authorName: data['authorName'] ?? '',
          category: ProjectCategory.values.firstWhere(
            (e) => e.name == data['category'],
            orElse: () => ProjectCategory.other,
          ),
          year: data['year'] ?? DateTime.now().year,
          semester: data['semester'] != null
              ? Semester.values.firstWhere(
                  (e) => e.name == data['semester'],
                  orElse: () => Semester.summer,
                )
              : Semester.summer,
          supervisor: data['supervisor'] ?? '',
          createdAt: DateTime.parse(data['createdAt']),
          updatedAt: DateTime.parse(data['updatedAt']),
          status: ProjectStatus.values.firstWhere(
            (e) => e.name == data['status'],
            orElse: () => ProjectStatus.pending,
          ),
          rating: (data['rating'] ?? 0.0).toDouble(),
          reviewCount: data['reviewCount'] ?? 0,
          imageUrls: List<String>.from(data['imageUrls'] ?? []),
          pdfUrl: data['pdfUrl'],
          githubUrl: data['githubUrl'],
          projectType: data['projectType'] != null
              ? ProjectType.values.firstWhere(
                  (e) => e.name == data['projectType'],
                  orElse: () => ProjectType.project,
                )
              : ProjectType.project,
        );
      }).toList();
    } catch (e) {
      print('Error getting projects by status: $e');
      return [];
    }
  }

  // File upload operations
  static Future<String> uploadFile(String path, String fileName) async {
    try {
      // Check if file exists
      final file = File(path);
      if (!await file.exists()) {
        throw Exception('File not found: $path');
      }

      print('FirestoreService: ========== UPLOAD START ==========');
      print('FirestoreService: Uploading file to Firebase Storage');
      print('FirestoreService: File path: $path');
      print('FirestoreService: File exists: ${await file.exists()}');
      print('FirestoreService: File size: ${await file.length()} bytes');
      print('FirestoreService: Storage path: uploads/$fileName');
      print('FirestoreService: Storage instance: $_storage');

      final ref = _storage.ref().child('uploads/$fileName');
      print('FirestoreService: Storage reference created: ${ref.fullPath}');
      print('FirestoreService: Starting file upload...');

      final uploadTask = ref.putFile(file);
      print('FirestoreService: Upload task created, waiting for completion...');

      await uploadTask;
      print('FirestoreService: File upload successful!');

      print('FirestoreService: Getting download URL...');
      final url = await ref.getDownloadURL();
      print('FirestoreService: Download URL obtained: $url');
      print('FirestoreService: ========== UPLOAD SUCCESS ==========');
      return url;
    } on FirebaseException catch (e) {
      String errorMessage = 'Failed to upload file';
      print(
        'ERROR: Firebase Storage exception - Code: ${e.code}, Message: ${e.message}',
      );
      print('ERROR: Stack trace: ${e.stackTrace}');

      if (e.code == 'unauthorized' || e.code == 'permission-denied') {
        errorMessage =
            'Permission denied. Please check Firebase Storage rules allow uploads to the uploads/ folder.';
      } else if (e.code == 'bucket-not-found' || e.code == 'object-not-found') {
        errorMessage =
            'Storage bucket not found. Please create a Firebase Storage bucket in Firebase Console.';
      } else if (e.code == 'unauthenticated') {
        errorMessage = 'Authentication required. Please log in and try again.';
      } else if (e.code == 'canceled') {
        errorMessage = 'Upload was canceled. Please try again.';
      } else {
        errorMessage =
            'Upload failed: ${e.message ?? e.code}. Please check Firebase Storage configuration.';
      }
      print('ERROR: Throwing exception with message: $errorMessage');
      throw Exception(errorMessage);
    } catch (e, stackTrace) {
      print('ERROR: Failed to upload file: $e');
      print('ERROR: Stack trace: $stackTrace');
      rethrow;
    }
  }

  static Future<List<String>> uploadMultipleFiles(
    List<String> paths,
    String folder,
  ) async {
    try {
      final urls = <String>[];
      for (int i = 0; i < paths.length; i++) {
        // Check if file exists
        final file = File(paths[i]);
        if (!await file.exists()) {
          throw Exception('File not found: ${paths[i]}');
        }

        final fileName =
            '${folder}_${DateTime.now().millisecondsSinceEpoch}_$i';
        final ref = _storage.ref().child('uploads/$folder/$fileName');
        await ref.putFile(file);
        final url = await ref.getDownloadURL();
        urls.add(url);
      }
      return urls;
    } on FirebaseException catch (e) {
      String errorMessage = 'Failed to upload files';
      if (e.code == 'unauthorized' || e.code == 'permission-denied') {
        errorMessage =
            'Permission denied. Please check Firebase Storage rules allow uploads.';
      } else if (e.code == 'bucket-not-found' || e.code == 'object-not-found') {
        errorMessage =
            'Storage bucket not found. Please create a Firebase Storage bucket.';
      } else if (e.code == 'unauthenticated') {
        errorMessage = 'Authentication required. Please log in and try again.';
      } else {
        errorMessage = 'Upload failed: ${e.message ?? e.code}';
      }
      print('ERROR: Firebase Storage error: ${e.code} - ${e.message}');
      throw Exception(errorMessage);
    } catch (e) {
      print('ERROR: Failed to upload multiple files: $e');
      rethrow;
    }
  }

  // Delete file from Firebase Storage
  static Future<void> deleteFile(String url) async {
    try {
      final ref = _storage.refFromURL(url);
      await ref.delete();
    } catch (e) {
      print('ERROR: Failed to delete file: $e');
      rethrow;
    }
  }

  // Notification methods
  static Future<void> saveNotification({
    required String userId,
    required String title,
    required String message,
    required String type,
    String? projectId,
  }) async {
    try {
      final notificationId = DateTime.now().millisecondsSinceEpoch.toString();
      await _firestore.collection('notifications').doc(notificationId).set({
        'id': notificationId,
        'userId': userId,
        'title': title,
        'message': message,
        'type': type,
        'projectId': projectId,
        'isRead': false,
        'createdAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('ERROR: Failed to save notification: $e');
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> getNotifications(
    String userId,
  ) async {
    try {
      final query = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      return query.docs.map((doc) {
        final data = doc.data();
        return {
          'id': data['id'] ?? doc.id,
          'user_id': data['userId'] ?? userId,
          'title': data['title'] ?? '',
          'message': data['message'] ?? '',
          'type': data['type'] ?? '',
          'project_id': data['projectId'],
          'is_read': data['isRead'] ?? false,
          'created_at': data['createdAt'] ?? DateTime.now().toIso8601String(),
        };
      }).toList();
    } catch (e) {
      print('ERROR: Failed to get notifications: $e');
      return [];
    }
  }

  static Future<List<Notification>> getUserNotifications(String userId) async {
    final query = await _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .get();

    return query.docs.map((doc) => Notification.fromMap(doc.data())).toList();
  }

  static Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'isRead': true,
      });
    } catch (e) {
      print('ERROR: Failed to mark notification as read: $e');
      rethrow;
    }
  }

  static Future<void> markAllNotificationsAsRead(String userId) async {
    final batch = _firestore.batch();
    final query = await _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();

    for (final doc in query.docs) {
      batch.update(doc.reference, {'isRead': true});
    }

    await batch.commit();
  }

  static Future<void> deleteNotification(String notificationId) async {
    await _firestore.collection('notifications').doc(notificationId).delete();
  }

  // Activity Logging Operations
  
  static Future<void> _logActivity({
    required String type,
    required String description,
    required String actorId,
    required String actorName,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _firestore.collection('activities').add({
        'type': type,
        'description': description,
        'actorId': actorId,
        'actorName': actorName,
        'timestamp': FieldValue.serverTimestamp(),
        'metadata': metadata,
      });
    } catch (e) {
      print('ERROR: Failed to log activity: $e');
    }
  }

  static Future<void> logTeacherRegistered(User user) async {
    // If not implemented, just a no-op or simple print for now to fix build
    // But since I'm implementing _logActivity, I'll use it.
     await _logActivity(
      type: 'teacher_registration',
      description: 'New teacher registration: ${user.name}',
      actorId: user.id,
      actorName: user.name,
      metadata: {
        'email': user.email,
        'department': user.department,
      },
    );
  }

  static Future<void> logTeacherApproved(User teacher, String adminId) async {
    await _logActivity(
      type: 'teacher_approval',
      description: 'Teacher approved: ${teacher.name}',
      actorId: adminId,
      actorName: 'Admin', 
      metadata: {
        'teacherId': teacher.id,
        'teacherEmail': teacher.email,
      },
    );
  }

  static Future<void> logTeacherRejected(User teacher, String adminId) async {
    await _logActivity(
      type: 'teacher_rejection',
      description: 'Teacher rejected: ${teacher.name}',
      actorId: adminId,
      actorName: 'Admin',
      metadata: {
        'teacherId': teacher.id,
        'teacherEmail': teacher.email,
      },
    );
  }

  static Future<void> logProjectUploaded(Project project) async {
    await _logActivity(
      type: 'project_upload',
      description: 'New project uploaded: ${project.title}',
      actorId: project.authorId,
      actorName: project.authorName,
      metadata: {
        'projectId': project.id,
        'category': project.category.name,
      },
    );
  }

  static Future<void> logProjectStatusChange(
    Project project, 
    ProjectStatus oldStatus, 
    ProjectStatus newStatus, 
    String? actorId, 
    String? actorName
  ) async {
    await _logActivity(
      type: 'project_status_change',
      description: 'Project ${project.title} status changed from ${oldStatus.name} to ${newStatus.name}',
      actorId: actorId ?? 'system',
      actorName: actorName ?? 'System',
      metadata: {
        'projectId': project.id,
        'oldStatus': oldStatus.name,
        'newStatus': newStatus.name,
      },
    );
  }

  static Future<void> logProjectReviewed(Project project, String reviewerName) async {
    await _logActivity(
      type: 'project_reviewed',
      description: 'Project ${project.title} reviewed by $reviewerName',
      actorId: 'unknown', 
      actorName: reviewerName,
      metadata: {
        'projectId': project.id,
      },
    );
  }
}
