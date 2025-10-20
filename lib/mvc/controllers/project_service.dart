import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../models/project.dart';
import 'firestore_service.dart';
import 'notification_service.dart';

class ProjectService extends ChangeNotifier {
  // Singleton instance so project data is shared app-wide
  static final ProjectService _instance = ProjectService._internal();
  factory ProjectService() => _instance;
  ProjectService._internal() {
    // Don't load projects immediately to prevent blocking
    // Projects will be loaded when needed
  }

  final List<Project> _projects = [];
  final List<Review> _reviews = [];
  final List<String> _bookmarkedProjectIds = [];
  bool _isLoading = false;
  bool _initialized = false;

  List<Project> get projects => List.unmodifiable(_projects);
  List<Review> get reviews => List.unmodifiable(_reviews);
  List<String> get bookmarkedProjectIds => List.unmodifiable(_bookmarkedProjectIds);
  bool get isLoading => _isLoading;

  List<Project> get featuredProjects => 
      _projects.where((p) => p.isFeatured).toList();

  List<Project> get trendingProjects => 
      _projects.where((p) => p.status == ProjectStatus.approved)
          .toList()
          ..sort((a, b) => b.rating.compareTo(a.rating));

  List<Project> get bookmarkedProjects =>
      _projects.where((p) => _bookmarkedProjectIds.contains(p.id)).toList();

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  Future<void> _loadProjects() async {
    if (_initialized) return;
    _setLoading(true);
    debugPrint('ProjectService: Loading projects from Firestore');
    
    try {
      // Load projects from Firestore
      final projects = await FirestoreService.getAllProjects();
      debugPrint('ProjectService: Loaded ${projects.length} projects from Firestore');
      
      _projects.clear();
      _projects.addAll(projects);
      
      // Load reviews from Firestore
      final reviews = await FirestoreService.getAllReviews();
      debugPrint('ProjectService: Loaded ${reviews.length} reviews from Firestore');
      
      _reviews.clear();
      _reviews.addAll(reviews);
      
      _initialized = true;
      _setLoading(false);
      notifyListeners();
      debugPrint('ProjectService: Projects and reviews loaded successfully');
    } catch (e) {
      debugPrint('ProjectService: Error loading projects from Firestore: $e');
      
      // Fallback to empty state if Firestore fails
      _projects.clear();
      _reviews.clear();
      
      _initialized = true;
      _setLoading(false);
      notifyListeners();
    }
  }

  Future<void> ensureProjectsLoaded() async {
    if (!_initialized) {
      await _loadProjects();
    }
  }

  Future<bool> createProject(Project project) async {
    _setLoading(true);
    debugPrint('ProjectService: Starting project creation for ${project.title}');
    
    try {
      String? pdfUrl;
      List<String> imageUrls = [];
      
      // Upload PDF if exists
      if (project.pdfUrl != null && project.pdfUrl!.isNotEmpty) {
        debugPrint('ProjectService: Uploading PDF file');
        pdfUrl = await _uploadFile(project.pdfUrl!, 'pdfs', 'pdf');
        if (pdfUrl == null) {
          debugPrint('ProjectService: Failed to upload PDF');
          _setLoading(false);
          return false;
        }
      }
      
      // Upload images if exist
      if (project.imageUrls.isNotEmpty) {
        debugPrint('ProjectService: Uploading ${project.imageUrls.length} image files');
        for (int i = 0; i < project.imageUrls.length; i++) {
          final imageUrl = await _uploadFile(project.imageUrls[i], 'images', 'jpg');
          if (imageUrl != null) {
            imageUrls.add(imageUrl);
          } else {
            debugPrint('ProjectService: Failed to upload image ${i + 1}');
          }
        }
      }
      
      // Create project with uploaded file URLs
      final projectWithUrls = project.copyWith(
        imageUrls: imageUrls,
        pdfUrl: pdfUrl,
      );
      
      debugPrint('ProjectService: Saving project to Firestore');
      await FirestoreService.saveProject(projectWithUrls);
      _projects.add(projectWithUrls);
      _setLoading(false);
      notifyListeners();
      debugPrint('ProjectService: Project created successfully');
      return true;
    } catch (e) {
      debugPrint('ProjectService: Error creating project: $e');
      debugPrint('ProjectService: Stack trace: ${StackTrace.current}');
      _setLoading(false);
      return false;
    }
  }

