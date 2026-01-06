import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../mvc/models/project.dart';
import '../mvc/models/user.dart';
import '../mvc/controllers/project_service.dart';
import '../mvc/models/team_member.dart';
import '../mvc/controllers/auth_service.dart';
import 'project_detail.dart';
import 'search_filter.dart';
import 'semester_archive_new.dart';
import '../mvc/views/profile_settings_screen.dart';
import '../mvc/controllers/notification_service.dart';
import '../mvc/views/notifications_screen.dart';

import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';

class StudentDashboardScreen extends StatefulWidget {
  const StudentDashboardScreen({super.key});

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  final ProjectService _projectService = ProjectService();
  final AuthService _authService = AuthService();
  final NotificationService _notificationService = NotificationService();
  int _selectedIndex = 0;
  DateTime? _lastPressedAt;

  @override
  void initState() {
    super.initState();
    _projectService.reloadProjects();
    _loadNotifications();
  }

  void _loadNotifications() {
    final user = _authService.currentUser;
    if (user != null) {
      _notificationService.startListening(user.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: true,
      bottom: false,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (bool didPop, Object? result) async {
          if (didPop) return;
          
          final now = DateTime.now();
          if (_lastPressedAt == null || 
              now.difference(_lastPressedAt!) > const Duration(seconds: 2)) {
            _lastPressedAt = now;
            Fluttertoast.showToast(
              msg: "Press back again to exit",
              toastLength: Toast.LENGTH_SHORT,
              gravity: ToastGravity.BOTTOM,
              backgroundColor: Colors.black87,
              textColor: Colors.white,
            );
          } else {
            await SystemNavigator.pop();
          }
        },
        child: Scaffold(
        appBar: AppBar(
          title: const Text('Student Dashboard'),
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
          actions: [
            IconButton(
              onPressed: () => Navigator.pushNamed(context, '/search'),
              icon: const Icon(Icons.search),
              tooltip: 'Search Projects',
            ),
            AnimatedBuilder(
              animation: _notificationService,
              builder: (context, _) {
                return Badge(
                  label: Text('${_notificationService.unreadCount}'),
                  isLabelVisible: _notificationService.unreadCount > 0,
                  child: IconButton(
                    icon: const Icon(Icons.notifications),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const NotificationsScreen()),
                      );
                    },
                  ),
                );
              },
            ),
            PopupMenuButton<String>(
              onSelected: (String value) async {
                if (value == 'profile') {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const ProfileSettingsScreen()),
                  );
                } else if (value == 'logout') {
                  await _authService.logout();
                  if (mounted) {
                    Navigator.of(context).pushNamedAndRemoveUntil('/auth', (route) => false);
                  }
                }
              },
              itemBuilder: (BuildContext context) => [
                PopupMenuItem<String>(
                  value: 'profile',
                  child: Row(
                    children: [
                      const Icon(Icons.person),
                      const SizedBox(width: 8),
                      Text(_authService.currentUser?.name ?? 'Student'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout),
                      SizedBox(width: 8),
                      Text('Logout'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: AnimatedBuilder(
          animation: _projectService,
          builder: (context, child) {
            if (_projectService.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            return IndexedStack(
              index: _selectedIndex,
              children: [
                _ExploreTab(projectService: _projectService, authService: _authService),
                _UploadTab(projectService: _projectService, authService: _authService),
                _MyProjectsTab(projectService: _projectService, authService: _authService),
                _BookmarksTab(projectService: _projectService, authService: _authService),
                const SemesterArchiveScreen(),
              ],
            );
          },
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (int index) => setState(() => _selectedIndex = index),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.explore_outlined),
              selectedIcon: Icon(Icons.explore),
              label: 'Explore',
            ),
            NavigationDestination(
              icon: Icon(Icons.upload_outlined),
              selectedIcon: Icon(Icons.upload),
              label: 'Upload',
            ),
            NavigationDestination(
              icon: Icon(Icons.folder_outlined),
              selectedIcon: Icon(Icons.folder),
              label: 'My Projects',
            ),
            NavigationDestination(
              icon: Icon(Icons.bookmark_border),
              selectedIcon: Icon(Icons.bookmark),
              label: 'Bookmarks',
            ),
            NavigationDestination(
              icon: Icon(Icons.archive_outlined),
              selectedIcon: Icon(Icons.archive),
              label: 'Archives',
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _ExploreTab extends StatelessWidget {
  const _ExploreTab({required this.projectService, required this.authService});
  final ProjectService projectService;
  final AuthService authService;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Welcome Section
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.school,
                      size: 32,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Welcome to projectshow',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Explore amazing projects from fellow students and showcase your own work!',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Featured Projects
        Text(
          'Featured Projects',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (projectService.featuredProjects.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.star_border, size: 48, color: Colors.grey),
                    SizedBox(height: 8),
                    Text('No featured projects yet'),
                  ],
                ),
              ),
            ),
          )
        else
          ...projectService.featuredProjects.take(3).map((project) => _ProjectCard(
            project: project,
            projectService: projectService,
            authService: authService,
            onTap: () => _openProjectDetail(context, project),
          )),

        const SizedBox(height: 24),

        // Recent Projects
        Text(
          'Recent Projects',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (projectService.projects.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.folder_open, size: 48, color: Colors.grey),
                    SizedBox(height: 8),
                    Text('No projects available yet'),
                  ],
                ),
              ),
            ),
          )
        else
          ...projectService.projects
              .where((p) => p.status == ProjectStatus.approved)
              .take(5)
              .map((project) => _ProjectCard(
                    project: project,
                    projectService: projectService,
                    authService: authService,
                    onTap: () => _openProjectDetail(context, project),
                  )),
      ],
    );
  }

  void _openProjectDetail(BuildContext context, Project project) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProjectDetailScreen(
          project: project,
          projectService: projectService,
          authService: AuthService(),
        ),
      ),
    );
  }
}

