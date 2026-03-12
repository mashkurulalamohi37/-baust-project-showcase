import 'package:flutter/foundation.dart';
import '../models/project.dart';
import '../models/review.dart';
import '../models/user.dart';
import '../models/feedback.dart' as feedback_models;
import 'firestore_service.dart';
import 'notification_service.dart';
import 'auth_service.dart';
import '../../services/email_service.dart';
import '../../services/imagekit_service.dart';

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
  String? get lastUploadError => _lastUploadError;

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

  Future<void> _loadProjects({bool force = false, bool showLoading = true}) async {
    if (_isLoading) return;
    if (_initialized && !force) return;
    
    if (showLoading) _setLoading(true);
    debugPrint('ProjectService: ${showLoading ? "Loading" : "Refresing"} projects from Firestore');
    
    try {
      // Load projects from Firestore
      final projects = await FirestoreService.getProjects();
      debugPrint('ProjectService: Loaded ${projects.length} projects from Firestore');
      
      _projects.clear();
      _projects.addAll(projects);
      
      _initialized = true;
      if (showLoading) _setLoading(false);
      notifyListeners();
      debugPrint('ProjectService: Projects ${showLoading ? "loaded" : "refreshed"} successfully');
    } catch (e) {
      debugPrint('ProjectService: Error loading projects from Firestore: $e');
      
      // Fallback to empty state if Firestore fails
      _projects.clear();
      _reviews.clear();
      
      _initialized = true;
      if (showLoading) _setLoading(false);
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

  Future<bool> createProject(
    Project project, {
    Uint8List? pdfBytes,
    List<Uint8List>? imageBytes,
    Uint8List? videoBytes,
    String? pdfPath,
    List<String>? imagePaths,
    String? videoPath,
    Function(double)? onProgress,
    Function(String type, String url)? onFileUploaded,
  }) async {
    debugPrint('ProjectService: Starting project creation for ${project.title}');
    
    try {
      // Check for duplicate projects
      final duplicateProject = _projects.where((p) => 
        p.title.toLowerCase() == project.title.toLowerCase() && 
        p.authorId == project.authorId &&
        (p.status == ProjectStatus.pending || p.status == ProjectStatus.draft)
      ).firstOrNull;
      
      if (duplicateProject != null) {
        _lastUploadError = 'A project with the title "${project.title}" is already pending.';
        return false;
      }
      
      // Calculate total bytes for progress weighting
      double totalBytes = 0;
      if (pdfBytes != null) totalBytes += pdfBytes.length;
      if (imageBytes != null) for (var b in imageBytes) totalBytes += b.length;
      if (videoBytes != null) totalBytes += videoBytes.length;
      
      double bytesUploaded = 0;
      void updateProgress(double fileProgress, double fileWeight) {
        if (onProgress != null && totalBytes > 0) {
          onProgress((bytesUploaded + (fileProgress * fileWeight)) / totalBytes);
        }
      }

      List<String> imageUrls = [];
      String? pdfUrl;
      String? videoUrl;
      
      // 1. Upload PDF
      bool hasExistingPdf = project.pdfUrl != null && project.pdfUrl!.startsWith('http');
      if ((pdfBytes != null || pdfPath != null) && !hasExistingPdf) {
        pdfUrl = await FirestoreService.uploadFile(
          pdfPath ?? '', 
          'projects/${project.id}/project_${DateTime.now().millisecondsSinceEpoch}.pdf',
          data: pdfBytes,
          onProgress: (p) => updateProgress(p, pdfBytes?.length.toDouble() ?? 0),
        );
        if (pdfUrl != null) {
          bytesUploaded += pdfBytes?.length ?? 0;
          if (onFileUploaded != null) onFileUploaded('pdf', pdfUrl);
        }
      } else if (hasExistingPdf) {
        pdfUrl = project.pdfUrl;
        bytesUploaded += pdfBytes?.length ?? 0;
        debugPrint('ProjectService: Skipping PDF upload, using: $pdfUrl');
      }

      // 2. Upload Images
      bool hasExistingImages = project.imageUrls.isNotEmpty && project.imageUrls.every((url) => url.startsWith('http'));
      if (((imageBytes != null && imageBytes.isNotEmpty) || (imagePaths != null && imagePaths.isNotEmpty)) && !hasExistingImages) {
        final uploadedUrls = await FirestoreService.uploadMultipleFiles(
          imagePaths ?? [],
          'projects/${project.id}',
          dataList: imageBytes,
          onProgress: (p) {
            double totalImageBytes = imageBytes?.fold(0.0, (sum, b) => sum! + b.length) ?? 0;
            updateProgress(p, totalImageBytes);
          },
        );
        imageUrls.addAll(uploadedUrls);
        bytesUploaded += imageBytes?.fold(0, (sum, b) => sum! + b.length) ?? 0;
        if (onFileUploaded != null) {
          for (var url in uploadedUrls) onFileUploaded('image', url);
        }
      } else if (hasExistingImages) {
        imageUrls = project.imageUrls;
        bytesUploaded += imageBytes?.fold(0, (sum, b) => sum! + b.length) ?? 0;
        debugPrint('ProjectService: Skipping Image uploads, using existing URLs');
      }

      // 3. Upload Video
      bool hasExistingVideo = project.videoUrl != null && project.videoUrl!.startsWith('http');
      if ((videoBytes != null || videoPath != null) && !hasExistingVideo) {
        videoUrl = await ImageKitService.uploadVideo(
          (videoPath != null && videoPath.isNotEmpty) ? videoPath : 'video.mp4',
          data: videoBytes,
          folder: 'projects/${project.id}/videos',
          onProgress: (p) => updateProgress(p, videoBytes?.length.toDouble() ?? 0),
        );
        if (videoUrl != null) {
          bytesUploaded += videoBytes?.length ?? 0;
          if (onFileUploaded != null) onFileUploaded('video', videoUrl);
        }
      } else if (hasExistingVideo) {
        videoUrl = project.videoUrl;
        bytesUploaded += videoBytes?.length ?? 0;
        debugPrint('ProjectService: Skipping Video upload, using: $videoUrl');
      }
      
      // Create project with uploaded file URLs
      final projectWithUrls = project.copyWith(
        imageUrls: imageUrls,
        pdfUrl: pdfUrl,
        videoUrl: videoUrl,
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
        
        // Log activity in background
        FirestoreService.logProjectUploaded(projectWithUrls).catchError((e) => debugPrint('ProjectService: Failed to log upload: $e'));
        
        // Notify teachers of new project pending approval
        if (projectWithUrls.status == ProjectStatus.pending) {
          // Don't await notifications to prevent hanging the UI if email service is slow
          final notificationService = NotificationService();
          notificationService.notifyTeachersNewProjectPending(projectWithUrls).then((_) {
            debugPrint('ProjectService: Notified teachers of new pending project');
          }).catchError((e) {
            debugPrint('ProjectService: Failed to notify teachers: $e');
          });
        }
        
        notifyListeners();
        debugPrint('ProjectService: Project created successfully and listeners notified');

        // Silent background refresh
        _loadProjects(force: true, showLoading: false);
        
        return true;
      } catch (e) {
        debugPrint('ProjectService: Failed to save project to Firestore: $e');
        debugPrint('ProjectService: Please check Firebase connection and configuration');
        return false;
      }
    } catch (e) {
      debugPrint('ProjectService: Error creating project: $e');
      debugPrint('ProjectService: Stack trace: ${StackTrace.current}');
      _lastUploadError = _lastUploadError ?? e.toString().replaceAll('Exception: ', '').replaceAll('Error: ', '');
      if (_lastUploadError!.isEmpty) _lastUploadError = 'Failed to create project. Please try again.';
      return false;
    }
  }

  Future<bool> updateProjectWithFiles(
    Project project, {
    Uint8List? pdfBytes,
    List<Uint8List>? imageBytes,
    Uint8List? videoBytes,
    String? pdfPath,
    List<String>? imagePaths,
    String? videoPath,
    Function(double)? onProgress,
    Function(String type, String url)? onFileUploaded,
  }) async {
    debugPrint('ProjectService: Updating project ${project.id}');
    
    try {
      // Calculate total bytes for progress weighting
      double totalBytes = 0;
      if (pdfBytes != null) totalBytes += pdfBytes.length;
      if (imageBytes != null) for (var b in imageBytes) totalBytes += b.length;
      if (videoBytes != null) totalBytes += videoBytes.length;
      
      double bytesUploaded = 0;
      void updateProgress(double fileProgress, double fileWeight) {
        if (onProgress != null && totalBytes > 0) {
          onProgress((bytesUploaded + (fileProgress * fileWeight)) / totalBytes);
        }
      }

      List<String> imageUrls = List.from(project.imageUrls);
      String? pdfUrl = project.pdfUrl;
      String? videoUrl = project.videoUrl;
      
      // 1. Handle PDF Upload (Skip if network URL already present)
      bool hasExistingPdf = pdfUrl != null && pdfUrl.startsWith('http');
      if ((pdfBytes != null || pdfPath != null) && !hasExistingPdf) {
        pdfUrl = await FirestoreService.uploadFile(
          pdfPath ?? '',
          'projects/${project.id}/project_${DateTime.now().millisecondsSinceEpoch}.pdf',
          data: pdfBytes,
          onProgress: (p) => updateProgress(p, pdfBytes?.length.toDouble() ?? 0),
        );
        if (pdfUrl != null) {
          bytesUploaded += pdfBytes?.length ?? 0;
          if (onFileUploaded != null) onFileUploaded('pdf', pdfUrl);
        }
      } else if (hasExistingPdf && (pdfBytes != null || pdfPath != null)) {
        bytesUploaded += pdfBytes?.length ?? 0;
      }
      
      // 2. Handle Image Uploads (Skip if network URLs already present)
      bool hasExistingImages = imageUrls.isNotEmpty && imageUrls.every((url) => url.startsWith('http'));
      if (((imageBytes != null && imageBytes.isNotEmpty) || (imagePaths != null && imagePaths.isNotEmpty)) && !hasExistingImages) {
        final uploadedUrls = await FirestoreService.uploadMultipleFiles(
          imagePaths ?? [],
          'projects/${project.id}',
          dataList: imageBytes,
          onProgress: (p) {
            double totalImageBytes = imageBytes?.fold(0.0, (sum, b) => sum! + b.length) ?? 0;
            updateProgress(p, totalImageBytes);
          },
        );
        imageUrls = uploadedUrls;
        bytesUploaded += imageBytes?.fold(0, (sum, b) => sum! + b.length) ?? 0;
        if (onFileUploaded != null) {
          for (var url in uploadedUrls) onFileUploaded('image', url);
        }
      } else if (hasExistingImages && imageBytes != null) {
        bytesUploaded += imageBytes.fold(0, (sum, b) => sum! + b.length) ?? 0;
      }

      // 3. Handle Video Upload (Skip if network URL already present)
      bool hasExistingVideo = videoUrl != null && videoUrl.startsWith('http');
      if ((videoBytes != null || videoPath != null) && !hasExistingVideo) {
        final newVideoUrl = await ImageKitService.uploadVideo(
          (videoPath != null && videoPath.isNotEmpty) ? videoPath : 'video.mp4',
          data: videoBytes,
          folder: 'projects/${project.id}/videos',
          onProgress: (p) => updateProgress(p, videoBytes?.length.toDouble() ?? 0),
        );
        if (newVideoUrl != null) {
          videoUrl = newVideoUrl;
          bytesUploaded += videoBytes?.length ?? 0;
          if (onFileUploaded != null) onFileUploaded('video', videoUrl);
        }
      } else if (hasExistingVideo && videoBytes != null) {
        bytesUploaded += videoBytes.length;
      }
      
      final updatedProject = project.copyWith(
        pdfUrl: pdfUrl,
        imageUrls: imageUrls,
        videoUrl: videoUrl,
        updatedAt: DateTime.now(),
      );
      
      await FirestoreService.updateProject(updatedProject);
      
      final index = _projects.indexWhere((p) => p.id == updatedProject.id);
      if (index != -1) {
        _projects[index] = updatedProject;
      }
      
      notifyListeners();
      
      // Background refresh
      _loadProjects(force: true, showLoading: false);
      
      return true;
    } catch (e) {
      debugPrint('ProjectService: Error updating project with files: $e');
      _lastUploadError = e.toString().replaceAll('Exception: ', '').replaceAll('Error: ', '');
      if (_lastUploadError!.isEmpty) _lastUploadError = 'Failed to update project. Please try again.';
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

      // Send email to teacher when assigned
      if (approverId != null && approverId != originalProject.facultyId) {
        try {
          final teacher = await FirestoreService.getUser(approverId);
          if (teacher != null) {
            // CRITICAL: Verify this is actually a teacher before sending email
            if (teacher.role == UserRole.teacher || teacher.role == UserRole.admin) {
              await EmailService.sendTeacherAssignmentEmail(
                teacherEmail: teacher.email,
                teacherName: teacher.name,
                projectTitle: updatedProject.title,
                studentName: updatedProject.authorName,
                submissionType: updatedProject.submissionType.displayName,
              );
              debugPrint('ProjectService: Teacher assignment email sent to ${teacher.email}');
            } else {
              debugPrint('ProjectService: Skipping email - User ${teacher.name} is not a teacher (role: ${teacher.role})');
            }
          }
        } catch (e) {
          debugPrint('Error sending teacher assignment email: $e');
        }
      }

      // Send notifications for status changes
      if (statusChanged) {
        // Wrap in try-catch so notification/log failures don't crash the approval
        try {
          await _sendStatusChangeNotifications(originalProject, updatedProject);
        } catch (e) {
          debugPrint('ProjectService: Non-fatal - notification error: $e');
        }
        try {
          await FirestoreService.logProjectStatusChange(
            updatedProject,
            oldStatus,
            updatedProject.status,
            approverId,
            approverName,
          );
        } catch (e) {
          debugPrint('ProjectService: Non-fatal - activity log error: $e');
        }
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

  Future<bool> updateShowcaseEvaluation(String projectId, Map<String, double> criteria, String feedback) async {
    _setLoading(true);
    try {
      final authService = AuthService();
      final currentUser = authService.currentUser;
      
      if (currentUser == null) {
        throw Exception('User not logged in');
      }

      // Fetch fresh project from Firestore to avoid overwriting other teachers' evaluations
      // due to stale local state
      final freshProject = await FirestoreService.getProjectById(projectId);
      if (freshProject == null) {
         throw Exception('Project not found');
      }

      // Calculate total mark from criteria
      double totalCriteria = 0;
      if (criteria.isNotEmpty) {
        criteria.forEach((_, value) => totalCriteria += value);
      }
      // Calculate average (assuming all criteria are out of 10, and we want a final mark out of 10)
      // If criteria is empty, mark is 0.
      double mark = criteria.isEmpty ? 0 : totalCriteria / criteria.length;

      // Create new evaluation
      final evaluation = ShowcaseEvaluation(
        teacherId: currentUser.id,
        teacherName: currentUser.name,
        mark: mark,
        criteria: criteria,
        feedback: feedback,
        updatedAt: DateTime.now(),
      );

      // Update evaluations list from the FRESH project
      List<ShowcaseEvaluation> updatedEvaluations = List.from(freshProject.evaluations);
      
      // Remove existing evaluation by this teacher if exists
      updatedEvaluations.removeWhere((e) => e.teacherId == currentUser.id);
      
      // Add new evaluation
      updatedEvaluations.add(evaluation);

      // Calculate average mark for the project
      double totalMark = 0;
      for (var e in updatedEvaluations) {
        totalMark += e.mark;
      }
      double averageMark = updatedEvaluations.isEmpty ? 0 : totalMark / updatedEvaluations.length;

      final updatedProject = freshProject.copyWith(
        evaluations: updatedEvaluations,
        showcaseMark: averageMark, // Keep showcaseMark as average for sorting/display
      );
      
      await FirestoreService.updateProject(updatedProject);
      
      final index = _projects.indexWhere((p) => p.id == projectId);
      if (index != -1) {
        _projects[index] = updatedProject;
        notifyListeners();
      }
      _setLoading(false);
      return true;
    } catch (e) {
      debugPrint('Error updating showcase evaluation: $e');
      _setLoading(false);
      return false;
    }
  }

  Future<void> _sendStatusChangeNotifications(Project originalProject, Project updatedProject) async {
    final notificationService = NotificationService();
    
    // Get teacher name from the updated project or use a default
    final teacherName = updatedProject.facultyName ?? 'Teacher';
    
    // Use the new unified notification method for all status changes
    if (originalProject.status != updatedProject.status) {
      await notificationService.notifyStudentProjectReviewed(
        updatedProject.authorId,
        updatedProject,
        teacherName,
        updatedProject.status,
      );
      
      // Send email when project is approved
      if (updatedProject.status == ProjectStatus.approved) {
        try {
          final student = await FirestoreService.getUser(updatedProject.authorId);
          if (student != null) {
            await EmailService.sendProjectApprovalEmail(
              studentEmail: student.email,
              studentName: student.name,
              projectTitle: updatedProject.title,
              teacherName: teacherName,
            );
          }
        } catch (e) {
          debugPrint('Error sending project approval email: $e');
        }
      }
    }
  }

  Future<bool> deleteProject(String projectId) async {
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
      
      // Silent background refresh
      _loadProjects(force: true, showLoading: false);

      return true;
    } catch (e) {
      debugPrint('Error deleting project: $e');
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
        reviewerProfileImageUrl: currentUser?.profileImageUrl, // Include profile picture
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
      debugPrint('ProjectService: Preparing to send review notification to student');
      debugPrint('ProjectService: Student (author) ID: ${project.authorId}');
      debugPrint('ProjectService: Reviewer name: ${review.reviewerName}');
      final notificationService = NotificationService();
      await notificationService.notifyNewReview(project.authorId, project, review.reviewerName);
      debugPrint('ProjectService: Review notification call completed');
      
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

      debugPrint('ProjectService: Creating revision for project $projectId');
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