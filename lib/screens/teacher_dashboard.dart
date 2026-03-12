import 'package:flutter/material.dart';
import '../mvc/models/project.dart';
import '../mvc/models/user.dart';
import '../mvc/models/feedback.dart' as feedback_models;
import '../mvc/controllers/project_service.dart';
import '../mvc/controllers/auth_service.dart';
import 'project_detail.dart';
import 'semester_archive_new.dart';
import 'semester_analytics_screen.dart';
import 'profile_settings_screen.dart';
import '../mvc/controllers/notification_service.dart';
import 'notifications_screen.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../utils/responsive_layout.dart';
import '../widgets/web_notification_panel.dart';
import '../services/announcement_service.dart';
import '../models/announcement.dart';
import 'package:intl/intl.dart';
import '../widgets/announcement_carousel.dart';
import '../services/system_service.dart';

class TeacherDashboardScreen extends StatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  final ProjectService _projectService = ProjectService();
  final AuthService _authService = AuthService();
  final NotificationService _notificationService = NotificationService();
  final AnnouncementService _announcementService = AnnouncementService();
  int _selectedIndex = 0;
  DateTime? _lastPressedAt;

  @override
  void initState() {
    super.initState();
    _projectService.reloadProjects();
    _authService.addListener(_onAuthChanged);
    _onAuthChanged();
    _loadNotifications();
    _announcementService.loadAnnouncements();
  }

  void _loadNotifications() {
    final user = _authService.currentUser;
    if (user != null) {
      _notificationService.startListening(user.id);
    }
  }

  @override
  void dispose() {
    _authService.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    final user = _authService.currentUser;
    if (user != null) {
      _projectService.loadReviewsForUser(user.id);
    }
    if (mounted) setState(() {});
  }

  @override

  Widget build(BuildContext context) {
    return PopScope(
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
      child: ResponsiveDashboardLayout(
        title: const Text('Teacher Dashboard'),
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int index) => setState(() => _selectedIndex = index),
        userEmail: _authService.currentUser?.email,
        userRole: _authService.currentUser?.role.displayName,
        onLogout: () async {
          await _authService.logout();
          if (mounted) {
            Navigator.of(context).pushNamedAndRemoveUntil('/auth', (route) => false);
          }
        },
        actions: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = MediaQuery.of(context).size.width >= 900;
              if (isDesktop) {
                return WebNotificationPanel(
                  notificationService: _notificationService,
                  onViewAll: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                    );
                  },
                );
              } else {
                return AnimatedBuilder(
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
                );
              }
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
                    Text(_authService.currentUser?.name ?? 'Teacher'),
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
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.rate_review_outlined),
            selectedIcon: Icon(Icons.rate_review),
            label: 'Review',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder),
            label: 'All Projects',
          ),
          NavigationDestination(
            icon: Icon(Icons.checklist_rtl_outlined),
            selectedIcon: Icon(Icons.checklist_rtl),
            label: 'Distributed',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics),
            label: 'Analytics',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu),
            selectedIcon: Icon(Icons.menu_open),
            label: 'More',
          ),
        ],
        body: AnimatedBuilder(
          animation: Listenable.merge([_projectService, _authService]),
          builder: (context, child) {
              return Stack(
                children: [
                  IndexedStack(
                    index: _selectedIndex,
                    children: [
                      _ReviewTab(
                        projectService: _projectService, 
                        authService: _authService,
                        announcementService: _announcementService,
                      ),
                      _AllProjectsTab(projectService: _projectService, authService: _authService),
                      _DistributedProjectsTab(projectService: _projectService, authService: _authService),
                      _AnalyticsTab(projectService: _projectService, authService: _authService),
                      _TeacherMoreTab(projectService: _projectService, authService: _authService),
                    ],
                  ),
                  if (_projectService.isLoading)
                    Container(
                      color: Colors.black.withOpacity(0.1),
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                ],
              );
          },
        ),
      ),
    );
  }
}

class _ReviewTab extends StatefulWidget {
  const _ReviewTab({
    required this.projectService, 
    required this.authService,
    required this.announcementService,
  });
  final ProjectService projectService;
  final AuthService authService;
  final AnnouncementService announcementService;

  @override
  State<_ReviewTab> createState() => _ReviewTabState();
}

class _ReviewTabState extends State<_ReviewTab> {
  late Stream<List<Announcement>> _announcementStream;

