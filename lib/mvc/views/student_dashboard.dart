import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/project.dart';
import '../models/user.dart';
import '../controllers/project_service.dart';
import '../controllers/auth_service.dart';
import 'project_detail.dart';
import 'profile_settings_screen.dart';
import 'search_filter.dart';

class StudentDashboardScreen extends StatefulWidget {
  const StudentDashboardScreen({super.key});

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  final ProjectService _projectService = ProjectService();
  final AuthService _authService = AuthService();
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _projectService.ensureProjectsLoaded();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset(
            'asset/project.png',
            fit: BoxFit.contain,
          ),
        ),
        leadingWidth: 60,
        title: const Text('Student Dashboard'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
        actions: [
          IconButton(
            onPressed: () => Navigator.pushNamed(context, '/search'),
            icon: const Icon(Icons.search),
            tooltip: 'Search Projects',
          ),
          PopupMenuButton<String>(
            onSelected: (String value) async {
              if (value == 'profile') {
                Navigator.push(
                  context,
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
        ],
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
  final _supervisorController = TextEditingController();
  final List<String> _selectedImagePaths = <String>[];
  String? _selectedPdfPath;
  
  ProjectCategory _selectedCategory = ProjectCategory.other;
  ProjectType _selectedProjectType = ProjectType.project;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _abstractController.dispose();
    _yearController.dispose();
    _githubController.dispose();
    _supervisorController.dispose();
    super.dispose();
  }

  Future<void> _submitProject() async {
    debugPrint('StudentDashboard: _submitProject called');
    debugPrint('StudentDashboard: Form validation: ${_formKey.currentState?.validate()}');
    debugPrint('StudentDashboard: Current user: ${widget.authService.currentUser?.name}');
    
    if (_formKey.currentState!.validate() && widget.authService.currentUser != null) {
      debugPrint('StudentDashboard: Starting project submission');
      setState(() => _isSubmitting = true);

      final project = Project(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text.trim(),
        abstract: _abstractController.text.trim(),
        authorId: widget.authService.currentUser!.id,
        authorName: widget.authService.currentUser!.name,
        category: _selectedCategory,
        year: int.tryParse(_yearController.text) ?? DateTime.now().year,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        status: ProjectStatus.pending,
        githubUrl: _githubController.text.trim().isNotEmpty ? _githubController.text.trim() : null,
        imageUrls: _selectedImagePaths,
        pdfUrl: _selectedPdfPath,
        supervisor: _supervisorController.text.trim().isNotEmpty ? _supervisorController.text.trim() : null,
        facultyName: _supervisorController.text.trim().isNotEmpty ? _supervisorController.text.trim() : null,
        projectType: _selectedProjectType,
        semester: Semester.summer,
      );

      debugPrint('StudentDashboard: Project created, calling createProject service');
      debugPrint('StudentDashboard: Project has ${project.imageUrls.length} images and PDF: ${project.pdfUrl != null}');

      // Add timeout to prevent infinite loading
      final success = await Future.any([
        widget.projectService.createProject(project),
        Future.delayed(const Duration(seconds: 30), () => false),
      ]);
      
      debugPrint('StudentDashboard: Project creation result: $success');
      setState(() => _isSubmitting = false);

      if (success && mounted) {
        debugPrint('StudentDashboard: Project submitted successfully, showing success message');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_selectedProjectType == ProjectType.thesis ? 'Thesis' : 'Project'} submitted successfully! It will be reviewed by teachers.'),
            backgroundColor: Colors.green,
          ),
        );
        _clearForm();
        
        // Switch to My Projects tab to show the newly submitted project
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            final parentState = context.findAncestorStateOfType<_StudentDashboardScreenState>();
            if (parentState != null) {
              parentState.setState(() {
                parentState._selectedIndex = 2; // Switch to My Projects tab
              });
            }
          }
        });
      } else if (mounted) {
        debugPrint('StudentDashboard: Project submission failed, showing error message');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to submit project. A project with this title already exists or there was an error. Please try again with a different title.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } else {
      debugPrint('StudentDashboard: Form validation failed or user is null');
    }
  }

  void _clearForm() {
    _titleController.clear();
    _abstractController.clear();
    _yearController.clear();
    _githubController.clear();
    _supervisorController.clear();
    setState(() {
      _selectedCategory = ProjectCategory.other;
      _selectedProjectType = ProjectType.project;
      _selectedImagePaths.clear();
      _selectedPdfPath = null;
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

            // Project Type Selection
            Card(
              elevation: 4,
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.category,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Select Submission Type',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
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
                              padding: const EdgeInsets.all(16),
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
                                    size: 32,
                                    color: _selectedProjectType == ProjectType.project
                                        ? Theme.of(context).colorScheme.onPrimary
                                        : Theme.of(context).colorScheme.onSurface,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Project',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: _selectedProjectType == ProjectType.project
                                          ? Theme.of(context).colorScheme.onPrimary
                                          : Theme.of(context).colorScheme.onSurface,
                                    ),
                                  ),
                                  if (_selectedProjectType == ProjectType.project)
                                    const SizedBox(height: 4),
                                  if (_selectedProjectType == ProjectType.project)
                                    Text(
                                      'Optional: GitHub, Images',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.8),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _selectedProjectType = ProjectType.thesis;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(16),
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
                                    size: 32,
                                    color: _selectedProjectType == ProjectType.thesis
                                        ? Theme.of(context).colorScheme.onPrimary
                                        : Theme.of(context).colorScheme.onSurface,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Thesis',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: _selectedProjectType == ProjectType.thesis
                                          ? Theme.of(context).colorScheme.onPrimary
                                          : Theme.of(context).colorScheme.onSurface,
                                    ),
                                  ),
                                  if (_selectedProjectType == ProjectType.thesis)
                                    const SizedBox(height: 4),
                                  if (_selectedProjectType == ProjectType.thesis)
                                    Text(
                                      'PDF Required',
                                      style: TextStyle(
                                        fontSize: 12,
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

            TextFormField(
              controller: _yearController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Year',
                hintText: 'e.g., 2024',
                prefixIcon: Icon(Icons.calendar_today),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter the year';
                }
                final year = int.tryParse(value);
                if (year == null || year < 2000 || year > DateTime.now().year + 1) {
                  return 'Please enter a valid year';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            if (_selectedProjectType == ProjectType.project) ...[
              TextFormField(
                controller: _githubController,
                decoration: const InputDecoration(
                  labelText: 'GitHub URL (Optional)',
                  hintText: 'https://github.com/username/repository',
                  prefixIcon: Icon(Icons.code),
                ),
              ),
              const SizedBox(height: 16),
            ],

            TextFormField(
              controller: _supervisorController,
              decoration: InputDecoration(
                labelText: _selectedProjectType == ProjectType.thesis ? 'Supervisor Name (Required)' : 'Supervisor Name',
                hintText: 'e.g., Dr. Sarah Johnson, Prof. Michael Chen',
                prefixIcon: const Icon(Icons.person),
              ),
              validator: (value) {
                if (_selectedProjectType == ProjectType.thesis) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your supervisor\'s name';
                  }
                }
                return null;
              },
            ),
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
                    if (_selectedProjectType == ProjectType.thesis) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 20,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Thesis submission requires a PDF document.',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
                                ? (_selectedProjectType == ProjectType.thesis ? 'Attach Thesis PDF (Required)' : 'Attach PDF')
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
                  // Validate PDF is required for thesis
                  if (_selectedProjectType == ProjectType.thesis && _selectedPdfPath == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please attach a PDF document for thesis submission'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }
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

class _MyProjectsTab extends StatefulWidget {
  const _MyProjectsTab({required this.projectService, required this.authService, Key? key}) : super(key: key);
  final ProjectService projectService;
  final AuthService authService;

  @override
  State<_MyProjectsTab> createState() => _MyProjectsTabState();
}

class _MyProjectsTabState extends State<_MyProjectsTab> {
  final GlobalKey<_MyProjectsTabState> _myProjectsTabKey = GlobalKey<_MyProjectsTabState>();

  @override
  void initState() {
    super.initState();
    widget.projectService.ensureProjectsLoaded();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.authService.currentUser;
    if (user == null) return const Center(child: Text('Please log in'));

    final userProjects = widget.projectService.projects
        .where((p) => p.authorId == user.id)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    
    debugPrint('MyProjectsTab: Building with ${userProjects.length} user projects');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'My Projects',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh My Projects',
              onPressed: () async {
                await widget.projectService.ensureProjectsLoaded();
                setState(() {});
              },
            ),
          ],
        ),
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
                projectService: widget.projectService,
                authService: widget.authService,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ProjectDetailScreen(
                      project: project,
                      projectService: widget.projectService,
                      authService: widget.authService,
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
      case ProjectStatus.hidden:
        return Colors.blueGrey;
    }
  }
}
