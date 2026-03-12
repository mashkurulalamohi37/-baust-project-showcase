import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/user.dart';
import '../models/project.dart';
import '../models/review.dart';
import '../models/team_member.dart';
import '../models/feedback.dart' as feedback_models;
import 'notification_service.dart';
import 'package:projectshowcase/services/imagekit_service.dart';

class FirestoreService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection names
  static const String _usersCollection = 'users';
  static const String _projectsCollection = 'projects';
  static const String _reviewsCollection = 'reviews';
  static const String _bookmarksCollection = 'bookmarks';
  static const String _systemConfigCollection = 'system_config';


  // System settings
  static Future<Map<String, dynamic>> getSystemSettings() async {
    try {
      final doc = await _firestore.collection(_systemConfigCollection).doc('main').get();
      if (!doc.exists) {
        // Create default settings if not exists
        final defaultSettings = {'autoApprovalEnabled': false};
        await _firestore.collection(_systemConfigCollection).doc('main').set(defaultSettings);
        return defaultSettings;
      }
      return doc.data()!;
    } catch (e) {
      print('ERROR: Failed to get system settings: $e');
      return {'autoApprovalEnabled': false};
    }
  }

  static Future<void> updateSystemSettings(Map<String, dynamic> settings) async {
    try {
      await _firestore.collection(_systemConfigCollection).doc('main').set(
        settings,
        SetOptions(merge: true),
      );
    } catch (e) {
      print('ERROR: Failed to update system settings: $e');
      rethrow;
    }
  }

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
        'notificationsEnabled': user.notificationsEnabled,
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
      notificationsEnabled: _boolField(data, 'notificationsEnabled', defaultValue: true),
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
      
      print('FirestoreService: Updating user ${user.id}');
      print('FirestoreService: Designation to save: ${user.designation?.name} (${user.designation?.displayName})');
      
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
        'notificationsEnabled': user.notificationsEnabled,
      });
      print('FirestoreService: User updated successfully: $normalizedEmail');
    } catch (e) {
      print('FirestoreService: ERROR - Failed to update user: $e');
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

  // Maintenance operations
  static Future<void> deleteAllProjects() async {
    final projects = await _firestore.collection(_projectsCollection).get();
    final batch = _firestore.batch();
    for (final doc in projects.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  static Future<void> deleteAllReviews() async {
    final reviews = await _firestore.collection(_reviewsCollection).get();
    final batch = _firestore.batch();
    for (final doc in reviews.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  static Future<void> deleteAllBookmarks() async {
    final bookmarks = await _firestore.collection(_bookmarksCollection).get();
    final batch = _firestore.batch();
    for (final doc in bookmarks.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  static Future<void> deleteAllAnnouncements() async {
    final announcements = await _firestore.collection('announcements').get();
    final batch = _firestore.batch();
    for (final doc in announcements.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  static Future<void> resetDatabase({bool keepUsers = true}) async {
    await deleteAllProjects();
    await deleteAllReviews();
    await deleteAllBookmarks();
    await deleteAllAnnouncements();
    
    if (!keepUsers) {
      final users = await _firestore.collection(_usersCollection).get();
      final batch = _firestore.batch();
      for (final doc in users.docs) {
        final data = doc.data();
        final role = data['role']?.toString().toLowerCase();
        final email = data['email']?.toString().toLowerCase();
        
        // NEVER delete the main admin
        if (role == 'admin' || email == 'ohi82@gmail.com') continue;
        
        batch.delete(doc.reference);
      }
      await batch.commit();
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
        'customCategory': project.customCategory,
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
        'videoUrl': project.videoUrl,
        'studentId': project.studentId,
        'studentName': project.studentName,
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
      final projects = <Project>[];
      for (final doc in query.docs) {
        try {
          final data = doc.data();
          projects.add(Project(
            id: data['id'],
            title: data['title'],
            abstract: data['abstract'],
            authorId: data['authorId'],
            authorName: data['authorName'],
            category: ProjectCategory.values.firstWhere(
              (e) => e.name == data['category'],
              orElse: () => ProjectCategory.other,
            ),
            customCategory: data['customCategory'], // Helper: _optionalString(data, 'customCategory')
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
              orElse: () => ProjectStatus.pending,
            ),
            rating: (data['rating'] ?? 0.0).toDouble(),
            reviewCount: data['reviewCount'] ?? 0,
            createdAt: _parseDateOrNow(data['createdAt']),
            updatedAt: _parseDateOrNow(data['updatedAt']),
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
            videoUrl: data['videoUrl'] ?? data['youtubeUrl'], // Fallback to old data
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
            showcaseMark: (data['showcaseMark'] ?? 0.0).toDouble(),
            evaluations: (data['evaluations'] as List<dynamic>?)
                    ?.map((e) => ShowcaseEvaluation.fromMap(e))
                    .toList() ??
                [],
          ));
        } catch (e) {
          print('FirestoreService: Skipping invalid project doc ${doc.id}: $e');
        }
      }
      return projects;
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

      final projects = <Project>[];
      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();
          projects.add(Project(
            id: data['id'] ?? doc.id,
            title: data['title'] ?? '',
            abstract: data['abstract'] ?? '',
            authorId: data['authorId'] ?? '',
            authorName: data['authorName'] ?? '',
            category: ProjectCategory.values.firstWhere(
              (e) => e.name == data['category'],
              orElse: () => ProjectCategory.other,
            ),
            customCategory: data['customCategory'],
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
            createdAt: _parseDateOrNow(data['createdAt']),
            updatedAt: _parseDateOrNow(data['updatedAt']),
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
            videoUrl: data['videoUrl'] ?? data['youtubeUrl'],
            studentId: data['studentId'],
            studentName: data['studentName'],
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
            showcaseMark: (data['showcaseMark'] ?? 0.0).toDouble(),
            evaluations: (data['evaluations'] as List<dynamic>?)
                    ?.map((e) => ShowcaseEvaluation.fromMap(e))
                    .toList() ??
                [],
          ));
        } catch (e) {
          print('FirestoreService: Skipping invalid project doc ${doc.id}: $e');
        }
      }
      return projects;
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
        videoUrl: data['videoUrl'] ?? data['youtubeUrl'],
        studentId: data['studentId'],
        studentName: data['studentName'],
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
        showcaseMark: (data['showcaseMark'] ?? 0.0).toDouble(),
        evaluations: (data['evaluations'] as List<dynamic>?)
                ?.map((e) => ShowcaseEvaluation.fromMap(e))
                .toList() ??
            [],
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
        'showcaseMark': project.showcaseMark,
        'evaluations': project.evaluations.map((e) => e.toMap()).toList(),
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
  static Future<String?> uploadFile(
    String path, 
    String fileName, {
    Uint8List? data,
    Function(double)? onProgress,
  }) async {
    try {
      print('FirestoreService: ========== UPLOAD START ==========');
      print('FirestoreService: Uploading file to ImageKit');
      
      final imageKit = ImageKitService();
      
      // Use provided path on mobile, fallback to fileName on web
      final actualPath = path.trim().isNotEmpty ? path : fileName;
      print('FirestoreService: Actual path resolving to: $actualPath');

      // Upload to ImageKit
      final url = await imageKit.uploadFile(
        actualPath,
        fileName: fileName,
        folder: 'projectshowcase',
        bytes: data,
        onProgress: onProgress,
      );
      
      if (url != null) {
        print('FirestoreService: Upload successful: $url');
        print('FirestoreService: ========== UPLOAD SUCCESS ==========');
        return url;
      } else {
        print('FirestoreService: Upload failed - no URL returned');
        print('FirestoreService: ========== UPLOAD FAILED ==========');
        throw Exception('Upload failed - no URL returned');
      }
    } catch (e) {
      print('FirestoreService: Error uploading file to ImageKit: $e');
      print('FirestoreService: ========== UPLOAD ERROR ==========');
      rethrow;
    }
  }

  static Future<List<String>> uploadMultipleFiles(
    List<String> paths,
    String folder, {
    List<Uint8List>? dataList,
    Function(double)? onProgress,
  }) async {
    try {
      final imageKit = ImageKitService();
      final urls = <String>[];
      
      if (dataList != null && dataList.isNotEmpty) {
        // Web: Upload from bytes
        for (int i = 0; i < dataList.length; i++) {
          final fileName = '${folder}_${DateTime.now().millisecondsSinceEpoch}_$i';
          final url = await imageKit.uploadFile(
            '', // No path for bytes
            fileName: fileName,
            folder: 'projectshowcase/$folder',
            bytes: dataList[i],
            onProgress: onProgress != null ? (p) => onProgress((i + p) / dataList.length) : null,
          );
          if (url != null) urls.add(url);
        }
      } else {
        // Mobile: Upload from file paths
        for (int i = 0; i < paths.length; i++) {
          final path = paths[i];
          final fileName = path.split('/').last;
          final url = await imageKit.uploadFile(
            path,
            fileName: fileName,
            folder: 'projectshowcase/$folder',
            onProgress: onProgress != null ? (p) => onProgress((i + p) / paths.length) : null,
          );
          if (url != null) urls.add(url);
        }
      }
      
      return urls;
    } catch (e) {
      print('Error uploading multiple files to ImageKit: $e');
      rethrow;
    }
  }

  // Delete file - disabled for now to prevent accidental deletion during migration
  static Future<void> deleteFile(String url) async {
    try {
      print('FirestoreService: deleteFile is currently disabled to protect legacy uploads.');
    } catch (e) {
      print('ERROR: Failed to delete file: $e');
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