  @override
  void initState() {
    super.initState();
    _announcementStream = widget.announcementService.getActiveAnnouncementsStream();
    // Listen to project service changes
    widget.projectService.addListener(_onProjectServiceChanged);
  }

  @override
  void dispose() {
    widget.projectService.removeListener(_onProjectServiceChanged);
    super.dispose();
  }

  void _onProjectServiceChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentTeacher = widget.authService.currentUser;
    // Pending projects: Only show to assigned teacher
    final pendingProjects = widget.projectService
        .filterProjectsByStatus(ProjectStatus.pending)
        .where((project) => _isPendingProjectVisibleToTeacher(project, currentTeacher))
        .toList();
    // Approved projects: Show to all teachers (they can review)
    final approvedProjects = widget.projectService
        .filterProjectsByStatus(ProjectStatus.approved)
        .toList();
    
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Announcements Section
        StreamBuilder<List<Announcement>>(
          stream: _announcementStream,
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox.shrink();
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: AnnouncementCarousel(announcements: snapshot.data!),
            );
          },
        ),

        // Header
        Card(
          color: Theme.of(context).colorScheme.secondaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(
                  Icons.rate_review,
                  size: 48,
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                ),
                const SizedBox(height: 12),
                Text(
                  'Review & Rate Projects',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Help students improve by providing constructive feedback',
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

        // Statistics Cards
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.pending_actions,
                label: 'Pending Review',
                value: pendingProjects.length.toString(),
                color: Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.check_circle,
                label: 'Reviewed',
                value: approvedProjects.length.toString(),
                color: Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Pending Reviews
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Pending Reviews',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            IconButton(
              onPressed: () async {
                await widget.projectService.ensureProjectsLoaded();
              },
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh Projects',
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (pendingProjects.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.check_circle_outline, size: 48, color: Colors.grey),
                    SizedBox(height: 8),
                    Text('No pending reviews'),
                    SizedBox(height: 4),
                    Text('All projects have been reviewed'),
                  ],
                ),
              ),
            ),
          )
        else
          ...pendingProjects.take(5).map((project) => _ProjectReviewCard(
            project: project,
            projectService: widget.projectService,
            authService: widget.authService,
            onTap: () => _openProjectDetail(context, project),
          )),

        const SizedBox(height: 24),

        // Recently Reviewed
        Text(
          'Recently Reviewed',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (approvedProjects.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.rate_review, size: 48, color: Colors.grey),
                    SizedBox(height: 8),
                    Text('No reviews yet'),
                    SizedBox(height: 4),
                    Text('Start reviewing projects to see them here'),
                  ],
                ),
              ),
            ),
          )
        else
          ...approvedProjects.take(3).map((project) => _ProjectReviewCard(
            project: project,
            projectService: widget.projectService,
            authService: widget.authService,
            onTap: () => _openProjectDetail(context, project),
            showReviewActions: false,
          )),

        const SizedBox(height: 24),

        // Featured Projects
        Text(
          'Featured Projects',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (widget.projectService.featuredProjects.isEmpty)
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
          ...widget.projectService.featuredProjects.take(3).map((project) => _ProjectReviewCard(
            project: project,
            projectService: widget.projectService,
            authService: widget.authService,
            onTap: () => _openProjectDetail(context, project),
            showReviewActions: false,
          )),
      ],
        ),
      ),
    );
  }

  void _openProjectDetail(BuildContext context, Project project) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProjectDetailScreen(
          project: project,
          projectService: widget.projectService,
          authService: widget.authService,
        ),
      ),
    );
  }


}

class _AllProjectsTab extends StatefulWidget {
  const _AllProjectsTab({required this.projectService, required this.authService});
  final ProjectService projectService;
  final AuthService authService;

  @override
  State<_AllProjectsTab> createState() => _AllProjectsTabState();
}

