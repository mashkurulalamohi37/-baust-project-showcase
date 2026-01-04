import 'package:flutter/foundation.dart';
import 'dart:io';
import '../models/project.dart';
import '../models/review.dart';
import '../models/user.dart';
import '../models/feedback.dart' as feedback_models;
import 'firestore_service.dart';
import 'notification_service.dart';
import 'auth_service.dart';

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
  String? _lastUploadError;

  List<Project> get projects => List.unmodifiable(_projects);
  List<Review> get reviews => List.unmodifiable(_reviews);
  List<String> get bookmarkedProjectIds => List.unmodifiable(_bookmarkedProjectIds);
  bool get isLoading => _isLoading;

  List<Project> get featuredProjects => 
      _projects.where((p) => p.isFeatured && p.status != ProjectStatus.hidden && p.status != ProjectStatus.draft && p.status != ProjectStatus.rejected && p.status != ProjectStatus.pending && p.status != ProjectStatus.needsRevision).toList();

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

  Future<void> _loadProjects({bool force = false}) async {
    if (_isLoading) return;
    if (_initialized && !force) return;
    _setLoading(true);
    debugPrint('ProjectService: Loading projects from Firestore');
    
    try {
      // Load projects from Firestore
      final projects = await FirestoreService.getProjects();
      debugPrint('ProjectService: Loaded ${projects.length} projects from Firestore');
      
      _projects.clear();
      _projects.addAll(projects);
      
      // Load reviews will be done per project when needed
      // For now, we'll load reviews separately
      
      _initialized = true;
      _setLoading(false);
      notifyListeners();
      debugPrint('ProjectService: Projects loaded successfully');
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

  Future<void> reloadProjects() async {
    await _loadProjects(force: true);
  }

  Future<bool> createProject(Project project) async {
    _setLoading(true);
    debugPrint('ProjectService: Starting project creation for ${project.title}');
    
    try {
      // Check for duplicate projects (same title by same author with pending/draft status)
      // Allow duplicates if the existing project is approved/rejected (user can resubmit)
      final duplicateProject = _projects.where((p) => 
        p.title.toLowerCase() == project.title.toLowerCase() && 
        p.authorId == project.authorId &&
        (p.status == ProjectStatus.pending || p.status == ProjectStatus.draft)
      ).firstOrNull;
      
      if (duplicateProject != null) {
        debugPrint('ProjectService: Duplicate project found with title: ${project.title} (status: ${duplicateProject.status})');
        _setLoading(false);
        _lastUploadError = 'A project with the title "${project.title}" is already pending. Please use a different title or wait for the existing project to be reviewed.';
        return false;
      }
      
      // Upload files to Firebase Storage
      List<String> imageUrls = [];
      String? pdfUrl;
      
      // Upload PDF if provided
      bool pdfUploadRequired = project.pdfUrl != null && project.pdfUrl!.isNotEmpty;
      bool pdfUploadFailed = false;
      
      if (pdfUploadRequired) {
        debugPrint('ProjectService: Uploading PDF file: ${project.pdfUrl}');
        try {
          debugPrint('ProjectService: Using Firebase Storage for PDF upload');
          pdfUrl = await FirestoreService.uploadFile(
            project.pdfUrl!,
            'projects/${project.id}/project_${DateTime.now().millisecondsSinceEpoch}.pdf',
          );
          if (pdfUrl != null) {
            debugPrint('ProjectService: PDF uploaded to Firebase: $pdfUrl');
          } else {
            final errorMsg = 'PDF upload failed';
            debugPrint('ProjectService: PDF upload returned null');
            debugPrint('ProjectService: Error message: $errorMsg');
            pdfUploadFailed = true;
            // Store error for display
            _lastUploadError = errorMsg ?? 'PDF upload failed. Check Firebase configuration.';
          }
          
          if (pdfUrl == null) {
            pdfUploadFailed = true;
            debugPrint('ProjectService: ERROR - Failed to upload PDF!');
            debugPrint('ProjectService: PDF file path was: ${project.pdfUrl}');
            debugPrint('ProjectService: This means the PDF will not be accessible. Please check:');
            debugPrint('  1. Firebase Storage bucket exists and is configured');
            debugPrint('  2. Storage rules allow upload operations');
            debugPrint('  3. Firebase is properly initialized');
            debugPrint('  4. Check console logs above for specific error messages');
          } else {
            debugPrint('ProjectService: PDF uploaded successfully: $pdfUrl');
          }
        } catch (e, stackTrace) {
          pdfUploadFailed = true;
          final errorString = e.toString();
          debugPrint('ProjectService: ERROR uploading PDF: $e');
          debugPrint('ProjectService: Stack trace: $stackTrace');
          debugPrint('ProjectService: Exception details: $errorString');
          // Store the actual error message
          _lastUploadError = errorString.replaceAll('Exception: ', '').replaceAll('Error: ', '');
          if (_lastUploadError?.isEmpty ?? true) {
            _lastUploadError = 'PDF upload failed. Please check Firebase Storage configuration.';
          }
        }
      } else {
        debugPrint('ProjectService: No PDF to upload (pdfUrl is null or empty)');
      }
      
      // If PDF upload failed, throw an error to prevent saving project
      if (pdfUploadFailed) {
        _setLoading(false);
        final errorMsg = _lastUploadError ?? 'PDF upload failed. Please check Firebase configuration and try again.';
        throw Exception(errorMsg);
      }
      
      // Upload images if provided
      if (project.imageUrls.isNotEmpty) {
        debugPrint('ProjectService: Uploading ${project.imageUrls.length} image(s)');
        
        // Use Firebase Storage batch upload
        final uploadedUrls = await FirestoreService.uploadMultipleFiles(
          project.imageUrls,
          'projects/${project.id}',
        );
        imageUrls.addAll(uploadedUrls);
        debugPrint('ProjectService: Uploaded ${uploadedUrls.length} images to Firebase');
      }
      
      // Create project with uploaded file URLs
      final projectWithUrls = project.copyWith(
        imageUrls: imageUrls,
        pdfUrl: pdfUrl,
      );
      
      debugPrint('ProjectService: Saving project to Firestore');
      debugPrint('ProjectService: Project has ${imageUrls.length} images and PDF: ${pdfUrl != null}');
      if (pdfUrl != null) {
        debugPrint('ProjectService: PDF URL to be saved: $pdfUrl');
      } else {
        debugPrint('ProjectService: WARNING - PDF URL is null, original file path was: ${project.pdfUrl}');
      }
      if (imageUrls.isNotEmpty) {
        debugPrint('ProjectService: Image URLs to be saved: ${imageUrls.join(", ")}');
      }
      try {
        await FirestoreService.saveProject(projectWithUrls);
        debugPrint('ProjectService: Project saved to Firestore successfully');
        
        _projects.add(projectWithUrls);
        debugPrint('ProjectService: Project added to local list. Total projects: ${_projects.length}');
        
        // Log activity
        await FirestoreService.logProjectUploaded(projectWithUrls);
        _setLoading(false);
        notifyListeners();
        debugPrint('ProjectService: Project created successfully and listeners notified');
        // Force reload all projects so other dashboards see the latest list immediately
        await _loadProjects(force: true);
        return true;
      } catch (e) {
        debugPrint('ProjectService: Failed to save project to Firestore: $e');
        debugPrint('ProjectService: Please check Firebase connection and configuration');
        _setLoading(false);
        return false;
      }
    } catch (e) {
      debugPrint('ProjectService: Error creating project: $e');
      debugPrint('ProjectService: Stack trace: ${StackTrace.current}');
      _setLoading(false);
      return false;
    }
  }

  Future<bool> updateProject(
    Project project, {
    String? approverId,
    String? approverName,
  }) async {
    _setLoading(true);
    try {
      // Get the original project to check for status changes
      final originalProject = _projects.firstWhere(
        (p) => p.id == project.id,
        orElse: () => project,
      );
      final statusChanged = originalProject.status != project.status;
      final oldStatus = originalProject.status;

      // If project was in needsRevision status and is being updated by student (not teacher),
      // automatically change status to pending for re-approval
      ProjectStatus newStatus = project.status;
      if (originalProject.status == ProjectStatus.needsRevision && 
          project.status == ProjectStatus.needsRevision &&
          approverId == null) {
        // Student is updating their project - change to pending
        newStatus = ProjectStatus.pending;
        debugPrint('ProjectService: Project ${project.id} updated from needsRevision to pending for re-approval');
      }

      // Update project in Firestore
      final updatedProject = project.copyWith(
        status: newStatus,
        facultyId: approverId ?? project.facultyId,
        facultyName: approverName ?? project.facultyName,
      );
      await FirestoreService.updateProject(updatedProject);

      final index = _projects.indexWhere((p) => p.id == project.id);
      if (index != -1) {
        _projects[index] = updatedProject;
      } else {
        _projects.add(updatedProject);
      }

      // Send notifications for status changes
      if (statusChanged) {
        await _sendStatusChangeNotifications(originalProject, updatedProject);
        // Log activity for status change
        await FirestoreService.logProjectStatusChange(
          updatedProject,
          oldStatus,
          updatedProject.status,
          approverId,
          approverName,
        );
      }
      
      // Always reload projects after update to ensure UI reflects changes (especially for featured status)
      await _loadProjects(force: true);

      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error updating project: $e');
      _setLoading(false);
      return false;
    }
  }

  Future<bool> updateProjectAward(String projectId, ProjectAward award) async {
    _setLoading(true);
    try {
      final project = _projects.firstWhere((p) => p.id == projectId);
      final updatedProject = project.copyWith(award: award);
      
      await FirestoreService.updateProject(updatedProject);
      
      final index = _projects.indexWhere((p) => p.id == projectId);
      if (index != -1) {
        _projects[index] = updatedProject;
        notifyListeners();
      }
      _setLoading(false);
      return true;
    } catch (e) {
      debugPrint('Error updating project award: $e');
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
      await _loadProjects(force: true);
      return true;
    } catch (e) {
      debugPrint('Error deleting project: $e');
      _setLoading(false);
      return false;
    }
  }

  // Review and Rating System
  Future<void> loadReviewsForProject(String projectId) async {
    try {
      final reviews = await FirestoreService.getReviewsByProjectId(projectId);
      _reviews.removeWhere((r) => r.projectId == projectId);
      _reviews.addAll(reviews);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading reviews for project: $e');
    }
  }

  Future<void> loadReviewsForUser(String userId) async {
    try {
      final reviews = await FirestoreService.getReviewsByReviewerId(userId);
      // Remove existing reviews by this user to avoid duplicates
      _reviews.removeWhere((r) => r.reviewerId == userId);
      _reviews.addAll(reviews);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading reviews for user: $e');
    }
  }

  Future<bool> addReview(String projectId, double rating, String comment) async {
    _setLoading(true);
    
    try {
      // Get current user from AuthService
      final authService = AuthService();
      final currentUser = authService.currentUser;
      debugPrint('ProjectService: Adding review - Current user: ${currentUser?.name} (ID: ${currentUser?.id})');
      
      final reviewerName = currentUser?.name ?? 'Unknown User';
      final reviewerId = currentUser?.id ?? _getCurrentUserId();
      final reviewerDesignation = currentUser?.designation?.displayName;
      
      // Ensure reviewer name is not empty
      final finalReviewerName = reviewerName.trim().isEmpty ? 'Anonymous Reviewer' : reviewerName;
      
      debugPrint('ProjectService: Review details - Reviewer: $finalReviewerName, Designation: $reviewerDesignation, Rating: $rating, Comment length: ${comment.length}');
      
      final review = Review(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        projectId: projectId,
        reviewerId: reviewerId,
        reviewerName: finalReviewerName,
        reviewerDesignation: reviewerDesignation,
        rating: rating,
        comment: comment,
        createdAt: DateTime.now(),
      );

      debugPrint('ProjectService: Saving review to Firestore...');
      await FirestoreService.saveReview(review);
      debugPrint('ProjectService: Review saved successfully');
      
      // Load reviews for the project to update local cache
      await loadReviewsForProject(projectId);
      
      // Ensure the new review is in the list (handle potential Firestore consistency delay)
      if (!_reviews.any((r) => r.id == review.id)) {
        _reviews.add(review);
      }
      
      // Update project rating
      final project = _projects.firstWhere((p) => p.id == projectId);
      final updatedRating = _calculateAverageRating(projectId);
      // Use actual count from loaded reviews
      final currentReviews = _reviews.where((r) => r.projectId == projectId);
      final updatedProject = project.copyWith(
        rating: updatedRating,
        reviewCount: currentReviews.length,
      );
      
      await updateProject(updatedProject);
      
      // Send notification for new review
      final notificationService = NotificationService();
      await notificationService.notifyNewReview(project.authorId, project, review.reviewerName);
      
      // Log activity for review
      await FirestoreService.logProjectReviewed(project, review.reviewerName);
      
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error adding review: $e');
      _setLoading(false);
      return false;
    }
  }

  Future<bool> updateReview(String reviewId, double rating, String comment) async {
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
      
      // Reload reviews for the project
      final projectReviews = await FirestoreService.getReviewsByProjectId(updatedReview.projectId);
      _reviews.removeWhere((r) => r.projectId == updatedReview.projectId);
      _reviews.addAll(projectReviews);
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

  // Filter projects by status
  List<Project> filterProjectsByStatus(ProjectStatus status) {
    return _projects.where((project) => project.status == status).toList();
  }

  Future<bool> deleteReview(String reviewId) async {
    _setLoading(true);
    
    try {
      final review = _reviews.firstWhere((r) => r.id == reviewId);
      final projectId = review.projectId;
      await FirestoreService.deleteReview(reviewId);
      
      // Reload reviews for the project
      final projectReviews = await FirestoreService.getReviewsByProjectId(projectId);
      _reviews.removeWhere((r) => r.projectId == projectId);
      _reviews.addAll(projectReviews);
      _reviews.removeWhere((r) => r.id == reviewId);
      
      // Update project rating
      final project = _projects.firstWhere((p) => p.id == projectId);
      final updatedRating = _calculateAverageRating(projectId);
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
    
    final totalRating = projectReviews.fold<double>(0.0, (sum, review) => sum + review.rating);
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

  // Storage provider: Using Firebase Storage

  // Helper method to upload files to Firebase Storage
  Future<String?> _uploadFile(String filePath, String folder, String extension) async {
    return await _uploadFileToFirebase(filePath, folder, extension);
  }

  // Upload to Firebase Storage
  Future<String?> _uploadFileToFirebase(String filePath, String folder, String extension) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$extension';
      final path = '$folder/$fileName';
      
      debugPrint('ProjectService: Uploading file to Firebase Storage: $path');
      
      final url = await FirestoreService.uploadFile(filePath, path);
      
      if (url != null && url.isNotEmpty) {
        debugPrint('ProjectService: File uploaded successfully to Firebase: $url');
      }
      
      return url;
    } catch (e) {
      debugPrint('ProjectService: Error uploading file to Firebase: $e');
      return null;
    }
  }

  // Create project revision - updates project and sets status back to pending
  Future<bool> createProjectRevision(String projectId, String description, {Project? updatedProjectData}) async {
    _setLoading(true);
    
    try {
      // Find the existing project
      final existingProject = _projects.firstWhere(
        (p) => p.id == projectId,
        orElse: () => throw Exception('Project not found'),
      );

      // If updated project data is provided, use it; otherwise use existing project
      var projectToUpdate = updatedProjectData ?? existingProject;

      // Upload files if they are local file paths (not URLs)
      String? pdfUrl = projectToUpdate.pdfUrl;
      List<String> imageUrls = [];

      // Check if PDF needs to be uploaded (if it's a local file path, not a URL)
      if (projectToUpdate.pdfUrl != null && 
          projectToUpdate.pdfUrl!.isNotEmpty &&
          !projectToUpdate.pdfUrl!.startsWith('http://') &&
          !projectToUpdate.pdfUrl!.startsWith('https://')) {
        debugPrint('ProjectService: Uploading revised PDF file: ${projectToUpdate.pdfUrl}');
        pdfUrl = await _uploadFileToFirebase(
          projectToUpdate.pdfUrl!,
          'projects/$projectId',
          'pdf',
        );
        if (pdfUrl == null) {
          throw Exception('Failed to upload PDF file');
        }
      } else {
        // Keep existing PDF URL if it's already a URL
        pdfUrl = projectToUpdate.pdfUrl;
      }

      // Upload images if they are local file paths
      if (projectToUpdate.imageUrls.isNotEmpty) {
        final List<String> localPaths = [];
        final List<String> existingUrls = [];
        
        for (final path in projectToUpdate.imageUrls) {
          if (path.startsWith('http://') || path.startsWith('https://')) {
            // Already a URL, keep it
            existingUrls.add(path);
          } else {
            // Local file path, needs upload
            localPaths.add(path);
          }
        }
        
        imageUrls.addAll(existingUrls);
        
        if (localPaths.isNotEmpty) {
          debugPrint('ProjectService: Uploading ${localPaths.length} revised image(s)');
          final uploadedUrls = await FirestoreService.uploadMultipleFiles(
            localPaths,
            'projects/$projectId',
          );
          imageUrls.addAll(uploadedUrls);
        }
      }

      // Update project: change status to pending and preserve facultyId
      final revisedProject = projectToUpdate.copyWith(
        status: ProjectStatus.pending, // Change back to pending for re-approval
        updatedAt: DateTime.now(),
        version: existingProject.version + 1, // Increment version
        pdfUrl: pdfUrl,
        imageUrls: imageUrls,
        // Preserve facultyId so it goes back to the same teacher
        facultyId: existingProject.facultyId,
        facultyName: existingProject.facultyName,
      );

      debugPrint('ProjectService: Creating revision for project ${projectId}');
      debugPrint('ProjectService: Status changed from ${existingProject.status} to ${revisedProject.status}');
      debugPrint('ProjectService: Version incremented from ${existingProject.version} to ${revisedProject.version}');
      debugPrint('ProjectService: Preserving facultyId: ${revisedProject.facultyId}');
      debugPrint('ProjectService: Updated title: ${revisedProject.title}');
      debugPrint('ProjectService: Updated abstract: ${revisedProject.abstract}');

      // Update the project in Firestore
      await updateProject(revisedProject);
      
      _setLoading(false);
      return true;
    } catch (e) {
      debugPrint('Error creating project revision: $e');
      _setLoading(false);
      return false;
    }
  }

  // Helper method to delete project files from Firebase Storage
  Future<void> deleteProjectFiles(Project project) async {
    try {
      // Delete PDF if exists
      if (project.pdfUrl != null && project.pdfUrl!.isNotEmpty) {
        await FirestoreService.deleteFile(project.pdfUrl!);
        debugPrint('ProjectService: Deleted PDF file from Firebase');
      }
      
      // Delete images if exist
      for (final imageUrl in project.imageUrls) {
        try {
          await FirestoreService.deleteFile(imageUrl);
          debugPrint('ProjectService: Deleted image file from Firebase');
        } catch (e) {
          debugPrint('ProjectService: Error deleting image: $e');
        }
      }
    } catch (e) {
      debugPrint('ProjectService: Error deleting project files: $e');
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

  // Project feedback operations
  Future<bool> addFeedback(String projectId, String comment, feedback_models.FeedbackType type) async {
    _setLoading(true);
    
    try {
      // Get current user from AuthService
      final authService = AuthService();
      final currentUser = authService.currentUser;
      final reviewerName = currentUser?.name ?? 'Unknown User';
      final reviewerId = currentUser?.id ?? _getCurrentUserId();
      
      final feedback = feedback_models.ProjectFeedback(
        id: 'feedback_${DateTime.now().millisecondsSinceEpoch}',
        projectId: projectId,
        reviewerId: reviewerId,
        reviewerName: reviewerName,
        comment: comment,
        type: type,
        createdAt: DateTime.now(),
      );
      
      await FirestoreService.saveFeedback(feedback);
      _setLoading(false);
      return true;
    } catch (e) {
      debugPrint('Error adding feedback: $e');
      _setLoading(false);
      return false;
    }
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
}