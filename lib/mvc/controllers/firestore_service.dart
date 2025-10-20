import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/user.dart';
import '../models/project.dart';

class FirestoreService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  // Collections
  static const String _usersCollection = 'users';
  static const String _projectsCollection = 'projects';
  static const String _reviewsCollection = 'reviews';
  static const String _bookmarksCollection = 'bookmarks';

  // Helper method to parse dates
  static DateTime? parseDate(dynamic dateValue) {
    if (dateValue == null) return null;
    try {
      return DateTime.parse(dateValue.toString());
    } catch (e) {
      print('DEBUG: Error parsing date $dateValue: $e');
      return null;
    }
  }

  // User operations
  static Future<void> saveUser(User user) async {
    try {
      print('FirestoreService: Saving user ${user.name} with ID ${user.id}');
      print('FirestoreService: User role: ${user.role.name}, Approved: ${user.isApproved}');
      
      await _firestore.collection(_usersCollection).doc(user.id).set({
        'id': user.id,
        'name': user.name,
        'email': user.email,
        'role': user.role.name,
        'createdAt': user.createdAt.toIso8601String(),
        'profileImageUrl': user.profileImageUrl,
        'isApproved': user.isApproved,
        'approvedAt': user.approvedAt?.toIso8601String(),
        'approvedBy': user.approvedBy,
        'department': user.department,
        'employeeId': user.employeeId,
        'phoneNumber': user.phoneNumber,
        'lastLoginAt': user.lastLoginAt?.toIso8601String(),
        'isActive': user.isActive,
      });
      
      print('FirestoreService: User saved successfully');
    } catch (e) {
      print('ERROR: Failed to save user: $e');
      print('ERROR: Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  static Future<User?> getUser(String userId) async {
    try {
      final doc = await _firestore.collection(_usersCollection).doc(userId).get();
      if (!doc.exists) return null;
      
      final data = doc.data()!;
      print('DEBUG: Raw user data from Firestore: $data');
      print('DEBUG: Data type: ${data.runtimeType}');
      
      // Create a safe data map by converting all values to proper types
      final safeData = <String, dynamic>{};
      data.forEach((key, value) {
        if (value != null) {
          if (value is List) {
            // Handle list values - convert to string or skip
            print('DEBUG: Found list value for $key: $value');
            safeData[key] = value.toString();
          } else {
            safeData[key] = value;
          }
        }
      });
      
      print('DEBUG: Safe data map: $safeData');
      
      // Safely parse role
      UserRole userRole = UserRole.student;
      if (safeData['role'] != null) {
        final roleValue = safeData['role'];
        if (roleValue is String) {
          try {
            userRole = UserRole.values.firstWhere(
              (e) => e.name == roleValue, 
              orElse: () => UserRole.student
            );
          } catch (e) {
            print('DEBUG: Error parsing role $roleValue: $e');
            userRole = UserRole.student;
          }
        } else {
          print('DEBUG: Role is not a string: $roleValue (${roleValue.runtimeType})');
        }
      }
      
      // Safely parse dates
      DateTime? parseDate(dynamic dateValue) {
        if (dateValue == null) return null;
        try {
          return DateTime.parse(dateValue.toString());
        } catch (e) {
          print('DEBUG: Error parsing date $dateValue: $e');
          return null;
        }
      }
      
      return User(
        id: safeData['id']?.toString() ?? userId,
        name: safeData['name']?.toString() ?? 'User',
        email: safeData['email']?.toString() ?? '',
        role: userRole,
        createdAt: parseDate(safeData['createdAt']) ?? DateTime.now(),
        profileImageUrl: safeData['profileImageUrl']?.toString(),
        isApproved: safeData['isApproved'] ?? true,
        approvedAt: parseDate(safeData['approvedAt']),
        approvedBy: safeData['approvedBy']?.toString(),
        department: safeData['department']?.toString(),
        employeeId: safeData['employeeId']?.toString(),
        phoneNumber: safeData['phoneNumber']?.toString(),
        lastLoginAt: parseDate(safeData['lastLoginAt']),
        isActive: safeData['isActive'] ?? true,
      );
    } catch (e) {
      print('ERROR: Failed to get user from Firestore: $e');
      print('ERROR: Stack trace: ${StackTrace.current}');
      return null;
    }
  }

  static Future<User?> getUserByEmail(String email) async {
    try {
      final query = await _firestore
          .collection(_usersCollection)
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      
      if (query.docs.isEmpty) return null;
      
      final data = query.docs.first.data();
      print('DEBUG: Raw user data by email from Firestore: $data');
      print('DEBUG: Data type: ${data.runtimeType}');
      
      // Create a safe data map by converting all values to proper types
      final safeData = <String, dynamic>{};
      data.forEach((key, value) {
        if (value != null) {
          if (value is List) {
            // Handle list values - convert to string or skip
            print('DEBUG: Found list value for $key: $value');
            safeData[key] = value.toString();
          } else {
            safeData[key] = value;
          }
        }
      });
      
      print('DEBUG: Safe data map: $safeData');
      
      // Safely parse role
      UserRole userRole = UserRole.student;
      if (safeData['role'] != null) {
        final roleValue = safeData['role'];
        if (roleValue is String) {
          try {
            userRole = UserRole.values.firstWhere(
              (e) => e.name == roleValue, 
              orElse: () => UserRole.student
            );
          } catch (e) {
            print('DEBUG: Error parsing role $roleValue: $e');
            userRole = UserRole.student;
          }
        } else {
          print('DEBUG: Role is not a string: $roleValue (${roleValue.runtimeType})');
        }
      }
      
      // Safely parse dates
      DateTime? parseDate(dynamic dateValue) {
        if (dateValue == null) return null;
        try {
          return DateTime.parse(dateValue.toString());
        } catch (e) {
          print('DEBUG: Error parsing date $dateValue: $e');
          return null;
        }
      }
      
      return User(
        id: safeData['id']?.toString() ?? query.docs.first.id,
        name: safeData['name']?.toString() ?? 'User',
        email: safeData['email']?.toString() ?? email,
        role: userRole,
        createdAt: parseDate(safeData['createdAt']) ?? DateTime.now(),
        profileImageUrl: safeData['profileImageUrl']?.toString(),
        isApproved: safeData['isApproved'] ?? true,
        approvedAt: parseDate(safeData['approvedAt']),
        approvedBy: safeData['approvedBy']?.toString(),
        department: safeData['department']?.toString(),
        employeeId: safeData['employeeId']?.toString(),
        phoneNumber: safeData['phoneNumber']?.toString(),
        lastLoginAt: parseDate(safeData['lastLoginAt']),
        isActive: safeData['isActive'] ?? true,
      );
    } catch (e) {
      print('ERROR: Failed to get user by email from Firestore: $e');
      print('ERROR: Stack trace: ${StackTrace.current}');
      return null;
    }
  }


  // Project operations
  static Future<void> saveProject(Project project) async {
    await _firestore.collection(_projectsCollection).doc(project.id).set({
      'id': project.id,
      'title': project.title,
      'abstract': project.abstract,
      'authorId': project.authorId,
      'authorName': project.authorName,
      'category': project.category.name,
      'year': project.year,
      'createdAt': project.createdAt.toIso8601String(),
      'updatedAt': project.updatedAt.toIso8601String(),
      'status': project.status.name,
      'rating': project.rating,
      'reviewCount': project.reviewCount,
      'imageUrls': project.imageUrls,
      'pdfUrl': project.pdfUrl,
      'githubUrl': project.githubUrl,
      'tags': project.tags,
      'isFeatured': project.isFeatured,
      'facultyId': project.facultyId,
      'facultyName': project.facultyName,
    });
  }

  static Future<Project?> getProject(String projectId) async {
    final doc = await _firestore.collection(_projectsCollection).doc(projectId).get();
    if (!doc.exists) return null;
    
    final data = doc.data()!;
    return Project(
      id: data['id'],
      title: data['title'],
      abstract: data['abstract'],
      authorId: data['authorId'],
      authorName: data['authorName'],
      category: ProjectCategory.values.firstWhere((e) => e.name == data['category']),
      year: data['year'],
      createdAt: DateTime.parse(data['createdAt']),
      updatedAt: DateTime.parse(data['updatedAt']),
      status: ProjectStatus.values.firstWhere((e) => e.name == data['status']),
      rating: (data['rating'] ?? 0.0).toDouble(),
      reviewCount: data['reviewCount'] ?? 0,
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      pdfUrl: data['pdfUrl'],
      githubUrl: data['githubUrl'],
      tags: List<String>.from(data['tags'] ?? []),
      isFeatured: data['isFeatured'] ?? false,
      facultyId: data['facultyId'],
      facultyName: data['facultyName'],
    );
  }

  static Future<List<Project>> getAllProjects() async {
    final query = await _firestore.collection(_projectsCollection).get();
    return query.docs.map((doc) {
      final data = doc.data();
      return Project(
        id: data['id'],
        title: data['title'],
        abstract: data['abstract'],
        authorId: data['authorId'],
        authorName: data['authorName'],
        category: ProjectCategory.values.firstWhere((e) => e.name == data['category']),
        year: data['year'],
        createdAt: DateTime.parse(data['createdAt']),
        updatedAt: DateTime.parse(data['updatedAt']),
        status: ProjectStatus.values.firstWhere((e) => e.name == data['status']),
        rating: (data['rating'] ?? 0.0).toDouble(),
        reviewCount: data['reviewCount'] ?? 0,
        imageUrls: List<String>.from(data['imageUrls'] ?? []),
        pdfUrl: data['pdfUrl'],
        githubUrl: data['githubUrl'],
        tags: List<String>.from(data['tags'] ?? []),
        isFeatured: data['isFeatured'] ?? false,
        facultyId: data['facultyId'],
        facultyName: data['facultyName'],
      );
    }).toList();
  }

  static Future<List<Project>> getProjectsByStatus(ProjectStatus status) async {
    final query = await _firestore
        .collection(_projectsCollection)
        .where('status', isEqualTo: status.name)
        .get();
    
    return query.docs.map((doc) {
      final data = doc.data();
      return Project(
        id: data['id'],
        title: data['title'],
        abstract: data['abstract'],
        authorId: data['authorId'],
        authorName: data['authorName'],
        category: ProjectCategory.values.firstWhere((e) => e.name == data['category']),
        year: data['year'],
        createdAt: DateTime.parse(data['createdAt']),
        updatedAt: DateTime.parse(data['updatedAt']),
        status: ProjectStatus.values.firstWhere((e) => e.name == data['status']),
        rating: (data['rating'] ?? 0.0).toDouble(),
        reviewCount: data['reviewCount'] ?? 0,
        imageUrls: List<String>.from(data['imageUrls'] ?? []),
        pdfUrl: data['pdfUrl'],
        githubUrl: data['githubUrl'],
        tags: List<String>.from(data['tags'] ?? []),
        isFeatured: data['isFeatured'] ?? false,
        facultyId: data['facultyId'],
        facultyName: data['facultyName'],
      );
    }).toList();
  }

  static Future<void> deleteProject(String projectId) async {
    await _firestore.collection(_projectsCollection).doc(projectId).delete();
  }

  // Review operations
  static Future<void> saveReview(Review review) async {
    await _firestore.collection(_reviewsCollection).doc(review.id).set({
      'id': review.id,
      'projectId': review.projectId,
      'reviewerId': review.reviewerId,
      'reviewerName': review.reviewerName,
      'rating': review.rating,
      'comment': review.comment,
      'createdAt': review.createdAt.toIso8601String(),
    });
  }

  static Future<List<Review>> getReviewsForProject(String projectId) async {
    final query = await _firestore
        .collection(_reviewsCollection)
        .where('projectId', isEqualTo: projectId)
        .orderBy('createdAt', descending: true)
        .get();
    
    return query.docs.map((doc) {
      final data = doc.data();
      return Review(
        id: data['id'],
        projectId: data['projectId'],
        reviewerId: data['reviewerId'],
        reviewerName: data['reviewerName'],
        rating: data['rating'],
        comment: data['comment'],
        createdAt: DateTime.parse(data['createdAt']),
      );
    }).toList();
  }

  static Future<void> deleteReview(String reviewId) async {
    await _firestore.collection(_reviewsCollection).doc(reviewId).delete();
  }

  static Future<List<Review>> getAllReviews() async {
    final query = await _firestore
        .collection(_reviewsCollection)
        .orderBy('createdAt', descending: true)
        .get();
    
    return query.docs.map((doc) {
      final data = doc.data();
      return Review(
        id: data['id'],
        projectId: data['projectId'],
        reviewerId: data['reviewerId'],
        reviewerName: data['reviewerName'],
        rating: data['rating'],
        comment: data['comment'],
        createdAt: DateTime.parse(data['createdAt']),
      );
    }).toList();
  }

  // Bookmark operations
  static Future<void> saveBookmark(String userId, String projectId) async {
    await _firestore
        .collection('bookmarks')
        .doc('${userId}_$projectId')
        .set({
      'userId': userId,
      'projectId': projectId,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  static Future<void> removeBookmark(String userId, String projectId) async {
    await _firestore
        .collection('bookmarks')
        .doc('${userId}_$projectId')
        .delete();
  }

  static Future<bool> isBookmarked(String userId, String projectId) async {
    final doc = await _firestore
        .collection('bookmarks')
        .doc('${userId}_$projectId')
        .get();
    return doc.exists;
  }

  static Future<List<String>> getUserBookmarks(String userId) async {
    final query = await _firestore
        .collection('bookmarks')
        .where('userId', isEqualTo: userId)
        .get();
    
    return query.docs.map((doc) => doc.data()['projectId'] as String).toList();
  }

  // Feedback operations
  static Future<void> saveFeedback(ProjectFeedback feedback) async {
    await _firestore.collection('feedback').doc(feedback.id).set({
      'id': feedback.id,
      'projectId': feedback.projectId,
      'reviewerId': feedback.reviewerId,
      'reviewerName': feedback.reviewerName,
      'comment': feedback.comment,
      'type': feedback.type.name,
      'createdAt': feedback.createdAt.toIso8601String(),
    });
  }

  static Future<void> deleteFeedback(String feedbackId) async {
    await _firestore.collection('feedback').doc(feedbackId).delete();
  }

  static Future<List<ProjectFeedback>> getFeedbackForProject(String projectId) async {
    final query = await _firestore
        .collection('feedback')
        .where('projectId', isEqualTo: projectId)
        .orderBy('createdAt', descending: true)
        .get();
    
    return query.docs.map((doc) {
      final data = doc.data();
      return ProjectFeedback(
        id: data['id'],
        projectId: data['projectId'],
        reviewerId: data['reviewerId'],
        reviewerName: data['reviewerName'],
        comment: data['comment'],
        type: FeedbackType.values.firstWhere((e) => e.name == data['type']),
        createdAt: DateTime.parse(data['createdAt']),
      );
    }).toList();
  }

  // Notification operations
  static Future<void> saveNotification(Notification notification) async {
    await _firestore.collection('notifications').doc(notification.id).set(notification.toMap());
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
    await _firestore.collection('notifications').doc(notificationId).update({'isRead': true});
  }

  static Future<void> markAllNotificationsAsRead(String userId) async {
    final batch = _firestore.batch();
    final notifications = await _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();
    
    for (final doc in notifications.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    
    await batch.commit();
  }

  static Future<void> deleteNotification(String notificationId) async {
    await _firestore.collection('notifications').doc(notificationId).delete();
  }

  static Future<List<Review>> getAllReviews() async {
    final query = await _firestore.collection(_reviewsCollection).get();
    return query.docs.map((doc) {
      final data = doc.data();
      return Review(
        id: data['id'],
        projectId: data['projectId'],
        reviewerId: data['reviewerId'],
        reviewerName: data['reviewerName'],
        rating: (data['rating'] ?? 0.0).toDouble(),
        comment: data['comment'],
        createdAt: DateTime.parse(data['createdAt']),
      );
    }).toList();
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
    final query = await _firestore
        .collection(_bookmarksCollection)
        .where('userId', isEqualTo: userId)
        .get();
    
    return query.docs.map((doc) => doc.data()['projectId'] as String).toList();
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

  // File upload operations
  static Future<String> uploadFile(String path, String fileName) async {
    final ref = _storage.ref().child('uploads/$fileName');
    await ref.putFile(File(path));
    return await ref.getDownloadURL();
  }

  static Future<List<String>> uploadMultipleFiles(List<String> paths, String folder) async {
    final urls = <String>[];
    for (int i = 0; i < paths.length; i++) {
      final fileName = '${folder}_${DateTime.now().millisecondsSinceEpoch}_$i';
      final ref = _storage.ref().child('uploads/$folder/$fileName');
      await ref.putFile(File(paths[i]));
      final url = await ref.getDownloadURL();
      urls.add(url);
    }
    return urls;
  }

  // Profile image upload
  static Future<String> uploadProfileImage(String path, String userId) async {
    final fileName = 'profiles/$userId/profile_${DateTime.now().millisecondsSinceEpoch}';
    return await uploadFile(path, fileName);
  }

  // Update user profile
  static Future<void> updateUserProfile(String userId, Map<String, dynamic> updates) async {
    await _firestore.collection(_usersCollection).doc(userId).update(updates);
  }

  // Get projects by author
  static Future<List<Project>> getProjectsByAuthor(String authorId) async {
    final query = await _firestore
        .collection(_projectsCollection)
        .where('authorId', isEqualTo: authorId)
        .get();
    
    return query.docs.map((doc) {
      final data = doc.data();
      return Project(
        id: data['id'],
        title: data['title'],
        abstract: data['abstract'],
        authorId: data['authorId'],
        authorName: data['authorName'],
        category: ProjectCategory.values.firstWhere((e) => e.name == data['category']),
        year: data['year'],
        createdAt: DateTime.parse(data['createdAt']),
        updatedAt: DateTime.parse(data['updatedAt']),
        status: ProjectStatus.values.firstWhere((e) => e.name == data['status']),
        rating: (data['rating'] ?? 0.0).toDouble(),
        reviewCount: data['reviewCount'] ?? 0,
        imageUrls: List<String>.from(data['imageUrls'] ?? []),
        pdfUrl: data['pdfUrl'],
        githubUrl: data['githubUrl'],
        tags: List<String>.from(data['tags'] ?? []),
        isFeatured: data['isFeatured'] ?? false,
        facultyId: data['facultyId'],
        facultyName: data['facultyName'],
      );
    }).toList();
  }

  // Search projects
  static Future<List<Project>> searchProjects(String query) async {
    // Note: This is a simple implementation. For better search, consider using Algolia or similar
    final allProjects = await getAllProjects();
    final lowercaseQuery = query.toLowerCase();
    
    return allProjects.where((project) =>
      project.title.toLowerCase().contains(lowercaseQuery) ||
      project.abstract.toLowerCase().contains(lowercaseQuery) ||
      project.tags.any((tag) => tag.toLowerCase().contains(lowercaseQuery)) ||
      project.authorName.toLowerCase().contains(lowercaseQuery)
    ).toList();
  }

  // Get all users (for admin management)
  static Future<List<User>> getAllUsers() async {
    try {
      print('FirestoreService: Getting all users from collection $_usersCollection');
      final querySnapshot = await _firestore.collection(_usersCollection).get();
      print('FirestoreService: Retrieved ${querySnapshot.docs.length} user documents');
      
      final users = <User>[];
      
      for (final doc in querySnapshot.docs) {
        try {
          final data = doc.data();
          print('FirestoreService: Processing user document ${doc.id}');
          final user = User(
            id: doc.id,
            email: data['email']?.toString() ?? '',
            name: data['name']?.toString() ?? '',
            role: UserRole.values.firstWhere(
              (role) => role.name == data['role']?.toString(),
              orElse: () => UserRole.student,
            ),
            createdAt: parseDate(data['createdAt']) ?? DateTime.now(),
            isApproved: data['isApproved'] ?? false,
            approvedAt: parseDate(data['approvedAt']),
            approvedBy: data['approvedBy']?.toString(),
            department: data['department']?.toString(),
            employeeId: data['employeeId']?.toString(),
            phoneNumber: data['phoneNumber']?.toString(),
            lastLoginAt: parseDate(data['lastLoginAt']),
            isActive: data['isActive'] ?? true,
          );
          users.add(user);
          print('FirestoreService: Successfully parsed user ${user.name}');
        } catch (e) {
          print('ERROR: Failed to parse user ${doc.id}: $e');
          continue;
        }
      }
      
      print('FirestoreService: Returning ${users.length} users');
      return users;
    } catch (e) {
      print('ERROR: Failed to get all users: $e');
      print('ERROR: Stack trace: ${StackTrace.current}');
      return [];
    }
  }

  // Delete user
  static Future<void> deleteUser(String userId) async {
    try {
      await _firestore.collection(_usersCollection).doc(userId).delete();
      print('User $userId deleted successfully');
    } catch (e) {
      print('ERROR: Failed to delete user $userId: $e');
      rethrow;
    }
  }

  // Feedback operations
  static Future<void> saveFeedback(ProjectFeedback feedback) async {
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

  static Future<List<ProjectFeedback>> getProjectFeedback(String projectId) async {
    try {
      final snapshot = await _firestore
          .collection('project_feedback')
          .where('projectId', isEqualTo: projectId)
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return ProjectFeedback(
          id: data['id'],
          projectId: data['projectId'],
          reviewerId: data['reviewerId'],
          reviewerName: data['reviewerName'],
          comment: data['comment'],
          type: FeedbackType.values.firstWhere((e) => e.name == data['type']),
          createdAt: DateTime.parse(data['createdAt']),
          isResolved: data['isResolved'] ?? false,
        );
      }).toList();
    } catch (e) {
      print('ERROR: Failed to get project feedback: $e');
      return [];
    }
  }

  // Project version operations
  static Future<void> saveProjectVersion(ProjectVersion version) async {
    try {
      await _firestore.collection('project_versions').doc(version.id).set({
        'id': version.id,
        'projectId': version.projectId,
        'versionNumber': version.versionNumber,
        'title': version.title,
        'abstract': version.abstract,
        'imageUrls': version.imageUrls,
        'pdfUrl': version.pdfUrl,
        'githubUrl': version.githubUrl,
        'createdAt': version.createdAt.toIso8601String(),
        'changeDescription': version.changeDescription,
      });
      print('Project version saved successfully: ${version.versionNumber}');
    } catch (e) {
      print('ERROR: Failed to save project version: $e');
      rethrow;
    }
  }

  static Future<List<ProjectVersion>> getProjectVersions(String projectId) async {
    try {
      final snapshot = await _firestore
          .collection('project_versions')
          .where('projectId', isEqualTo: projectId)
          .orderBy('versionNumber')
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return ProjectVersion(
          id: data['id'],
          projectId: data['projectId'],
          versionNumber: data['versionNumber'],
          title: data['title'],
          abstract: data['abstract'],
          imageUrls: List<String>.from(data['imageUrls'] ?? []),
          pdfUrl: data['pdfUrl'],
          githubUrl: data['githubUrl'],
          createdAt: DateTime.parse(data['createdAt']),
          changeDescription: data['changeDescription'],
        );
      }).toList();
    } catch (e) {
      print('ERROR: Failed to get project versions: $e');
      return [];
    }
  }
}
