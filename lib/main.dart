import 'package:flutter/material.dart';
import 'theme.dart';
import 'screens/auth.dart';
import 'screens/search_filter.dart';
import 'screens/project_detail.dart';
import 'screens/student_dashboard.dart';
import 'screens/teacher_dashboard.dart';
import 'screens/admin_dashboard.dart';
import 'mvc/controllers/auth_service.dart';
import 'mvc/controllers/project_service.dart';
import 'mvc/models/user.dart';
import 'mvc/models/project.dart';
import 'mvc/models/team_member.dart';
import 'mvc/controllers/notification_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// Web-specific imports for Firebase plugins
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:firebase_storage/firebase_storage.dart' as storage;

// Global AuthService instance
final AuthService globalAuthService = AuthService();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. Show loading screen immediately to prevent black screen
  runApp(const MaterialApp(
    home: Scaffold(
      backgroundColor: Color(0xFF0E121A), // Dark theme background
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF4F46E5)), // Primary color
            SizedBox(height: 20),
            Text(
              'Starting projectshow...', 
              style: TextStyle(color: Colors.white70),
              textDirection: TextDirection.ltr,
            ),
          ],
        ),
      ),
    ),
    debugShowCheckedModeBanner: false,
  ));
  
  // 2. Initialize Firebase (for Firestore, Auth, and Storage)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('Firebase initialized successfully');
    
    // Initialize Local Notifications safely
    try {
      // We can initialize this in the background, or await it if critical.
      // Since it handles permissions, doing it here might pop up permission dialogs 
      // on top of the loading screen, which is fine.
      // However, to keep startup fast, we might want to delegate this purely to AppShell
      // But AppShell logic we added previously is also good.
      // Let's leave it to AppShell to handle notification init to avoid further delays here.
    } catch (e) {
      debugPrint('Notification init skipped in main: $e');
    }

  } catch (e) {
    debugPrint('Firebase initialization error: $e');
    debugPrint('Please check your Firebase configuration in firebase_options.dart');
    
    // In case of fatal error, show it
    runApp(MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFF0E121A),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Initialization Failed',
                  style: TextStyle(color: Colors.white, fontSize: 20),
                ),
                const SizedBox(height: 8),
                Text(
                  e.toString(),
                  style: const TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    ));
    return;
  }
  
  // 3. Run the main app
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'projectshow',
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: ThemeMode.system,
      home: const AppShell(),
      routes: <String, WidgetBuilder>{
        '/auth': (context) => AuthGate(
              authService: globalAuthService,
              onEnter: (UserRole role) {
                debugPrint('Auth: onEnter called with role: $role');
                // Navigate to appropriate dashboard based on role
                if (role == UserRole.student) {
                  Navigator.of(context).pushReplacementNamed('/student');
                } else if (role == UserRole.teacher) {
                  Navigator.of(context).pushReplacementNamed('/teacher');
                } else if (role == UserRole.admin) {
                  Navigator.of(context).pushReplacementNamed('/admin');
                }
              },
            ),
        '/search': (_) => const SearchFilterScreen(),
        '/student': (_) => RoleGuard(
              authService: globalAuthService,
              requiredRole: UserRole.student,
              child: const StudentDashboardScreen(),
            ),
        '/teacher': (_) => RoleGuard(
              authService: globalAuthService,
              requiredRole: UserRole.teacher,
              allowAdmin: true,
              child: const TeacherDashboardScreen(),
            ),
        '/admin': (_) => RoleGuard(
              authService: globalAuthService,
              requiredRole: UserRole.admin,
              child: const AdminDashboardScreen(),
            ),
      },
    );
  }
}

class RoleGuard extends StatelessWidget {
  const RoleGuard({super.key, required this.authService, required this.requiredRole, this.allowAdmin = false, required this.child});
  final AuthService authService;
  final UserRole requiredRole;
  final bool allowAdmin;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isAllowed = authService.isAuthenticated &&
        (authService.currentUser?.role == requiredRole || (allowAdmin && authService.currentUser?.role == UserRole.admin));

