import 'package:flutter/foundation.dart';
import '../models/project.dart';
import 'firestore_service.dart';

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
      // For now, skip file uploads to avoid Firebase Storage issues
      // Just save the project with local file paths for testing
      debugPrint('ProjectService: Skipping file uploads for now, saving project directly');
      
      // Create project without uploading files to Firebase Storage
      final projectWithUrls = project.copyWith(
        imageUrls: project.imageUrls, // Keep local paths for now
        pdfUrl: project.pdfUrl, // Keep local path for now
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
      await FirestoreService.saveProject(project);
      
      final index = _projects.indexWhere((p) => p.id == project.id);
      if (index != -1) {
        _projects[index] = project;
      } else {
        _projects.add(project);
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

  Future<bool> deleteProject(String projectId) async {
    _setLoading(true);
    
    try {
      await FirestoreService.deleteProject(projectId);
      _projects.removeWhere((p) => p.id == projectId);
      _bookmarkedProjectIds.remove(projectId);
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error deleting project: $e');
      _setLoading(false);
      return false;
    }
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

  String? _currentUserId;

  void setCurrentUserId(String userId) {
    _currentUserId = userId;
    loadUserBookmarks(userId);
  }

  String _getCurrentUserId() {
    return _currentUserId ?? 'anonymous';
  }
}