class _AllProjectsTabState extends State<_AllProjectsTab> {
  String _selectedFilter = 'All'; // 'All', 'Pending', 'Approved', 'Featured'
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final teacher = widget.authService.currentUser;
    final allProjects = widget.projectService.projects
        .where((project) => _isProjectVisibleToTeacher(project, teacher))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Filter projects based on selected filter and search query
    final filteredProjects = allProjects.where((project) {
      // Status filter
      final matchesStatus = _selectedFilter == 'All'
          ? true
          : _selectedFilter == 'Pending'
              ? project.status == ProjectStatus.pending
              : _selectedFilter == 'Approved'
                  ? project.status == ProjectStatus.approved
                  : _selectedFilter == 'Featured'
                      ? (project.isFeatured || project.status == ProjectStatus.featured)
                      : true;

      // Search filter
      final matchesSearch = _searchQuery.isEmpty ||
          project.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          project.authorName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (project.studentId?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);

      return matchesStatus && matchesSearch;
    }).toList();

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: ListView(
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
                  Icons.folder,
                  size: 48,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
                const SizedBox(height: 12),
                Text(
                  'All Student Projects',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${filteredProjects.length} project${filteredProjects.length == 1 ? '' : 's'} found',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Search Bar
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search by title, student name, or ID',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            filled: true,
            fillColor: Theme.of(context).cardColor,
          ),
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
        ),
        const SizedBox(height: 16),

        // Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              FilterChip(
                label: const Text('All'),
                selected: _selectedFilter == 'All',
                onSelected: (bool selected) {
                  if (selected) {
                    setState(() => _selectedFilter = 'All');
                  }
                },
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Pending'),
                selected: _selectedFilter == 'Pending',
                onSelected: (bool selected) {
                  if (selected) {
                    setState(() => _selectedFilter = 'Pending');
                  }
                },
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Approved'),
                selected: _selectedFilter == 'Approved',
                onSelected: (bool selected) {
                  if (selected) {
                    setState(() => _selectedFilter = 'Approved');
                  }
                },
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Featured'),
                selected: _selectedFilter == 'Featured',
                onSelected: (bool selected) {
                  if (selected) {
                    setState(() => _selectedFilter = 'Featured');
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Projects List
        if (filteredProjects.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      _searchQuery.isNotEmpty ? Icons.search_off : Icons.folder_open,
                      size: 48, 
                      color: Colors.grey
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _searchQuery.isNotEmpty 
                        ? 'No results found for "$_searchQuery"'
                        : 'No ${_selectedFilter.toLowerCase()} projects'
                    ),
                    const SizedBox(height: 4),
                    Text(
                        _searchQuery.isNotEmpty
                          ? 'Try different keywords'
                          : _selectedFilter == 'All' 
                            ? 'Students haven\'t uploaded any projects yet'
                            : 'No projects with ${_selectedFilter.toLowerCase()} status'
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          ...filteredProjects.map((project) => _ProjectReviewCard(
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
        ),
      ),
    );
  }
}

class _MyReviewsTab extends StatelessWidget {
  const _MyReviewsTab({required this.projectService, required this.authService});
  final ProjectService projectService;
  final AuthService authService;

  @override
  Widget build(BuildContext context) {
    final user = authService.currentUser;
    if (user == null) return const Center(child: Text('Please log in'));

    final myReviews = projectService.reviews
        .where((review) => review.reviewerId == user.id)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: ListView(
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
                  Icons.comment,
                  size: 48,
                  color: Theme.of(context).colorScheme.onTertiaryContainer,
                ),
                const SizedBox(height: 12),
                Text(
                  'My Reviews',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onTertiaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${myReviews.length} review${myReviews.length == 1 ? '' : 's'} written',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onTertiaryContainer.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Reviews List
        if (myReviews.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.comment_outlined, size: 48, color: Colors.grey),
                    SizedBox(height: 8),
                    Text('No reviews written yet'),
                    SizedBox(height: 4),
                    Text('Start reviewing projects to see them here'),
                  ],
                ),
              ),
            ),
          )
        else
          ...myReviews.map((review) {
            final project = projectService.projects.firstWhere(
              (p) => p.id == review.projectId,
              orElse: () => Project(
                id: '',
                title: 'Project not found',
                abstract: '',
                authorId: '',
                authorName: 'Unknown',
                category: ProjectCategory.other,
                year: DateTime.now().year,
                semester: Semester.summer,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
                status: ProjectStatus.draft,
              ),
            );
            return _ReviewCard(
              review: review,
              project: project,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ProjectDetailScreen(
                    project: project,
                    projectService: projectService,
                    authService: authService,
                  ),
                ),
              ),
            );
          }),
      ],
        ),
      ),
    );
  }
}

class _AnalyticsTab extends StatelessWidget {
  const _AnalyticsTab({required this.projectService, required this.authService});
  final ProjectService projectService;
  final AuthService authService;

  @override
  Widget build(BuildContext context) {
    // Reuse the same semester analytics screen used by admin
    return SemesterAnalyticsBody(projectService: projectService);
  }
}