  Future<bool> updateProject(Project project) async {
    _setLoading(true);
    
    try {
      // Get the original project to check for status changes
      final originalProject = _projects.firstWhere((p) => p.id == project.id);
      final statusChanged = originalProject.status != project.status;
      
      await FirestoreService.saveProject(project);
      
      final index = _projects.indexWhere((p) => p.id == project.id);
      if (index != -1) {
        _projects[index] = project;
      } else {
        _projects.add(project);
      }
      
      // Send notifications for status changes
      if (statusChanged) {
        await _sendStatusChangeNotifications(originalProject, project);
      }
      
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error updating project: $e');
      _setLoading(false);
      return false;
    }
  }

  Future<void> _sendStatusChangeNotifications(Project originalProject, Project updatedProject) async {
    final notificationService = NotificationService();
    
    switch (updatedProject.status) {
      case ProjectStatus.approved:
        if (originalProject.status != ProjectStatus.approved) {
          await notificationService.notifyProjectApproved(updatedProject.authorId, updatedProject);
        }
        break;
      case ProjectStatus.rejected:
        if (originalProject.status != ProjectStatus.rejected) {
          await notificationService.notifyProjectRejected(updatedProject.authorId, updatedProject);
        }
        break;
      case ProjectStatus.featured:
        if (originalProject.status != ProjectStatus.featured) {
          await notificationService.notifyProjectFeatured(updatedProject.authorId, updatedProject);
        }
        break;
      case ProjectStatus.needsRevision:
        if (originalProject.status != ProjectStatus.needsRevision) {
          await notificationService.notifyProjectNeedsRevision(updatedProject.authorId, updatedProject);
        }
        break;
      default:
        break;
    }
  }

  Future<bool> deleteProject(String projectId) async {
    _setLoading(true);
    
    try {
      // Find the project to get file URLs
      final project = _projects.firstWhere((p) => p.id == projectId);
      
      // Delete files from Firebase Storage
      await deleteProjectFiles(project);
      
      // Delete project from Firestore
      await FirestoreService.deleteProject(projectId);
      
      // Remove from local list
      _projects.removeWhere((p) => p.id == projectId);
      
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error deleting project: $e');
      _setLoading(false);
      return false;
    }
  }

  // Review and Rating System
  Future<bool> addReview(String projectId, int rating, String comment) async {
    _setLoading(true);
    
    try {
      final review = Review(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        projectId: projectId,
        reviewerId: _getCurrentUserId(),
        reviewerName: 'Current User', // Get from auth service
        rating: rating,
        comment: comment,
        createdAt: DateTime.now(),
      );

      await FirestoreService.saveReview(review);
      
      // Update project rating
      final project = _projects.firstWhere((p) => p.id == projectId);
      final updatedRating = _calculateAverageRating(projectId);
      final updatedProject = project.copyWith(
        rating: updatedRating,
        reviewCount: project.reviewCount + 1,
      );
      
      await updateProject(updatedProject);
      _reviews.add(review);
      
      // Send notification for new review
      final notificationService = NotificationService();
      await notificationService.notifyNewReview(project.authorId, project, review.reviewerName);
      
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error adding review: $e');
      _setLoading(false);
      return false;
    }
  }

  Future<bool> updateReview(String reviewId, int rating, String comment) async {
    _setLoading(true);
    
    try {
      final reviewIndex = _reviews.indexWhere((r) => r.id == reviewId);
      if (reviewIndex == -1) {
        _setLoading(false);
        return false;
      }

      final updatedReview = _reviews[reviewIndex].copyWith(
        rating: rating,
        comment: comment,
        createdAt: DateTime.now(),
      );

      await FirestoreService.saveReview(updatedReview);
      _reviews[reviewIndex] = updatedReview;
      
      // Update project rating
      final project = _projects.firstWhere((p) => p.id == updatedReview.projectId);
      final updatedRating = _calculateAverageRating(updatedReview.projectId);
      final updatedProject = project.copyWith(rating: updatedRating);
      await updateProject(updatedProject);
      
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error updating review: $e');
      _setLoading(false);
      return false;
    }
  }