    if (!authService.isAuthenticated) {
      return Scaffold(
        appBar: AppBar(title: const Text('Access Restricted')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Icon(Icons.lock_outline, size: 64),
              const SizedBox(height: 16),
              const Text('Please log in with the appropriate role'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pushNamed(context, '/auth'),
                child: const Text('Login'),
              ),
            ],
          ),
        ),
      );
    }

    // Check if teacher needs approval
    if (authService.needsApproval()) {
      return Scaffold(
        appBar: AppBar(title: const Text('Account Pending Approval')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.pending_actions, size: 64, color: Colors.orange),
                const SizedBox(height: 16),
                const Text(
                  'Your teacher account is pending admin approval',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please wait for an administrator to approve your account before you can access teacher features.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => authService.logout(),
                  child: const Text('Logout'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!isAllowed) {
      return Scaffold(
        appBar: AppBar(title: const Text('Access Denied')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('You do not have permission to access this section.'),
          ),
        ),
      );
    }

    return child;
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  final AuthService _authService = globalAuthService;
  final ProjectService _projectService = ProjectService();
  bool _isInitializing = true;
  bool _showWelcome = true;
  bool _hasRedirected = false;

  @override
  void initState() {
    super.initState();
    debugPrint('AppShell: initState called');
    
    // Listen to auth changes and update project service
    _authService.addListener(_onAuthStateChanged);
    
    // Explicitly sync initial state in case user is already logged in
    _onAuthStateChanged();
    
    // Start initialization
    _initializeApp();
    
    // Add a safety timeout to prevent infinite loading
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted && _isInitializing) {
        debugPrint('AppShell: Safety timeout reached, forcing initialization complete');
        setState(() {
          _isInitializing = false;
          _showWelcome = false;
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Redirect to login if not authenticated and haven't redirected yet
    if (!_authService.isAuthenticated && !_hasRedirected && !_isInitializing) {
      _hasRedirected = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          debugPrint('AppShell: Redirecting to auth page');
          Navigator.pushReplacementNamed(context, '/auth');
        }
      });
    }
  }

  Future<void> _initializeApp() async {
    try {
      debugPrint('AppShell: Starting app initialization');
      
      // Initialize Local Notifications (moved from main)
      try {
        await NotificationService().initialize();
        debugPrint('AppShell: Notifications initialized');
      } catch (e) {
        debugPrint('AppShell: Notification initialization failed: $e');
      }

      // Wait a bit for services to initialize, but with a timeout
      await Future.delayed(const Duration(milliseconds: 500)).timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          debugPrint('App initialization timeout - continuing anyway');
        },
      );
      
      debugPrint('AppShell: Setting _isInitializing to false');
      setState(() {
        _isInitializing = false;
      });
      
      // Show welcome screen for 2 seconds if user is not authenticated
      if (!_authService.isAuthenticated) {
        debugPrint('AppShell: User not authenticated, showing welcome screen');
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          setState(() {
            _showWelcome = false;
          });
        }
      } else {
        debugPrint('AppShell: User authenticated, skipping welcome screen');
        setState(() {
          _showWelcome = false;
        });
      }
      
      debugPrint('AppShell: App initialization complete');
    } catch (e) {
      debugPrint('Error initializing app: $e');
      setState(() {
        _isInitializing = false;
        _showWelcome = false;
      });
    }
  }

  @override
  void dispose() {
    _authService.removeListener(_onAuthStateChanged);
    super.dispose();
  }

  void _onAuthStateChanged() {
    if (_authService.isAuthenticated && _authService.currentUser != null) {
      _projectService.setCurrentUserId(_authService.currentUser!.id);
      _hasRedirected = false; // Reset redirect flag when user logs in
    } else {
      // User logged out, reset redirect flag
      _hasRedirected = false;
    }
  }

  List<Widget> get _pages => <Widget>[
    ExploreScreen(projectService: _projectService),
    UploadScreen(projectService: _projectService, authService: _authService),
    LeaderboardScreen(projectService: _projectService),
    BookmarksScreen(projectService: _projectService),
    ProfileScreen(authService: _authService, projectService: _projectService),
  ];

  final List<NavigationDestination> _destinations = const <NavigationDestination>[
    NavigationDestination(icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore), label: 'Explore'),
    NavigationDestination(icon: Icon(Icons.cloud_upload_outlined), selectedIcon: Icon(Icons.cloud_upload), label: 'Upload'),
    NavigationDestination(icon: Icon(Icons.emoji_events_outlined), selectedIcon: Icon(Icons.emoji_events), label: 'Top'),
    NavigationDestination(icon: Icon(Icons.bookmark_border), selectedIcon: Icon(Icons.bookmark), label: 'Saved'),
    NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('Initializing...'),
              const SizedBox(height: 8),
              Text('Debug: AuthService initialized: ${_authService != null}'),
              const SizedBox(height: 8),
              Text('Debug: ProjectService initialized: ${_projectService != null}'),
            ],
          ),
        ),
      );
    }

    if (_showWelcome) {
      return _WelcomeScreen(
        onGetStarted: () => setState(() => _showWelcome = false),
      );
    }

    return AnimatedBuilder(
      animation: _authService,
      builder: (context, child) {
        // Redirect authenticated users to their appropriate dashboard
        if (_authService.isAuthenticated && _authService.currentUser != null) {
          final user = _authService.currentUser!;
          debugPrint('AppShell: User authenticated, role: ${user.role}, name: ${user.name}');
          
          // Use a more reliable redirect approach with delay
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              debugPrint('AppShell: Navigating to dashboard for role: ${user.role}');
              try {
                if (user.role == UserRole.student) {
                  debugPrint('AppShell: Navigating to student dashboard');
                  Navigator.pushReplacementNamed(context, '/student');
                } else if (user.role == UserRole.teacher) {
                  debugPrint('AppShell: Navigating to teacher dashboard');
                  Navigator.pushReplacementNamed(context, '/teacher');
                } else if (user.role == UserRole.admin) {
                  debugPrint('AppShell: Navigating to admin dashboard');
                  Navigator.pushReplacementNamed(context, '/admin');
                }
              } catch (e) {
                debugPrint('AppShell: Navigation error: $e');
              }
            } else {
              debugPrint('AppShell: Widget not mounted, skipping navigation');
            }
          });
          
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text('Welcome ${user.name}!'),
                  const SizedBox(height: 8),
                  const Text('Redirecting to your dashboard...'),
                  const SizedBox(height: 8),
                  Text('Role: ${user.role.name}'),
                ],
              ),
            ),
          );
        }

        // Redirect unauthenticated users to login page
        Future.microtask(() {
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/auth');
          }
        });
        
        return const Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Redirecting to login...'),
              ],
            ),
          ),
        );
      },
    );
  }

}

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key, required this.projectService});
  final ProjectService projectService;

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  @override
  void initState() {
    super.initState();
    // Load projects when screen is first shown
    widget.projectService.ensureProjectsLoaded();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.projectService,
      builder: (context, child) {
        if (widget.projectService.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        const _SectionTitle('Trending Projects'),
        const SizedBox(height: 8),
            ...widget.projectService.trendingProjects.take(3).map((project) => _ProjectCard(
              project: project,
              projectService: widget.projectService,
              onTap: () => _open(context, project),
            )),
        const SizedBox(height: 24),
        const _SectionTitle('Featured by Faculty'),
        const SizedBox(height: 8),
            ...widget.projectService.featuredProjects.map((project) => _ProjectCard(
              project: project,
              projectService: widget.projectService,
              onTap: () => _open(context, project),
            )),
          ],
        );
      },
    );
  }

  void _open(BuildContext context, Project project) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ProjectDetailScreen(
        project: project, 
        projectService: widget.projectService,
        authService: AuthService(),
      ),
    ));
  }
}

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key, required this.projectService, required this.authService});
  final ProjectService projectService;
  final AuthService authService;

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _abstractController = TextEditingController();
  final _yearController = TextEditingController();
  final _githubController = TextEditingController();
  final List<String> _selectedImagePaths = <String>[];
  String? _selectedPdfPath;
  
  ProjectCategory _selectedCategory = ProjectCategory.other;
  ProjectType _selectedProjectType = ProjectType.project;
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

  @override
  void initState() {
    super.initState();
    _initializeTeamMembers();
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
    _githubController.dispose();
    _groupNameController.dispose();
    _studentIdController.dispose();
    _batchController.dispose();
    _levelController.dispose();
    _termController.dispose();
    _driveLinkController.dispose();
    for (var controllers in _teamMemberControllers) {
      controllers.values.forEach((c) => c.dispose());
    }
    super.dispose();
  }

  Future<void> _submitProject() async {
    if (_formKey.currentState!.validate() && widget.authService.currentUser != null) {
      setState(() => _isSubmitting = true);

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

      final project = Project(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text.trim(),
        abstract: _abstractController.text.trim(),
        authorId: widget.authService.currentUser!.id,
        authorName: widget.authService.currentUser!.name,
        category: _selectedCategory,
        year: int.tryParse(_yearController.text) ?? DateTime.now().year,
        semester: Semester.summer, // Defaulting to summer for now
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        status: ProjectStatus.pending,
        githubUrl: _githubController.text.trim().isNotEmpty ? _githubController.text.trim() : null,
        imageUrls: _selectedImagePaths,
        pdfUrl: _selectedPdfPath,
        projectType: _selectedProjectType,
        isGroupProject: _isGroupProject,
        groupName: _isGroupProject ? _groupNameController.text.trim() : null,
        teamMembers: teamMembers,
        driveLink: _driveLinkController.text.trim().isNotEmpty ? _driveLinkController.text.trim() : null,
        studentId: !_isGroupProject ? _studentIdController.text.trim() : null,
        batch: !_isGroupProject ? int.tryParse(_batchController.text) : null,
        level: !_isGroupProject ? int.tryParse(_levelController.text) : null,
        term: !_isGroupProject ? int.tryParse(_termController.text) : null,
      );

      final success = await widget.projectService.createProject(project);
      
      setState(() => _isSubmitting = false);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Project submitted successfully!')),
        );
        _clearForm();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to submit project. Please try again.')),
        );
      }
    }
  }

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
    for (var controllers in _teamMemberControllers) {
      controllers.values.forEach((c) => c.clear());
    }
    setState(() {
      _selectedCategory = ProjectCategory.other;
      _selectedImagePaths.clear();
      _selectedPdfPath = null;
      _isGroupProject = false;
      _numberOfMembers = 2;
      _initializeTeamMembers();
    });
  }

  Future<void> _pickImages() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.image,
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
    return AnimatedBuilder(
      animation: widget.authService,
      builder: (context, child) {
        if (!widget.authService.isAuthenticated) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Icon(Icons.lock, size: 64),
                const SizedBox(height: 16),
                const Text('Please log in to upload projects'),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.pushNamed(context, '/auth'),
                  child: const Text('Login'),
                ),
              ],
            ),
          );
        }

        // Check if user can upload projects (only students)
        if (!widget.authService.canUploadProjects()) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Icon(Icons.block, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  widget.authService.isTeacher 
                    ? 'Teachers cannot upload projects'
                    : 'Only students can upload projects',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.authService.isTeacher
                    ? 'Teachers can review, rate, and provide feedback on student projects.'
                    : 'Please log in as a student to upload projects.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                if (widget.authService.isTeacher)
                  FilledButton(
                    onPressed: () => Navigator.pushNamed(context, '/teacher'),
                    child: const Text('Go to Teacher Dashboard'),
                  )
                else
                  FilledButton(
                    onPressed: () => Navigator.pushNamed(context, '/auth'),
                    child: const Text('Login as Student'),
                  ),
              ],
            ),
          );
        }

    return Padding(
      padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
                const _SectionTitle('Upload Project'),
          const SizedBox(height: 12),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a title';
                    }
                    return null;
                  },
                ),
          const SizedBox(height: 12),
                TextFormField(
                  controller: _abstractController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Abstract'),
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
          const SizedBox(height: 12),
                DropdownButtonFormField<ProjectCategory>(
            decoration: const InputDecoration(labelText: 'Category'),
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
                const SizedBox(height: 12),
                TextFormField(
                  controller: _yearController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Year'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a year';
                    }
                    final year = int.tryParse(value);
                    if (year == null || year < 2000 || year > DateTime.now().year + 1) {
                      return 'Please enter a valid year';
                    }
                    return null;
                  },
          ),
          const SizedBox(height: 12),
                TextFormField(
                  controller: _githubController,
                  decoration: const InputDecoration(labelText: 'GitHub URL (optional)'),
                ),
          const SizedBox(height: 16),
          
                // Project Type Selection
                DropdownButtonFormField<ProjectType>(
                  decoration: const InputDecoration(labelText: 'Project Type'),
                  value: _selectedProjectType,
                  items: ProjectType.values.map((type) => DropdownMenuItem(
                    value: type,
                    child: Text(type.displayName),
                  )).toList(),
                  onChanged: (ProjectType? value) {
                    if (value != null) {
                      setState(() => _selectedProjectType = value);
                    }
                  },
                ),
                const SizedBox(height: 24),
                
                // Team Configuration Section
                const _SectionTitle('Team Configuration'),
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
                            setState(() => _isGroupProject = value);
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
                            items: List.generate(9, (index) => index + 2).map((count) => DropdownMenuItem(
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
                const _SectionTitle('Additional Resources'),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _driveLinkController,
                  decoration: const InputDecoration(
                    labelText: 'Google Drive Link (optional)',
                    hintText: 'Link to screenshots, additional PDFs, or posters',
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
                // File upload section
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Attachments',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: OutlinedButton.icon(
                  onPressed: _pickPdf,
                                icon: Icon(
                                  _selectedPdfPath == null ? Icons.picture_as_pdf_outlined : Icons.check_circle,
                                  color: _selectedPdfPath == null ? null : Colors.green,
                                ),
                                label: Text(_selectedPdfPath == null ? 'Attach PDF' : 'PDF Selected'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _selectedPdfPath == null ? null : Colors.green,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                  onPressed: _pickImages,
                                icon: Icon(
                                  _selectedImagePaths.isEmpty ? Icons.image_outlined : Icons.check_circle,
                                  color: _selectedImagePaths.isEmpty ? null : Colors.green,
                                ),
                                label: Text(_selectedImagePaths.isEmpty ? 'Add Images' : '${_selectedImagePaths.length} Images'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _selectedImagePaths.isEmpty ? null : Colors.green,
                                ),
                              ),
                            ),
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
          const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isSubmitting ? null : _submitProject,
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Submit for Review'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key, required this.projectService});
  final ProjectService projectService;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: projectService,
      builder: (context, child) {
        if (projectService.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final topProjects = projectService.trendingProjects.take(10).toList();
        
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemBuilder: (BuildContext context, int index) {
            final project = topProjects[index];
        return ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: Text(
                  '#${index + 1}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(project.title),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('${project.category.displayName} • ${project.year}'),
                  Row(
                    children: <Widget>[
                      const Icon(Icons.star, size: 16, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text('${project.rating.toStringAsFixed(1)} (${project.reviewCount} reviews)'),
                    ],
                  ),
                ],
              ),
          trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => ProjectDetailScreen(
                  project: project, 
                  projectService: projectService,
                  authService: AuthService(),
                ),
              )),
        );
      },
      separatorBuilder: (_, __) => const Divider(height: 1),
          itemCount: topProjects.length,
        );
      },
    );
  }
}