class _ProjectReviewCard extends StatelessWidget {
  const _ProjectReviewCard({
    required this.project,
    required this.projectService,
    required this.authService,
    this.onTap,
    this.showReviewActions = true,
  });
  final Project project;
  final ProjectService projectService;
  final AuthService authService;
  final VoidCallback? onTap;
  final bool showReviewActions;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    
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
              if (project.facultyName != null)
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
                    'Supervisor: ${project.facultyName}',
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              
              // Author info
              Text(
                'By ${project.isGroupProject ? project.authorName : ((project.studentName != null && project.studentName!.isNotEmpty) ? project.studentName! : project.authorName)}' + 
                (project.level != null && project.term != null ? ' • L${project.level} T${project.term}' : ''),
                style: TextStyle(
                  color: scheme.onSurface.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              
              // Footer with rating and actions
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                      const Spacer(),
                      Icon(
                        Icons.chevron_right,
                        color: scheme.primary,
                      ),
                    ],
                  ),
                  if (showReviewActions && project.status == ProjectStatus.pending)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          TextButton.icon(
                            onPressed: () => _approveProject(context, project),
                            icon: const Icon(Icons.check_circle, color: Colors.green),
                            label: const Text('Approve'),
                          ),
                          if (authService.currentUser?.id == SystemService().primaryTeacherId)
                            TextButton.icon(
                              onPressed: () => _showDistributionDialog(context, project),
                              icon: const Icon(Icons.share, color: Colors.blue),
                              label: const Text('Distribute'),
                            ),
                          TextButton.icon(
                            onPressed: () => _giveFeedback(context, project),
                            icon: const Icon(Icons.feedback, color: Colors.orange),
                            label: const Text('Feedback'),
                          ),
                          TextButton.icon(
                            onPressed: () => _rejectProject(context, project),
                            icon: const Icon(Icons.cancel, color: Colors.red),
                            label: const Text('Reject'),
                          ),
                        ],
                      ),
                    )
                  else if (showReviewActions)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          TextButton.icon(
                            onPressed: () => _rateProject(context, project),
                            icon: const Icon(Icons.star_rate, color: Colors.amber),
                            label: const Text('Rate'),
                          ),
                          TextButton.icon(
                            onPressed: () => _commentProject(context, project),
                            icon: const Icon(Icons.comment, color: Colors.blue),
                            label: const Text('Comment'),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _approveProject(BuildContext context, Project project) async {
    final updatedProject = project.copyWith(status: ProjectStatus.approved);
    final teacher = authService.currentUser;
    final success = await projectService.updateProject(
      updatedProject,
      approverId: teacher?.id,
      approverName: teacher?.name,
    );
    
    if (success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${project.title} approved')),
      );
    }
  }

  void _rejectProject(BuildContext context, Project project) {
    showDialog(
      context: context,
      builder: (context) => _RejectionDialog(
        project: project,
        projectService: projectService,
        authService: authService,
      ),
    );
  }

  void _giveFeedback(BuildContext context, Project project) {
    showDialog(
      context: context,
      builder: (context) => _FeedbackDialog(
        project: project,
        projectService: projectService,
        authService: authService,
      ),
    );
  }

  void _rateProject(BuildContext context, Project project) {
    // Navigate to project detail for rating
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProjectDetailScreen(
          project: project,
          projectService: projectService,
          authService: authService,
        ),
      ),
    );
  }

  void _commentProject(BuildContext context, Project project) async {
    // Navigate to project detail for commenting
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProjectDetailScreen(
          project: project,
          projectService: projectService,
          authService: authService,
        ),
      ),
    );
  }

  void _showDistributionDialog(BuildContext context, Project project) {
    showDialog(
      context: context,
      builder: (context) => _DistributionDialog(
        project: project,
        authService: authService,
        projectService: projectService,
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

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.review,
    required this.project,
    this.onTap,
  });
  final dynamic review; // Assuming Review model exists
  final Project project;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      project.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Row(
                    children: List.generate(5, (index) {
                      return Icon(
                        index < (review.rating ?? 0) ? Icons.star : Icons.star_border,
                        size: 16,
                        color: Colors.amber,
                      );
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                review.comment ?? 'No comment provided',
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                'Reviewed on ${review.createdAt.day}/${review.createdAt.month}/${review.createdAt.year}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Check if a pending project is visible to a teacher (only assigned teacher can see pending)
bool _isPendingProjectVisibleToTeacher(Project project, User? teacher) {
  if (teacher == null) return false;
  
  // If project is distributed to an assistant, hide it from the primary teacher's pending list
  if (project.facultyId == teacher.id && project.assistantTeacherId != null) {
    return false;
  }
  
  // Visible if assigned as primary OR assistant
  return project.facultyId == teacher.id || project.assistantTeacherId == teacher.id;
}

// Check if a project is visible to a teacher (for general visibility checks)
bool _isProjectVisibleToTeacher(Project project, User? teacher) {
  if (teacher == null) return false;
  
  // Faculty sees their own assigned projects (Primary or Assistant)
  if (project.facultyId == teacher.id || project.assistantTeacherId == teacher.id) return true;
  
  // Approved projects: visible to all teachers (they can review)
  if (project.status == ProjectStatus.approved || 
      project.status == ProjectStatus.featured) {
    return true;
  }
  
  // Pending projects: only visible to assigned teacher
  if (project.status == ProjectStatus.pending) {
    return _isPendingProjectVisibleToTeacher(project, teacher);
  }
  
  // Other statuses: only visible to assigned teacher
  if ((project.facultyId == null || project.facultyId!.isEmpty) && 
      (project.assistantTeacherId == null || project.assistantTeacherId!.isEmpty)) return false;
  
  return project.facultyId == teacher.id || project.assistantTeacherId == teacher.id;
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _AnalyticsCard extends StatelessWidget {
  const _AnalyticsCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedbackDialog extends StatefulWidget {
  const _FeedbackDialog({
    required this.project,
    required this.projectService,
    required this.authService,
  });

  final Project project;
  final ProjectService projectService;
  final AuthService authService;

  @override
  State<_FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<_FeedbackDialog> {
  final _commentController = TextEditingController();
  int _selectedType = 0;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Give Feedback - ${widget.project.title}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Feedback Type',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: feedback_models.FeedbackType.values.asMap().entries.map((entry) {
                final type = entry.value;
                final index = entry.key;
                return ChoiceChip(
                  label: Text('${type.icon} ${type.displayName}'),
                  selected: _selectedType == index,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedType = index);
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _commentController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Feedback Comment',
                hintText: 'Provide detailed feedback for the student...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submitFeedback,
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Submit Feedback'),
        ),
      ],
    );
  }

  Future<void> _submitFeedback() async {
    if (_commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter feedback comment')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final user = widget.authService.currentUser;
    if (user == null) return;

    // Create feedback object
    final feedback = feedback_models.ProjectFeedback(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      projectId: widget.project.id,
      reviewerId: user.id,
      reviewerName: user.name,
      comment: _commentController.text.trim(),
      type: feedback_models.FeedbackType.values[_selectedType],
      createdAt: DateTime.now(),
    );

    // Save feedback to dedicated collection
    final success = await widget.projectService.addFeedback(
      widget.project.id,
      _commentController.text.trim(),
      feedback_models.FeedbackType.values[_selectedType],
    );
    
    if (success && mounted) {
      // Create updated feedback list
      final updatedFeedbackList = List<feedback_models.ProjectFeedback>.from(widget.project.feedback)
        ..add(feedback);

      // Update project status to needs revision AND update the feedback list in the project document
      final updatedProject = widget.project.copyWith(
        status: ProjectStatus.needsRevision,
        feedback: updatedFeedbackList,
      );
      
      await widget.projectService.updateProject(
        updatedProject,
        approverId: user.id,
        approverName: user.name,
      );
      
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Feedback submitted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to submit feedback'),
          backgroundColor: Colors.red,
        ),
      );
    }

    setState(() => _isSubmitting = false);
  }
}

class _RejectionDialog extends StatefulWidget {
  const _RejectionDialog({
    required this.project,
    required this.projectService,
    required this.authService,
  });

  final Project project;
  final ProjectService projectService;
  final AuthService authService;

  @override
  State<_RejectionDialog> createState() => _RejectionDialogState();
}

class _RejectionDialogState extends State<_RejectionDialog> {
  final _reasonController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.cancel, color: Colors.red, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Reject Project',
              style: TextStyle(color: Colors.red[700]),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Project: ${widget.project.title}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Rejection Reason (Required)',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _reasonController,
              maxLines: 4,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Please provide a clear reason for rejection...',
                border: const OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.red.withOpacity(0.3)),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.red, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'The student will be notified with this reason.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange[900],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _isSubmitting ? null : _submitRejection,
          icon: const Icon(Icons.cancel),
          label: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Reject Project'),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Future<void> _submitRejection() async {
    final reason = _reasonController.text.trim();
    
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide a rejection reason'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final teacher = widget.authService.currentUser;
    if (teacher == null) return;

    final updatedProject = widget.project.copyWith(
      status: ProjectStatus.rejected,
      rejectionReason: reason,
    );
    
    final success = await widget.projectService.updateProject(
      updatedProject,
      approverId: teacher.id,
      approverName: teacher.name,
    );
    
    setState(() => _isSubmitting = false);

    if (success && mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.project.title} rejected'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class _DistributionDialog extends StatefulWidget {
  const _DistributionDialog({
    required this.project,
    required this.authService,
    required this.projectService,
  });

  final Project project;
  final AuthService authService;
  final ProjectService projectService;

  @override
  State<_DistributionDialog> createState() => _DistributionDialogState();
}

class _DistributionDialogState extends State<_DistributionDialog> {
  List<User> _teachers = [];
  bool _isLoading = true;
  String? _selectedTeacherId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedTeacherId = widget.project.assistantTeacherId;
    _loadTeachers();
  }

  Future<void> _loadTeachers() async {
    try {
      final teachers = await widget.authService.getUsersByRole(UserRole.teacher);
      if (mounted) {
        setState(() {
          _teachers = teachers.where((t) => 
            t.isApproved && 
            t.isActive && 
            t.id != widget.authService.currentUser?.id
          ).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Distribute Project'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SizedBox(
          width: double.maxFinite,
          child: _isLoading 
            ? const Center(child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ))
            : _teachers.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No other approved teachers found'),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: _teachers.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final teacher = _teachers[index];
                    final isSelected = teacher.id == _selectedTeacherId;
                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      title: Text(teacher.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(teacher.designation?.displayName ?? 'Teacher', style: const TextStyle(fontSize: 12)),
                      trailing: isSelected 
                        ? const Icon(Icons.check_circle, color: Colors.blue, size: 20) 
                        : const Icon(Icons.circle_outlined, size: 20, color: Colors.grey),
                      onTap: () {
                        setState(() {
                          _selectedTeacherId = teacher.id;
                        });
                      },
                    );
                  },
                ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: (_isSaving || _selectedTeacherId == null || _selectedTeacherId == widget.project.assistantTeacherId)
              ? null
              : () async {
                  setState(() => _isSaving = true);
                  final selectedTeacher = _teachers.firstWhere((t) => t.id == _selectedTeacherId);
                  final updatedProject = widget.project.copyWith(
                    assistantTeacherId: _selectedTeacherId,
                  );
                  final success = await widget.projectService.updateProject(updatedProject);
                  if (success && mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Distributed to ${selectedTeacher.name}'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  } else if (mounted) {
                    setState(() => _isSaving = false);
                  }
                },
          child: _isSaving 
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : const Text('Confirm'),
        ),
      ],
    );
  }
}