  Future<bool> deleteReview(String reviewId) async {
    _setLoading(true);
    
    try {
      final review = _reviews.firstWhere((r) => r.id == reviewId);
      await FirestoreService.deleteReview(reviewId);
      _reviews.removeWhere((r) => r.id == reviewId);
      
      // Update project rating
      final project = _projects.firstWhere((p) => p.id == review.projectId);
      final updatedRating = _calculateAverageRating(review.projectId);
      final updatedProject = project.copyWith(
        rating: updatedRating,
        reviewCount: project.reviewCount - 1,
      );
      await updateProject(updatedProject);
      
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error deleting review: $e');
      _setLoading(false);
      return false;
    }
  }

  double _calculateAverageRating(String projectId) {
    final projectReviews = _reviews.where((r) => r.projectId == projectId);
    if (projectReviews.isEmpty) return 0.0;
    
    final totalRating = projectReviews.fold<int>(0, (sum, review) => sum + review.rating);
    return totalRating / projectReviews.length;
  }

  List<Review> getReviewsForProject(String projectId) {
    return _reviews.where((r) => r.projectId == projectId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> toggleBookmark(String projectId) async {
    try {
      final isBookmarked = await FirestoreService.isBookmarked(
        _getCurrentUserId(), 
        projectId
      );
      
      if (isBookmarked) {
        await FirestoreService.removeBookmark(_getCurrentUserId(), projectId);
        _bookmarkedProjectIds.remove(projectId);
      } else {
        await FirestoreService.addBookmark(_getCurrentUserId(), projectId);
        _bookmarkedProjectIds.add(projectId);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error toggling bookmark: $e');
    }
  }

  bool isBookmarked(String projectId) {
    return _bookmarkedProjectIds.contains(projectId);
  }

  Future<bool> addReview(Review review) async {
    _setLoading(true);
    
    try {
      await FirestoreService.saveReview(review);
      _reviews.add(review);
      
      // Update project rating
      final projectIndex = _projects.indexWhere((p) => p.id == review.projectId);
      if (projectIndex != -1) {
        final project = _projects[projectIndex];
        final projectReviews = _reviews.where((r) => r.projectId == project.id).toList();
        final averageRating = projectReviews.map((r) => r.rating).reduce((a, b) => a + b) / projectReviews.length;
        
        _projects[projectIndex] = project.copyWith(
          rating: averageRating,
          reviewCount: projectReviews.length,
        );
        
        // Update in Firestore
        await FirestoreService.saveProject(_projects[projectIndex]);
      }
      
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error adding review: $e');
      _setLoading(false);
      return false;
    }
  }

  List<Project> searchProjects(String query) {
    if (query.isEmpty) return _projects;
    
    final lowercaseQuery = query.toLowerCase();
    return _projects.where((project) =>
      project.title.toLowerCase().contains(lowercaseQuery) ||
      project.abstract.toLowerCase().contains(lowercaseQuery) ||
      project.tags.any((tag) => tag.toLowerCase().contains(lowercaseQuery)) ||
      project.authorName.toLowerCase().contains(lowercaseQuery)
    ).toList();
  }

  List<Project> filterProjectsByCategory(ProjectCategory category) {
    return _projects.where((project) => project.category == category).toList();
  }

  List<Project> filterProjectsByStatus(ProjectStatus status) {
    return _projects.where((project) => project.status == status).toList();
  }

  Future<void> loadUserBookmarks(String userId) async {
    try {
      final bookmarks = await FirestoreService.getUserBookmarks(userId);
      _bookmarkedProjectIds.clear();
      _bookmarkedProjectIds.addAll(bookmarks);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading bookmarks: $e');
    }
  }

  // Feedback methods
  Future<bool> addFeedback(ProjectFeedback feedback) async {
    _setLoading(true);
    
    try {
      await FirestoreService.saveFeedback(feedback);
      
      // Update project with new feedback
      final projectIndex = _projects.indexWhere((p) => p.id == feedback.projectId);
      if (projectIndex != -1) {
        final project = _projects[projectIndex];
        final updatedFeedback = List<ProjectFeedback>.from(project.feedback)..add(feedback);
        _projects[projectIndex] = project.copyWith(feedback: updatedFeedback);
        
        // Update in Firestore
        await FirestoreService.saveProject(_projects[projectIndex]);
      }
      
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error adding feedback: $e');
      _setLoading(false);
      return false;
    }
  }

  Future<bool> markFeedbackResolved(String feedbackId, String projectId) async {
    _setLoading(true);
    
    try {
      final projectIndex = _projects.indexWhere((p) => p.id == projectId);
      if (projectIndex != -1) {
        final project = _projects[projectIndex];
        final updatedFeedback = project.feedback.map((f) => 
          f.id == feedbackId ? f.copyWith(isResolved: true) : f
        ).toList();
        
        _projects[projectIndex] = project.copyWith(feedback: updatedFeedback);
        await FirestoreService.saveProject(_projects[projectIndex]);
      }
      
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error marking feedback as resolved: $e');
      _setLoading(false);
      return false;
    }
  }

  // Version control methods
  Future<bool> createProjectRevision(Project originalProject, Project revisedProject) async {
    _setLoading(true);
    
    try {
      // Create version record of original project
      final version = ProjectVersion(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        projectId: originalProject.id,
        versionNumber: originalProject.version,
        title: originalProject.title,
        abstract: originalProject.abstract,
        imageUrls: originalProject.imageUrls,
        pdfUrl: originalProject.pdfUrl,
        githubUrl: originalProject.githubUrl,
        createdAt: originalProject.updatedAt,
        changeDescription: 'Original version',
      );

      // Update original project with new version
      final updatedVersions = List<ProjectVersion>.from(originalProject.versions)..add(version);
      final updatedOriginal = originalProject.copyWith(
        versions: updatedVersions,
        status: ProjectStatus.needsRevision,
      );

      // Create revised project
      final revisedProjectWithVersion = revisedProject.copyWith(
        id: originalProject.id, // Keep same ID
        version: originalProject.version + 1,
        parentProjectId: originalProject.parentProjectId ?? originalProject.id,
        status: ProjectStatus.resubmitted,
        createdAt: originalProject.createdAt, // Keep original creation date
        updatedAt: DateTime.now(),
      );

      // Save both projects
      await FirestoreService.saveProject(updatedOriginal);
      await FirestoreService.saveProject(revisedProjectWithVersion);

      // Update local list
      final projectIndex = _projects.indexWhere((p) => p.id == originalProject.id);
      if (projectIndex != -1) {
        _projects[projectIndex] = revisedProjectWithVersion;
      } else {
        _projects.add(revisedProjectWithVersion);
      }

      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error creating project revision: $e');
      _setLoading(false);
      return false;
    }
  }

  // Advanced Search and Filtering
  List<Project> searchProjects(String query) {
    if (query.isEmpty) return _projects;
    
    final lowerQuery = query.toLowerCase();
    return _projects.where((project) =>
      project.title.toLowerCase().contains(lowerQuery) ||
      project.abstract.toLowerCase().contains(lowerQuery) ||
      project.authorName.toLowerCase().contains(lowerQuery) ||
      project.tags.any((tag) => tag.toLowerCase().contains(lowerQuery))
    ).toList();
  }

  List<Project> filterProjects({
    ProjectCategory? category,
    ProjectStatus? status,
    int? minYear,
    int? maxYear,
    double? minRating,
    String? authorId,
    bool? isFeatured,
  }) {
    return _projects.where((project) {
      if (category != null && project.category != category) return false;
      if (status != null && project.status != status) return false;
      if (minYear != null && project.year < minYear) return false;
      if (maxYear != null && project.year > maxYear) return false;
      if (minRating != null && project.rating < minRating) return false;
      if (authorId != null && project.authorId != authorId) return false;
      if (isFeatured != null && project.isFeatured != isFeatured) return false;
      return true;
    }).toList();
  }

  List<Project> getProjectsByAuthor(String authorId) {
    return _projects.where((p) => p.authorId == authorId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<Project> getRecentProjects({int limit = 10}) {
    return _projects
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt))
      ..take(limit);
  }

  List<Project> getTopRatedProjects({int limit = 10}) {
    return _projects.where((p) => p.rating > 0)
      ..sort((a, b) => b.rating.compareTo(a.rating))
      ..take(limit);
  }

  List<Project> filterProjectsByStatus(ProjectStatus status) {
    return _projects.where((p) => p.status == status).toList();
  }

  List<Project> getProjectVersions(String projectId) {
    final project = _projects.firstWhere((p) => p.id == projectId);
    return _projects.where((p) => 
      p.id == projectId || p.parentProjectId == projectId
    ).toList()..sort((a, b) => a.version.compareTo(b.version));
  }

  List<ProjectFeedback> getProjectFeedback(String projectId) {
    final project = _projects.firstWhere((p) => p.id == projectId);
    return project.feedback..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  // Feedback system
  Future<bool> addFeedback(ProjectFeedback feedback) async {
    _setLoading(true);
    
    try {
      await FirestoreService.saveFeedback(feedback);
      
      // Update project with feedback
      final project = _projects.firstWhere((p) => p.id == feedback.projectId);
      final updatedProject = project.copyWith(
        feedback: [...project.feedback, feedback],
      );
      
      await updateProject(updatedProject);
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error adding feedback: $e');
      _setLoading(false);
      return false;
    }
  }

  Future<bool> updateFeedback(ProjectFeedback feedback) async {
    _setLoading(true);
    
    try {
      await FirestoreService.saveFeedback(feedback);
      
      // Update project with feedback
      final project = _projects.firstWhere((p) => p.id == feedback.projectId);
      final updatedFeedback = project.feedback.map((f) => 
        f.id == feedback.id ? feedback : f
      ).toList();
      
      final updatedProject = project.copyWith(feedback: updatedFeedback);
      await updateProject(updatedProject);
      
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error updating feedback: $e');
      _setLoading(false);
      return false;
    }
  }

  Future<bool> deleteFeedback(String feedbackId, String projectId) async {
    _setLoading(true);
    
    try {
      await FirestoreService.deleteFeedback(feedbackId);
      
      // Update project by removing feedback
      final project = _projects.firstWhere((p) => p.id == projectId);
      final updatedFeedback = project.feedback.where((f) => f.id != feedbackId).toList();
      
      final updatedProject = project.copyWith(feedback: updatedFeedback);
      await updateProject(updatedProject);
      
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error deleting feedback: $e');
      _setLoading(false);
      return false;
    }
  }

  // Bookmark system
  bool isBookmarked(String projectId) {
    return _bookmarkedProjectIds.contains(projectId);
  }

  Future<void> loadUserBookmarks(String userId) async {
    try {
      final bookmarks = await FirestoreService.getUserBookmarks(userId);
      _bookmarkedProjectIds.clear();
      _bookmarkedProjectIds.addAll(bookmarks);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading bookmarks: $e');
    }
  }

  String? _currentUserId;

  void setCurrentUserId(String userId) {
    _currentUserId = userId;
    loadUserBookmarks(userId);
  }

  String _getCurrentUserId() {
    return _currentUserId ?? 'anonymous';
  }

  // Helper method to upload files to Firebase Storage
  Future<String?> _uploadFile(String filePath, String folder, String extension) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('ProjectService: File does not exist: $filePath');
        return null;
      }

      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$extension';
      final storageRef = FirebaseStorage.instance
          .ref()
          .child(folder)
          .child(fileName);

      debugPrint('ProjectService: Uploading file to Firebase Storage: $fileName');
      final uploadTask = storageRef.putFile(file);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      debugPrint('ProjectService: File uploaded successfully: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      debugPrint('ProjectService: Error uploading file: $e');
      return null;
    }
  }

  // Method to delete files from Firebase Storage
  Future<void> deleteProjectFiles(Project project) async {
    try {
      // Delete PDF if exists
      if (project.pdfUrl != null && project.pdfUrl!.isNotEmpty) {
        final pdfRef = FirebaseStorage.instance.refFromURL(project.pdfUrl!);
        await pdfRef.delete();
      }

      // Delete images if exist
      for (final imageUrl in project.imageUrls) {
        if (imageUrl.isNotEmpty) {
          final imageRef = FirebaseStorage.instance.refFromURL(imageUrl);
          await imageRef.delete();
        }
      }
    } catch (e) {
      debugPrint('ProjectService: Error deleting files: $e');
    }
  }
}