class _UploadTab extends StatefulWidget {
  const _UploadTab({required this.projectService, required this.authService});
  final ProjectService projectService;
  final AuthService authService;

  @override
  State<_UploadTab> createState() => _UploadTabState();
}

class _UploadTabState extends State<_UploadTab> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _abstractController = TextEditingController();
  final _yearController = TextEditingController();
  final _githubController = TextEditingController();
  final List<String> _selectedImagePaths = <String>[];
  String? _selectedPdfPath;
  List<User> _approvedTeachers = [];
  String? _selectedTeacherId; // No default - must select a teacher for approval
  String? _selectedSupervisorId; // Supervisor selection (optional, can be same as approver)
  bool _isLoadingTeachers = false;
  
  ProjectSubmissionType _submissionType = ProjectSubmissionType.projectShowcase;
  AcademicCourse? _selectedAcademicCourse; // Required for Academic submission
  String? _selectedAssistantTeacherId; // Optional for Academic submission
  ProjectCategory _selectedCategory = ProjectCategory.other;
  ProjectType _selectedProjectType = ProjectType.project;
  Semester _selectedSemester = Semester.summer;
  bool _isSubmitting = false;

  // Group/Individual project fields
  bool _isGroupProject = false;
  final _groupNameController = TextEditingController();
  int _numberOfMembers = 2;
  final List<Map<String, TextEditingController>> _teamMemberControllers = [];
  
  // Individual student fields
  final _studentIdController = TextEditingController();
  final _batchController = TextEditingController();
  final _levelController = TextEditingController();
  final _termController = TextEditingController();
  
  // Drive link
  final _driveLinkController = TextEditingController();
  
  // YouTube link
  final _youtubeLinkController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeTeamMembers();
    _loadTeachers();
  }

  void _initializeTeamMembers() {
    _teamMemberControllers.clear();
    for (int i = 0; i < _numberOfMembers; i++) {
      _teamMemberControllers.add({
        'name': TextEditingController(),
        'id': TextEditingController(),
        'batch': TextEditingController(),
        'level': TextEditingController(),
        'term': TextEditingController(),
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _abstractController.dispose();
    _yearController.dispose();
    _yearController.dispose();
    _githubController.dispose();
    _groupNameController.dispose();
    _studentIdController.dispose();
    _batchController.dispose();
    _levelController.dispose();
    _termController.dispose();
    _driveLinkController.dispose();
    _youtubeLinkController.dispose();
    for (var controllers in _teamMemberControllers) {
      controllers.values.forEach((c) => c.dispose());
    }
    super.dispose();
  }

  Future<void> _loadTeachers() async {
    setState(() => _isLoadingTeachers = true);
    try {
      final teachers = await widget.authService.getUsersByRole(UserRole.teacher);
      final approved = teachers.where((teacher) => teacher.isApproved).toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      if (mounted) {
        setState(() {
          _approvedTeachers = approved;
          _isLoadingTeachers = false;
          // Don't set default - user must select a teacher
        });
      }
    } catch (e) {
      debugPrint('StudentDashboard: Error loading teachers $e');
      if (mounted) {
        setState(() => _isLoadingTeachers = false);
      }
    }
  }

  Future<void> _submitProject() async {
    if (_formKey.currentState!.validate() && widget.authService.currentUser != null) {
      debugPrint('StudentDashboard: Starting project submission');
      setState(() => _isSubmitting = true);

      // Teacher selection is now required - must select a specific teacher
      if (_selectedTeacherId == null || _selectedTeacherId!.isEmpty || _selectedTeacherId == 'all') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select a teacher for project approval')),
          );
        }
        setState(() => _isSubmitting = false);
        return;
      }

      User? selectedTeacher;
      try {
        selectedTeacher = _approvedTeachers.firstWhere((teacher) => teacher.id == _selectedTeacherId);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Selected teacher not found. Please select again.')),
          );
        }
        setState(() => _isSubmitting = false);
        return;
      }
      
      if (selectedTeacher == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select a teacher for project approval')),
          );
        }
        setState(() => _isSubmitting = false);
        return;
      }
      
      // Get supervisor name - use selected supervisor if provided, otherwise use approving teacher
      final supervisorTeacher = _selectedSupervisorId != null
          ? _approvedTeachers.firstWhere((t) => t.id == _selectedSupervisorId)
          : selectedTeacher;
      final supervisorName = supervisorTeacher.name;

      // Build team members list if group project
      final List<TeamMember> teamMembers = [];
      if (_isGroupProject) {
        for (var controllers in _teamMemberControllers) {
          teamMembers.add(TeamMember(
            name: controllers['name']!.text.trim(),
            id: controllers['id']!.text.trim(),
            batch: int.tryParse(controllers['batch']!.text) ?? 0,
            level: int.tryParse(controllers['level']!.text) ?? 0,
            term: int.tryParse(controllers['term']!.text) ?? 0,
          ));
        }
      }

      // Validate Academic submission requirements
      if (_submissionType == ProjectSubmissionType.academic && _selectedAcademicCourse == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select an academic course')),
          );
        }
        setState(() => _isSubmitting = false);
        return;
      }

      final project = Project(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text.trim(),
        abstract: _abstractController.text.trim(),
        authorId: widget.authService.currentUser!.id,
        authorName: widget.authService.currentUser!.name,
        category: _selectedCategory,
        year: int.tryParse(_yearController.text) ?? DateTime.now().year,
        semester: _selectedSemester,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        status: ProjectStatus.pending,
        githubUrl: _githubController.text.trim().isNotEmpty ? _githubController.text.trim() : null,
        imageUrls: _selectedImagePaths,
        pdfUrl: _selectedPdfPath,
        supervisor: supervisorName,
        facultyId: selectedTeacher.id, // Required - must be assigned to a specific teacher
        facultyName: selectedTeacher.name,
        projectType: _selectedProjectType,
        isGroupProject: _isGroupProject,
        groupName: _isGroupProject ? _groupNameController.text.trim() : null,
        teamMembers: teamMembers,
        driveLink: _driveLinkController.text.trim().isNotEmpty ? _driveLinkController.text.trim() : null,
        youtubeUrl: _youtubeLinkController.text.trim().isNotEmpty ? _youtubeLinkController.text.trim() : null,
        studentId: !_isGroupProject ? _studentIdController.text.trim() : null,
        batch: !_isGroupProject ? int.tryParse(_batchController.text) : null,
        level: !_isGroupProject ? int.tryParse(_levelController.text) : null,
        term: !_isGroupProject ? int.tryParse(_termController.text) : null,
        submissionType: _submissionType,
        academicCourse: _submissionType == ProjectSubmissionType.academic ? _selectedAcademicCourse : null,
        assistantTeacherId: _submissionType == ProjectSubmissionType.academic ? _selectedAssistantTeacherId : null,
      );

      debugPrint('StudentDashboard: Project created, calling createProject service');
      debugPrint('StudentDashboard: Project has ${project.imageUrls.length} images and PDF: ${project.pdfUrl != null}');

      // Create status controller for dialog updates
      final uploadStatusController = ValueNotifier<String>('Preparing files...');
      
      // Show upload progress dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => ValueListenableBuilder<String>(
          valueListenable: uploadStatusController,
          builder: (context, status, _) => AlertDialog(
            title: const Text('Uploading Project'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  status,
                  style: const TextStyle(fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );

      bool success = false;
      
      try {
        // Add timeout to prevent infinite loading
        success = await Future.any([
          _submitProjectWithProgress(project, uploadStatusController),
          Future.delayed(const Duration(seconds: 60), () {
            uploadStatusController.value = 'Upload timeout!';
            return false;
          }),
        ]);
      } catch (e) {
        debugPrint('StudentDashboard: Error during upload: $e');
        uploadStatusController.value = 'Error: $e';
        success = false;
        await Future.delayed(const Duration(seconds: 1));
      } finally {
        // Close dialog - ensure it closes even if there's an error
        if (mounted) {
          // Check if dialog is still open before trying to close
          try {
            Navigator.of(context, rootNavigator: false).pop();
          } catch (e) {
            debugPrint('Dialog already closed or error closing: $e');
          }
        }
        uploadStatusController.dispose();
      }
      
      debugPrint('StudentDashboard: Project creation result: $success');
      setState(() => _isSubmitting = false);

      if (success && mounted) {
        debugPrint('StudentDashboard: Project submitted successfully, showing success message');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_selectedProjectType == ProjectType.thesis ? 'Thesis' : 'Project'} submitted successfully! It will be reviewed by teachers.'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        _clearForm();
      } else if (mounted) {
        debugPrint('StudentDashboard: Project submission failed, showing error message');
        final errorMsg = _lastUploadError ?? 'Failed to submit project. Please check your internet connection and try again.';
        
        // Check if error message already contains specific guidance
        final hasSpecificError = errorMsg.contains('Permission denied') || 
                                 errorMsg.contains('bucket not found') ||
                                 errorMsg.contains('Authentication required');
        
        // Show detailed error dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Upload Failed', style: TextStyle(color: Colors.red)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Error Details:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(errorMsg),
                  if (!hasSpecificError) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Quick Fix Steps:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text('1. Go to Firebase Console'),
                    const Text('2. Click Storage → Check if bucket exists'),
                    const Text('3. If missing, create it and configure rules'),
                    const Text('4. Go to Storage → Rules → Allow upload operations'),
                  ] else ...[
                    const SizedBox(height: 16),
                    const Text(
                      'To fix this issue:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    if (errorMsg.contains('Permission denied'))
                      const Text('• Go to Firebase Console → Storage → Rules\n• Update rules to allow uploads'),
                    if (errorMsg.contains('bucket not found'))
                      const Text('• Go to Firebase Console → Storage\n• Create a new storage bucket'),
                    if (errorMsg.contains('Authentication required'))
                      const Text('• Make sure you are logged in\n• Try logging out and back in'),
                  ],
                  const SizedBox(height: 8),
                  const Text(
                    'Check console logs for more details.',
                    style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        
        _lastUploadError = null; // Clear error after showing
      }
    } else {
      debugPrint('StudentDashboard: Form validation failed or user is null');
    }
  }

  Future<bool> _submitProjectWithProgress(Project project, ValueNotifier<String> statusNotifier) async {
    String? errorMessage;
    try {
      statusNotifier.value = 'Preparing files...';
      await Future.delayed(const Duration(milliseconds: 100));
      
      if (project.pdfUrl != null && project.pdfUrl!.isNotEmpty) {
        statusNotifier.value = 'Uploading PDF file to Firebase...';
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      if (project.imageUrls.isNotEmpty) {
        statusNotifier.value = 'Uploading ${project.imageUrls.length} image(s) to Firebase...';
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      statusNotifier.value = 'Saving project to database...';
      
      final success = await widget.projectService.createProject(project);
      
      if (success) {
        statusNotifier.value = 'Upload complete!';
        // Brief delay to show success message, then return (dialog will close in finally block)
        await Future.delayed(const Duration(milliseconds: 500));
      } else {
        errorMessage = 'Upload failed. Check console logs for details.';
        statusNotifier.value = 'Upload failed!';
        // Brief delay to show error message
        await Future.delayed(const Duration(milliseconds: 800));
      }
      
      return success;
    } catch (e, stackTrace) {
      errorMessage = 'Upload Error: $e';
      debugPrint('StudentDashboard: Upload error: $e');
      debugPrint('StudentDashboard: Stack trace: $stackTrace');
      
      // Show specific error message
      final errorString = e.toString();
      if (errorString.contains('PDF upload failed') || errorString.contains('Bucket') || errorString.contains('Permission') || errorString.contains('policy')) {
        statusNotifier.value = 'PDF upload failed!';
        // Extract the actual error message from the exception
        errorMessage = errorString.replaceAll('Exception: ', '').replaceAll('Error: ', '');
        if (errorMessage.length > 200) {
          errorMessage = errorMessage.substring(0, 200) + '...';
        }
      } else {
        statusNotifier.value = 'Error occurred!';
        errorMessage = errorString.replaceAll('Exception: ', '').replaceAll('Error: ', '');
      }
      
      await Future.delayed(const Duration(milliseconds: 1000));
      return false;
    } finally {
      // Store error message for display
      if (errorMessage != null) {
        _lastUploadError = errorMessage;
      }
    }
  }
  
  String? _lastUploadError;

  void _clearForm() {
    _titleController.clear();
    _abstractController.clear();
    _yearController.clear();
    _githubController.clear();
    _groupNameController.clear();
    _studentIdController.clear();
    _batchController.clear();
    _levelController.clear();
    _termController.clear();
    _driveLinkController.clear();
    _youtubeLinkController.clear();
    for (var controllers in _teamMemberControllers) {
      controllers.values.forEach((c) => c.clear());
    }
    setState(() {
      _selectedCategory = ProjectCategory.other;
      _selectedProjectType = ProjectType.project;
      _selectedSemester = Semester.summer;
      _submissionType = ProjectSubmissionType.projectShowcase;
      _selectedAcademicCourse = null;
      _selectedAssistantTeacherId = null;
      _selectedImagePaths.clear();
      _selectedPdfPath = null;
      _selectedTeacherId = null; // Reset to require selection
      _selectedSupervisorId = null; // Reset supervisor selection
      _isGroupProject = false;
      _numberOfMembers = 2;
      _initializeTeamMembers();
    });
  }

  Future<void> _pickImages() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'webp'],
      );
      if (result != null) {
        setState(() {
          _selectedImagePaths
            ..clear()
            ..addAll(result.paths.whereType<String>());
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${result.paths.length} image(s) selected'),
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to pick images: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _pickPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (result != null && result.files.single.path != null) {
        setState(() => _selectedPdfPath = result.files.single.path);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('PDF selected successfully'),
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to pick PDF: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Card(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(
                      Icons.upload,
                      size: 48,
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Upload Your Work',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Share your academic work with the projectshow community',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSecondaryContainer.withOpacity(0.8),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Submission Type Selection
            Card(
              elevation: 4,
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.class_outlined,
                          size: 20,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Submission Category',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _submissionType = ProjectSubmissionType.projectShowcase;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                              decoration: BoxDecoration(
                                color: _submissionType == ProjectSubmissionType.projectShowcase
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _submissionType == ProjectSubmissionType.projectShowcase
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.outline,
                                  width: 2,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.public,
                                    size: 24,
                                    color: _submissionType == ProjectSubmissionType.projectShowcase
                                        ? Theme.of(context).colorScheme.onPrimary
                                        : Theme.of(context).colorScheme.onSurface,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Project Showcase',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: _submissionType == ProjectSubmissionType.projectShowcase
                                          ? Theme.of(context).colorScheme.onPrimary
                                          : Theme.of(context).colorScheme.onSurface,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _submissionType = ProjectSubmissionType.academic;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                              decoration: BoxDecoration(
                                color: _submissionType == ProjectSubmissionType.academic
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _submissionType == ProjectSubmissionType.academic
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.outline,
                                  width: 2,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.school,
                                    size: 24,
                                    color: _submissionType == ProjectSubmissionType.academic
                                        ? Theme.of(context).colorScheme.onPrimary
                                        : Theme.of(context).colorScheme.onSurface,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Academic',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: _submissionType == ProjectSubmissionType.academic
                                          ? Theme.of(context).colorScheme.onPrimary
                                          : Theme.of(context).colorScheme.onSurface,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_submissionType == ProjectSubmissionType.academic) ...[
                      const SizedBox(height: 16),
                      DropdownButtonFormField<AcademicCourse>(
                        decoration: const InputDecoration(
                          labelText: 'Course Name *',
                          prefixIcon: Icon(Icons.book),
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        value: _selectedAcademicCourse,
                        items: AcademicCourse.values.map((course) => DropdownMenuItem(
                          value: course,
                          child: Text(
                            course.displayName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14),
                          ),
                        )).toList(),
                        onChanged: (AcademicCourse? value) {
                          if (value != null) {
                            setState(() => _selectedAcademicCourse = value);
                          }
                        },
                        validator: (value) {
                          if (_submissionType == ProjectSubmissionType.academic && value == null) {
                            return 'Please select a course';
                          }
                          return null;
                        },
                        isExpanded: true,
                      ),

                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Project Type Selection
            Card(
              elevation: 4,
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.category,
                          size: 20,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Submission Type',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _selectedProjectType = ProjectType.project;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                              decoration: BoxDecoration(
                                color: _selectedProjectType == ProjectType.project
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _selectedProjectType == ProjectType.project
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.outline,
                                  width: 2,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.code,
                                    size: 24,
                                    color: _selectedProjectType == ProjectType.project
                                        ? Theme.of(context).colorScheme.onPrimary
                                        : Theme.of(context).colorScheme.onSurface,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Project',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: _selectedProjectType == ProjectType.project
                                          ? Theme.of(context).colorScheme.onPrimary
                                          : Theme.of(context).colorScheme.onSurface,
                                    ),
                                  ),
                                  if (_selectedProjectType == ProjectType.project)
                                    const SizedBox(height: 2),
                                  if (_selectedProjectType == ProjectType.project)
                                    Text(
                                      'Optional: GitHub, Images',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.8),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _selectedProjectType = ProjectType.thesis;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                              decoration: BoxDecoration(
                                color: _selectedProjectType == ProjectType.thesis
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _selectedProjectType == ProjectType.thesis
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.outline,
                                  width: 2,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.menu_book,
                                    size: 24,
                                    color: _selectedProjectType == ProjectType.thesis
                                        ? Theme.of(context).colorScheme.onPrimary
                                        : Theme.of(context).colorScheme.onSurface,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Thesis',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: _selectedProjectType == ProjectType.thesis
                                          ? Theme.of(context).colorScheme.onPrimary
                                          : Theme.of(context).colorScheme.onSurface,
                                    ),
                                  ),
                                  if (_selectedProjectType == ProjectType.thesis)
                                    const SizedBox(height: 2),
                                  if (_selectedProjectType == ProjectType.thesis)
                                    Text(
                                      'PDF Required',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.8),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Form Fields
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: _selectedProjectType == ProjectType.thesis ? 'Thesis Title' : 'Project Title',
                hintText: _selectedProjectType == ProjectType.thesis 
                    ? 'Enter a descriptive title for your thesis'
                    : 'Enter a descriptive title for your project',
                prefixIcon: const Icon(Icons.title),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return _selectedProjectType == ProjectType.thesis 
                      ? 'Please enter a thesis title'
                      : 'Please enter a project title';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _abstractController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Abstract',
                hintText: 'Describe your project, its objectives, and key findings',
                prefixIcon: Icon(Icons.description),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter an abstract';
                }
                if (value.trim().length < 50) {
                  return 'Abstract must be at least 50 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<ProjectCategory>(
              decoration: const InputDecoration(
                labelText: 'Category',
                prefixIcon: Icon(Icons.category),
              ),
              value: _selectedCategory,
              items: ProjectCategory.values.map((category) => DropdownMenuItem(
                value: category,
                child: Text(category.displayName),
              )).toList(),
              onChanged: (ProjectCategory? value) {
                if (value != null) {
                  setState(() => _selectedCategory = value);
                }
              },
            ),
            const SizedBox(height: 16),

            SizedBox(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _yearController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Year',
                        hintText: 'e.g., 2024',
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Required';
                        }
                        final year = int.tryParse(value);
                        if (year == null || year < 2000 || year > DateTime.now().year + 1) {
                          return 'Invalid year';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<Semester>(
                      decoration: const InputDecoration(
                        labelText: 'Semester',
                        prefixIcon: Icon(Icons.date_range),
                      ),
                      value: _selectedSemester,
                      items: Semester.values.map((s) => DropdownMenuItem(
                        value: s,
                        child: Text(s.displayName),
                      )).toList(),
                      onChanged: (Semester? value) {
                        if (value != null) {
                          setState(() => _selectedSemester = value);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (_selectedProjectType == ProjectType.project) ...[
              TextFormField(
                controller: _githubController,
                decoration: const InputDecoration(
                  labelText: 'GitHub URL *',
                  hintText: 'https://github.com/username/repository',
                  prefixIcon: Icon(Icons.code),
                  helperText: 'Link to your project repository',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter GitHub URL';
                  }
                  // Basic validation
                  if (!value.toLowerCase().contains('github.com')) {
                     return 'Please enter a valid GitHub URL';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
            ],

            // Team Configuration Section
            Text(
              'Team Configuration',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<bool>(
                    title: const Text('Individual'),
                    value: false,
                    groupValue: _isGroupProject,
                    onChanged: (bool? value) {
                      if (value != null) {
                        setState(() => _isGroupProject = value);
                      }
                    },
                  ),
                ),
                Expanded(
                  child: RadioListTile<bool>(
                    title: const Text('Group'),
                    value: true,
                    groupValue: _isGroupProject,
                    onChanged: (bool? value) {
                      if (value != null) {
                        setState(() {
                          _isGroupProject = value;
                          if (_teamMemberControllers.isEmpty) {
                            _initializeTeamMembers();
                          }
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Individual Project Fields
            if (!_isGroupProject) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Student Details',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _studentIdController,
                        decoration: const InputDecoration(labelText: 'Student ID'),
                        validator: (value) {
                          if (!_isGroupProject && (value == null || value.trim().isEmpty)) {
                            return 'Please enter student ID';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _batchController,
                              decoration: const InputDecoration(labelText: 'Batch'),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (!_isGroupProject && (value == null || value.trim().isEmpty)) {
                                  return 'Required';
                                }
                                if (!_isGroupProject && int.tryParse(value!) == null) {
                                  return 'Must be a number';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _levelController,
                              decoration: const InputDecoration(labelText: 'Level'),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (!_isGroupProject && (value == null || value.trim().isEmpty)) {
                                  return 'Required';
                                }
                                if (!_isGroupProject && int.tryParse(value!) == null) {
                                  return 'Must be a number';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _termController,
                              decoration: const InputDecoration(labelText: 'Term'),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (!_isGroupProject && (value == null || value.trim().isEmpty)) {
                                  return 'Required';
                                }
                                if (!_isGroupProject && int.tryParse(value!) == null) {
                                  return 'Must be a number';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // Group Project Fields
            if (_isGroupProject) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Group Details',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _groupNameController,
                        decoration: const InputDecoration(labelText: 'Group Name'),
                        validator: (value) {
                          if (_isGroupProject && (value == null || value.trim().isEmpty)) {
                            return 'Please enter group name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        decoration: const InputDecoration(labelText: 'Number of Team Members'),
                        value: _numberOfMembers,
                        items: List.generate(3, (index) => index + 2).map((count) => DropdownMenuItem(
                          value: count,
                          child: Text('$count members'),
                        )).toList(),
                        onChanged: (int? value) {
                          if (value != null) {
                            setState(() {
                              _numberOfMembers = value;
                              _initializeTeamMembers();
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Team Members
              ...List.generate(_numberOfMembers, (index) {
                final controllers = _teamMemberControllers[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ExpansionTile(
                    title: Text('Team Member ${index + 1}'),
                    initiallyExpanded: index == 0,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            TextFormField(
                              controller: controllers['name'],
                              decoration: const InputDecoration(labelText: 'Name'),
                              validator: (value) {
                                if (_isGroupProject && (value == null || value.trim().isEmpty)) {
                                  return 'Please enter name';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: controllers['id'],
                              decoration: const InputDecoration(labelText: 'Student ID'),
                              validator: (value) {
                                if (_isGroupProject && (value == null || value.trim().isEmpty)) {
                                  return 'Please enter student ID';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: controllers['batch'],
                                    decoration: const InputDecoration(labelText: 'Batch'),
                                    keyboardType: TextInputType.number,
                                    validator: (value) {
                                      if (_isGroupProject && (value == null || value.trim().isEmpty)) {
                                        return 'Required';
                                      }
                                      if (_isGroupProject && int.tryParse(value!) == null) {
                                        return 'Number only';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: controllers['level'],
                                    decoration: const InputDecoration(labelText: 'Level'),
                                    keyboardType: TextInputType.number,
                                    validator: (value) {
                                      if (_isGroupProject && (value == null || value.trim().isEmpty)) {
                                        return 'Required';
                                      }
                                      if (_isGroupProject && int.tryParse(value!) == null) {
                                        return 'Number only';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: controllers['term'],
                                    decoration: const InputDecoration(labelText: 'Term'),
                                    keyboardType: TextInputType.number,
                                    validator: (value) {
                                      if (_isGroupProject && (value == null || value.trim().isEmpty)) {
                                        return 'Required';
                                      }
                                      if (_isGroupProject && int.tryParse(value!) == null) {
                                        return 'Number only';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 16),
            ],
            
            // Additional Resources (Drive Link)
            Text(
              'Additional Resources',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _driveLinkController,
              decoration: const InputDecoration(
                labelText: 'Google Drive Link (optional)',
                hintText: 'Link to screenshots, additional PDFs, or posters',
                prefixIcon: Icon(Icons.cloud_upload),
              ),
              validator: (value) {
                if (value != null && value.trim().isNotEmpty) {
                  // Basic URL validation
                  if (!value.trim().startsWith('http://') && !value.trim().startsWith('https://')) {
                    return 'Please enter a valid URL';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _youtubeLinkController,
              decoration: const InputDecoration(
                labelText: 'YouTube Video Link (optional)',
                hintText: 'https://www.youtube.com/watch?v=...',
                prefixIcon: Icon(Icons.video_library),
                helperText: 'Add a YouTube video demo of your project',
              ),
              validator: (value) {
                if (value != null && value.trim().isNotEmpty) {
                  // YouTube URL validation
                  if (!value.trim().contains('youtube.com') && !value.trim().contains('youtu.be')) {
                    return 'Please enter a valid YouTube URL';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            DropdownButtonFormField<String>(
              value: (_selectedTeacherId != null && 
                      _selectedTeacherId != 'all' && 
                      _approvedTeachers.any((t) => t.id == _selectedTeacherId))
                  ? _selectedTeacherId
                  : null,
              decoration: const InputDecoration(
                labelText: 'Select Teacher for Approval *',
                hintText: 'Choose a teacher (Required)',
                prefixIcon: Icon(Icons.person),
                helperText: 'This teacher will review and approve your project',
              ),
              isExpanded: true,
              items: _approvedTeachers.map(
                (teacher) => DropdownMenuItem(
                  value: teacher.id,
                  child: Text(
                    teacher.designation != null 
                        ? '${teacher.name} (${teacher.designation!.displayName})'
                        : teacher.name,
                  ),
                ),
              ).toList(),
              onChanged: _isLoadingTeachers ? null : (value) {
                if (value != null && value != 'all') {
                  setState(() => _selectedTeacherId = value);
                } else {
                  setState(() => _selectedTeacherId = null);
                }
              },
              validator: (value) {
                if (value == null || value.isEmpty || value == 'all') {
                  return 'Please select a teacher for approval';
                }
                return null;
              },
            ),
            if (_isLoadingTeachers)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(minHeight: 2),
              )
            else if (_approvedTeachers.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'No teachers available yet. Please check back later.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            const SizedBox(height: 24),

            // Supervisor Selection
            DropdownButtonFormField<String>(
              value: (_selectedSupervisorId != null && 
                      _approvedTeachers.any((t) => t.id == _selectedSupervisorId))
                  ? _selectedSupervisorId
                  : null,
              decoration: const InputDecoration(
                labelText: 'Select Supervisor *',
                hintText: 'Choose a supervisor',
                prefixIcon: Icon(Icons.school),
                helperText: 'Select the teacher supervising this project',
              ),
              isExpanded: true,
              items: _approvedTeachers.map(
                (teacher) => DropdownMenuItem(
                  value: teacher.id,
                  child: Text(
                    teacher.designation != null 
                        ? '${teacher.name} (${teacher.designation!.displayName})'
                        : teacher.name,
                  ),
                ),
              ).toList(),
              onChanged: _isLoadingTeachers ? null : (value) {
                 if (value != null) {
                   setState(() => _selectedSupervisorId = value);
                 }
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select a supervisor';
                }
                return null;
              },
            ),
            if (_submissionType == ProjectSubmissionType.academic) ...[
              const SizedBox(height: 24),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Assistant Teacher (Optional)',
                  prefixIcon: Icon(Icons.person_outline),
                  helperText: 'Select an assistant teacher if applicable',
                ),
                isExpanded: true,
                value: _selectedAssistantTeacherId,
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('None'),
                  ),
                  ..._approvedTeachers.map((teacher) => DropdownMenuItem(
                    value: teacher.id,
                    child: Text(teacher.name),
                  )),
                ],
                onChanged: (String? value) {
                  setState(() => _selectedAssistantTeacherId = value);
                },
              ),
            ],
            const SizedBox(height: 24),

            // File Upload Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Attachments',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickPdf,
                            icon: Icon(
                              _selectedPdfPath == null ? Icons.picture_as_pdf_outlined : Icons.check_circle,
                              color: _selectedPdfPath == null ? null : Colors.green,
                            ),
                            label: Text(_selectedPdfPath == null 
                                ? 'Attach PDF'
                                : 'PDF Selected'),
                          ),
                        ),
                        if (_selectedProjectType == ProjectType.project) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickImages,
                              icon: Icon(
                                _selectedImagePaths.isEmpty ? Icons.image_outlined : Icons.check_circle,
                                color: _selectedImagePaths.isEmpty ? null : Colors.green,
                              ),
                              label: Text(_selectedImagePaths.isEmpty ? 'Add Images' : '${_selectedImagePaths.length} Images'),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (_selectedImagePaths.isNotEmpty || _selectedPdfPath != null) ...[
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 8),
                      if (_selectedPdfPath != null)
                        ListTile(
                          leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                          title: Text('PDF: ${_selectedPdfPath!.split('/').last}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => setState(() => _selectedPdfPath = null),
                          ),
                          contentPadding: EdgeInsets.zero,
                        ),
                      if (_selectedImagePaths.isNotEmpty)
                        ListTile(
                          leading: const Icon(Icons.image, color: Colors.blue),
                          title: Text('${_selectedImagePaths.length} image(s) selected'),
                          trailing: IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => setState(() => _selectedImagePaths.clear()),
                          ),
                          contentPadding: EdgeInsets.zero,
                        ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSubmitting ? null : () {

                  _submitProject();
                },
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        'Submit ${_selectedProjectType == ProjectType.thesis ? 'Thesis' : 'Project'} for Review',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MyProjectsTab extends StatelessWidget {
  const _MyProjectsTab({required this.projectService, required this.authService});
  final ProjectService projectService;
  final AuthService authService;

  @override
  Widget build(BuildContext context) {
    final user = authService.currentUser;
    if (user == null) return const Center(child: Text('Please log in'));

    final userProjects = projectService.projects
        .where((p) => p.authorId == user.id)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header
        Card(
          color: Theme.of(context).colorScheme.tertiaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(
                  Icons.folder,
                  size: 48,
                  color: Theme.of(context).colorScheme.onTertiaryContainer,
                ),
                const SizedBox(height: 12),
                Text(
                  'My Projects',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onTertiaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${userProjects.length} project${userProjects.length == 1 ? '' : 's'} uploaded',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onTertiaryContainer.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Projects List
        if (userProjects.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.upload_file, size: 48, color: Colors.grey),
                    SizedBox(height: 8),
                    Text('No projects uploaded yet'),
                    SizedBox(height: 4),
                    Text('Start by uploading your first project!'),
                  ],
                ),
              ),
            ),
          )
        else
          ...userProjects.map((project) => _ProjectCard(
                project: project,
                projectService: projectService,
                authService: authService,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ProjectDetailScreen(
                      project: project,
                      projectService: projectService,
                      authService: authService,
                    ),
                  ),
                ),
              )),
      ],
    );
  }
}

class _BookmarksTab extends StatelessWidget {
  const _BookmarksTab({required this.projectService, required this.authService});
  final ProjectService projectService;
  final AuthService authService;

  @override
  Widget build(BuildContext context) {
    final bookmarkedProjects = projectService.bookmarkedProjects;
    
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(
                  Icons.bookmark,
                  size: 48,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
                const SizedBox(height: 12),
                Text(
                  'Bookmarked Projects',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${bookmarkedProjects.length} project${bookmarkedProjects.length == 1 ? '' : 's'} saved',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Bookmarks List
        if (bookmarkedProjects.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.bookmark_border, size: 48, color: Colors.grey),
                    SizedBox(height: 8),
                    Text('No bookmarked projects yet'),
                    SizedBox(height: 4),
                    Text('Tap the bookmark icon on any project to save it here'),
                  ],
                ),
              ),
            ),
          )
        else
          ...bookmarkedProjects.map((project) => _ProjectCard(
                project: project,
                projectService: projectService,
                authService: authService,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ProjectDetailScreen(
                      project: project,
                      projectService: projectService,
                      authService: authService,
                    ),
                  ),
                ),
              )),
      ],
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({
    required this.project,
    required this.projectService,
    required this.authService,
    this.onTap,
  });
  final Project project;
  final ProjectService projectService;
  final AuthService authService;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final isBookmarked = projectService.isBookmarked(project.id);
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with title and status
              Row(
                children: [
                  Expanded(
                    child: Text(
                      project.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(project.status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _getStatusColor(project.status).withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          project.status.displayName,
                          style: TextStyle(
                            color: _getStatusColor(project.status),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (project.version > 1) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getStatusColor(project.status),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'v${project.version}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Abstract
              Text(
                project.abstract,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface.withOpacity(0.7),
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              
              // Tags and info
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  Chip(
                    label: Text(project.category.displayName),
                    backgroundColor: scheme.primaryContainer,
                    labelStyle: TextStyle(color: scheme.onPrimaryContainer),
                  ),
                  Chip(
                    label: Text(project.year.toString()),
                    backgroundColor: scheme.secondaryContainer,
                    labelStyle: TextStyle(color: scheme.onSecondaryContainer),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Supervisor info
            if (project.facultyName != null && project.facultyName!.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: scheme.primaryContainer.withOpacity(0.5),
                    width: 1,
                  ),
                ),
                child: Text(
                  project.status == ProjectStatus.approved
                      ? 'Approved by: ${project.facultyName}'
                      : 'Supervisor: ${project.facultyName}',
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              
              // Rejection Reason (if rejected)
              if (project.status == ProjectStatus.rejected && 
                  project.rejectionReason != null && 
                  project.rejectionReason!.isNotEmpty) ...[ 
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.red.withOpacity(0.4),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.cancel_outlined,
                            color: Colors.red[700],
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Rejection Reason',
                            style: TextStyle(
                              color: Colors.red[700],
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        project.rejectionReason!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[800],
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              
              // Footer with rating, author, and actions
              Row(
                children: [
                  // Rating
                  Row(
                    children: [
                      const Icon(Icons.star, size: 16, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        '${project.rating.toStringAsFixed(1)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '(${project.reviewCount})',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  
                  // Author
                  Expanded(
                    child: Text(
                      'By ${project.authorName}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurface.withOpacity(0.7),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  
                  // Actions
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                          color: isBookmarked ? scheme.primary : scheme.onSurface.withOpacity(0.6),
                        ),
                        onPressed: () => projectService.toggleBookmark(project.id),
                        tooltip: isBookmarked ? 'Remove bookmark' : 'Add bookmark',
                      ),
                      if (project.status == ProjectStatus.needsRevision)
                        IconButton(
                          icon: const Icon(Icons.feedback),
                          color: Colors.amber[700],
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => ProjectDetailScreen(
                                  project: project,
                                  projectService: projectService,
                                  authService: authService,
                                ),
                              ),
                            );
                          },
                          tooltip: 'View feedback and revise',
                        ),
                      Icon(
                        Icons.chevron_right,
                        color: scheme.primary,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(ProjectStatus status) {
    switch (status) {
      case ProjectStatus.hidden:
        return Colors.grey.shade400;
      case ProjectStatus.draft:
        return Colors.grey;
      case ProjectStatus.pending:
        return Colors.orange;
      case ProjectStatus.approved:
        return Colors.green;
      case ProjectStatus.rejected:
        return Colors.red;
      case ProjectStatus.featured:
        return Colors.purple;
      case ProjectStatus.needsRevision:
        return Colors.amber;
      case ProjectStatus.resubmitted:
        return Colors.blue;
    }
  }
}