class _DistributedProjectsTab extends StatefulWidget {
  const _DistributedProjectsTab({
    super.key,
    required this.projectService,
    required this.authService,
  });

  final ProjectService projectService;
  final AuthService authService;

  @override
  State<_DistributedProjectsTab> createState() => _DistributedProjectsTabState();
}

class _DistributedProjectsTabState extends State<_DistributedProjectsTab> {
  Map<String, String> _teacherNames = {};
  bool _isLoadingNames = true;

  @override
  void initState() {
    super.initState();
    _loadTeacherNames();
  }

  Future<void> _loadTeacherNames() async {
    try {
      final teachers = await widget.authService.getUsersByRole(UserRole.teacher);
      if (mounted) {
        setState(() {
          _teacherNames = {for (var t in teachers) t.id: t.name};
          _isLoadingNames = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingNames = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final distributedProjects = widget.projectService.projects.where((p) => 
      p.facultyId == widget.authService.currentUser?.id && 
      p.assistantTeacherId != null
    ).toList();

    if (distributedProjects.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.analytics_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No projects distributed for review yet'),
          ],
        ),
      );
    }

    // Grouping logic
    final Map<String, List<Project>> projectsByTeacher = {};
    for (var project in distributedProjects) {
      final tid = project.assistantTeacherId!;
      projectsByTeacher.putIfAbsent(tid, () => []).add(project);
    }

    // Overall stats
    final totalAssigned = distributedProjects.length;
    final totalApproved = distributedProjects.where((p) => p.status == ProjectStatus.approved).length;
    final totalRejected = distributedProjects.where((p) => p.status == ProjectStatus.rejected).length;
    final totalPending = distributedProjects.where((p) => p.status == ProjectStatus.pending).length;
    final totalNeedsRevision = distributedProjects.where((p) => p.status == ProjectStatus.needsRevision).length;

    final ColorScheme scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Overall Summary Card
        Card(
          margin: const EdgeInsets.only(bottom: 24),
          color: scheme.primaryContainer.withOpacity(0.3),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: scheme.primary.withOpacity(0.2)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.dashboard_customize_outlined, color: scheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Overall Distribution Summary',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: scheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _TotalStatItem(label: 'Total', count: totalAssigned, icon: Icons.assignment_outlined),
                    _TotalStatItem(label: 'Pending', count: totalPending, icon: Icons.timer_outlined, color: Colors.orange),
                    _TotalStatItem(label: 'Approved', count: totalApproved, icon: Icons.check_circle_outline, color: Colors.green),
                    _TotalStatItem(label: 'Rejected', count: totalRejected, icon: Icons.cancel_outlined, color: Colors.red),
                    _TotalStatItem(label: 'Revision', count: totalNeedsRevision, icon: Icons.edit_note_outlined, color: Colors.blue),
                  ],
                ),
              ],
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            'Teacher-wise Analytics',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        ...projectsByTeacher.entries.map((entry) {
          final teacherId = entry.key;
          final projects = entry.value;
          final teacherName = _teacherNames[teacherId] ?? 'Loading...';
          
          final approved = projects.where((p) => p.status == ProjectStatus.approved).length;
          final rejected = projects.where((p) => p.status == ProjectStatus.rejected).length;
          final pending = projects.where((p) => p.status == ProjectStatus.pending).length;
          final needsRevision = projects.where((p) => p.status == ProjectStatus.needsRevision).length;

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: scheme.outlineVariant.withOpacity(0.5)),
            ),
            child: ExpansionTile(
              leading: CircleAvatar(
                backgroundColor: scheme.primaryContainer,
                child: Text(teacherName[0].toUpperCase(), style: TextStyle(color: scheme.onPrimaryContainer)),
              ),
              title: Text(teacherName, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${projects.length} Projects Assigned'),
              childrenPadding: const EdgeInsets.all(16),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _TeacherStatItem(label: 'Pending', count: pending, color: Colors.orange),
                    _TeacherStatItem(label: 'Approved', count: approved, color: Colors.green),
                    _TeacherStatItem(label: 'Rejected', count: rejected, color: Colors.red),
                    _TeacherStatItem(label: 'Revision', count: needsRevision, color: Colors.blue),
                  ],
                ),
                const Divider(height: 32),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Recent Assignments', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                ),
                const SizedBox(height: 8),
                ...projects.take(3).map((p) => ListTile(
                  dense: true,
                  title: Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('Status: ${p.status.displayName}'),
                  trailing: const Icon(Icons.chevron_right, size: 16),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => ProjectDetailScreen(
                        project: p,
                        projectService: widget.projectService,
                      )),
                    );
                  },
                )),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _TeacherStatItem extends StatelessWidget {
  const _TeacherStatItem({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: color.withOpacity(0.8),
          ),
        ),
      ],
    );
  }
}

class _TotalStatItem extends StatelessWidget {
  const _TotalStatItem({
    required this.label,
    required this.count,
    required this.icon,
    this.color,
  });

  final String label;
  final int count;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color ?? Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(height: 4),
        Text(
          count.toString(),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color?.withOpacity(0.8),
          ),
        ),
      ],
    );
  }
}

class _TeacherMoreTab extends StatelessWidget {
  const _TeacherMoreTab({required this.projectService, required this.authService});
  final ProjectService projectService;
  final AuthService authService;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ListTile(
          leading: const Icon(Icons.comment),
          title: const Text('My Reviews'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => Scaffold(
              appBar: AppBar(title: const Text('My Reviews')),
              body: _MyReviewsTab(projectService: projectService, authService: authService),
            )
          )),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.archive),
          title: const Text('Archives'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => const SemesterArchiveScreen(),
          )),
        ),
      ],
    );
  }
}