class BookmarksScreen extends StatelessWidget {
  const BookmarksScreen({super.key, required this.projectService});
  final ProjectService projectService;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: projectService,
      builder: (context, child) {
        if (projectService.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final bookmarkedProjects = projectService.bookmarkedProjects;
        
        if (bookmarkedProjects.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(Icons.bookmark_border, size: 64),
                SizedBox(height: 16),
                Text('No bookmarked projects yet'),
                SizedBox(height: 8),
                Text('Tap the bookmark icon on any project to save it here'),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemBuilder: (BuildContext context, int index) {
            final project = bookmarkedProjects[index];
            return _ProjectCard(
              project: project,
              projectService: projectService,
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => ProjectDetailScreen(
                  project: project, 
                  projectService: projectService,
                  authService: AuthService(),
                ),
              )),
            );
          },
          itemCount: bookmarkedProjects.length,
        );
      },
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.authService, required this.projectService});
  final AuthService authService;
  final ProjectService projectService;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: authService,
      builder: (context, child) {
        if (!authService.isAuthenticated) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Icon(Icons.person_outline, size: 64),
                const SizedBox(height: 16),
                const Text('Please log in to view your profile'),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.pushNamed(context, '/auth'),
                  child: const Text('Login'),
                ),
              ],
            ),
          );
        }

        final user = authService.currentUser!;
        final userProjects = projectService.projects
            .where((p) => p.authorId == user.id)
            .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: Text(
                  user.name[0].toUpperCase(),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(user.name),
              subtitle: Text('${user.role.displayName} • ${user.email}'),
              trailing: TextButton(
                onPressed: () {
                  // In a real app, navigate to edit profile
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Edit profile feature coming soon!')),
                  );
                },
                child: const Text('Edit'),
              ),
        ),
        const SizedBox(height: 16),
            const _SectionTitle('Statistics'),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: _StatCard(
                    icon: Icons.upload_file,
                    label: 'Projects',
                    value: userProjects.length.toString(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.bookmark,
                    label: 'Bookmarks',
                    value: projectService.bookmarkedProjectIds.length.toString(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.star,
                    label: 'Avg Rating',
                    value: userProjects.isNotEmpty
                        ? (userProjects.map((p) => p.rating).reduce((a, b) => a + b) / userProjects.length)
                            .toStringAsFixed(1)
                        : '0.0',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const _SectionTitle('My Projects'),
            const SizedBox(height: 8),
            if (userProjects.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    children: <Widget>[
                      Icon(Icons.upload_file, size: 48),
                      SizedBox(height: 8),
                      Text('No projects uploaded yet'),
                    ],
                  ),
                ),
              )
            else
              ...userProjects.map((project) => _ProjectCard(
                project: project,
                projectService: projectService,
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => ProjectDetailScreen(
                  project: project, 
                  projectService: projectService,
                  authService: AuthService(),
                ),
                )),
              )),
            const SizedBox(height: 24),
        const _SectionTitle('Quick Actions'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
              children: <Widget>[
                _QuickAction(
                  icon: Icons.upload_file,
                  label: 'Upload Project',
                  onTap: () {
                    // Switch to upload tab
                    DefaultTabController.of(context)?.animateTo(1);
                  },
                ),
                _QuickAction(
                  icon: Icons.settings,
                  label: 'Settings',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Settings feature coming soon!')),
                    );
                  },
                ),
                _QuickAction(
                  icon: Icons.logout,
                  label: 'Logout',
                  onTap: () => authService.logout(),
                ),
          ],
        ),
      ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        children: <Widget>[
          Icon(icon, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({
    required this.project,
    required this.projectService,
    this.onTap,
  });
  final Project project;
  final ProjectService projectService;
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
          children: <Widget>[
              // Header with title and status
            Row(
              children: <Widget>[
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
                    child: Text(
                      project.status.displayName,
                      style: TextStyle(
                        color: _getStatusColor(project.status),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
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
                children: <Widget>[
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
                  if (project.facultyName != null && project.facultyName!.isNotEmpty)
                    Chip(
                      label: Text(
                        project.status == ProjectStatus.approved
                            ? 'Approved by: ${project.facultyName}'
                            : 'Supervisor: ${project.facultyName}',
                      ),
                      backgroundColor: scheme.tertiaryContainer,
                      labelStyle: TextStyle(color: scheme.onTertiaryContainer),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Footer with rating, author, and actions
              Row(
                children: <Widget>[
                  // Rating
                  Row(
                    children: <Widget>[
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
          children: <Widget>[
            IconButton(
                        icon: Icon(
                          isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                          color: isBookmarked ? scheme.primary : scheme.onSurface.withOpacity(0.6),
                        ),
              onPressed: () => projectService.toggleBookmark(project.id),
                        tooltip: isBookmarked ? 'Remove bookmark' : 'Add bookmark',
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

class _PlaceholderCard extends StatelessWidget {
  const _PlaceholderCard(this.title, {this.onTap});
  final String title;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        title: Text(title),
        subtitle: const Text('Tap to view details'),
        trailing: Icon(Icons.chevron_right, color: scheme.primary),
        onTap: onTap,
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
      width: 140,
      height: 80,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(icon),
          const SizedBox(height: 6),
          Text(label),
        ],
        ),
      ),
    );
  }
}

class _WelcomeScreen extends StatelessWidget {
  const _WelcomeScreen({required this.onGetStarted});
  final VoidCallback onGetStarted;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              scheme.primary.withOpacity(0.1),
              scheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: <Widget>[
                const Spacer(),
                
                // Logo and Title
                Image.asset(
                  'asset/project.png',
                  height: 120,
                  width: 120,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 24),
                
                Text(
                  'projectshow',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: scheme.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                
                Text(
                  'Discover, Share, and Collaborate on Academic Projects',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurface.withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                
                // Features
                Column(
                  children: <Widget>[
                    _FeatureItem(
                      icon: Icons.explore,
                      title: 'Explore Projects',
                      description: 'Browse through innovative projects and research',
                    ),
                    const SizedBox(height: 16),
                    _FeatureItem(
                      icon: Icons.upload,
                      title: 'Share Your Work',
                      description: 'Upload and showcase your academic projects',
                    ),
                    const SizedBox(height: 16),
                    _FeatureItem(
                      icon: Icons.rate_review,
                      title: 'Get Feedback',
                      description: 'Receive reviews and ratings from peers',
                    ),
                  ],
                ),
                
                const Spacer(),
                
                // Get Started Button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onGetStarted,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'Get Started',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/auth'),
                  child: const Text('Already have an account? Sign In'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.description,
  });
  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    
    return Row(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: scheme.onPrimaryContainer,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
