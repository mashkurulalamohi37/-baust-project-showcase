import 'package:flutter/material.dart';
import '../mvc/models/project.dart';
import '../mvc/models/user.dart';
import '../mvc/models/feedback.dart' as feedback_models;
import '../mvc/controllers/project_service.dart';
import '../mvc/controllers/auth_service.dart';
import 'project_detail.dart';
import 'semester_archive_new.dart';
import 'profile_settings_screen.dart';
import '../mvc/controllers/notification_service.dart';
import 'notifications_screen.dart';

import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';

class TeacherDashboardScreen extends StatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  final ProjectService _projectService = ProjectService();
  final AuthService _authService = AuthService();
  final NotificationService _notificationService = NotificationService();
  int _selectedIndex = 0;
  DateTime? _lastPressedAt;

  @override
  void initState() {
    super.initState();
    _projectService.reloadProjects();
    _authService.addListener(_onAuthChanged);
    _onAuthChanged();
    _loadNotifications();
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
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Teacher Dashboard'),
        backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
        foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
        actions: [
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
      ),
      body: AnimatedBuilder(
        animation: Listenable.merge([_projectService, _authService]),
        builder: (context, child) {
          if (_projectService.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return IndexedStack(
            index: _selectedIndex,
            children: [
              _ReviewTab(projectService: _projectService, authService: _authService),
              _AllProjectsTab(projectService: _projectService, authService: _authService),
              _MyReviewsTab(projectService: _projectService, authService: _authService),
              _AnalyticsTab(projectService: _projectService, authService: _authService),
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
            icon: Icon(Icons.comment_outlined),
            selectedIcon: Icon(Icons.comment),
            label: 'My Reviews',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics),
            label: 'Analytics',
          ),
          NavigationDestination(
            icon: Icon(Icons.archive_outlined),
            selectedIcon: Icon(Icons.archive),
            label: 'Archives',
          ),
        ],
      ),
      ),
    );
  }
}

class _ReviewTab extends StatefulWidget {
  const _ReviewTab({required this.projectService, required this.authService});
  final ProjectService projectService;
  final AuthService authService;

  @override
  State<_ReviewTab> createState() => _ReviewTabState();
}

class _ReviewTabState extends State<_ReviewTab> {
  @override
  void initState() {
    super.initState();
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
    
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
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
    );
  }
}

class _AnalyticsTab extends StatelessWidget {
  const _AnalyticsTab({required this.projectService, required this.authService});
  final ProjectService projectService;
  final AuthService authService;

  @override
  Widget build(BuildContext context) {
    final teacher = authService.currentUser;
    final allProjects = projectService.projects
        .where((project) => _isProjectVisibleToTeacher(project, teacher))
        .toList();
    final projectsByStatus = <ProjectStatus, List<Project>>{};
    
    for (final status in ProjectStatus.values) {
      projectsByStatus[status] = projectService
          .filterProjectsByStatus(status)
          .where((project) => _isProjectVisibleToTeacher(project, teacher))
          .toList();
    }
    
    // Calculate featured projects count (projects with isFeatured flag or featured status)
    final featuredCount = allProjects.where((p) => p.isFeatured || p.status == ProjectStatus.featured).length;

    final totalReviews = projectService.reviews.length;
    final averageRating = allProjects.isNotEmpty
        ? allProjects.map((p) => p.rating).reduce((a, b) => a + b) / allProjects.length
        : 0.0;

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
                  Icons.analytics,
                  size: 48,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
                const SizedBox(height: 12),
                Text(
                  'Review Analytics',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Overview of project reviews and ratings',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.8),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Statistics Grid
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: [
            _AnalyticsCard(
              icon: Icons.folder,
              label: 'Total Projects',
              value: allProjects.length.toString(),
              color: Colors.blue,
            ),
            _AnalyticsCard(
              icon: Icons.pending_actions,
              label: 'Pending',
              value: projectsByStatus[ProjectStatus.pending]?.length.toString() ?? '0',
              color: Colors.orange,
            ),
            _AnalyticsCard(
              icon: Icons.check_circle,
              label: 'Approved',
              value: projectsByStatus[ProjectStatus.approved]?.length.toString() ?? '0',
              color: Colors.green,
            ),
            _AnalyticsCard(
              icon: Icons.star,
              label: 'Featured',
              value: featuredCount.toString(),
              color: Colors.purple,
            ),
            _AnalyticsCard(
              icon: Icons.rate_review,
              label: 'Total Reviews',
              value: totalReviews.toString(),
              color: Colors.teal,
            ),
            _AnalyticsCard(
              icon: Icons.star_rate,
              label: 'Avg Rating',
              value: averageRating.toStringAsFixed(1),
              color: Colors.amber,
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Category Distribution
        Text(
          'Projects by Category',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: ProjectCategory.values.map((category) {
                final count = allProjects.where((p) => p.category == category).length;
                final percentage = allProjects.isNotEmpty ? (count / allProjects.length * 100) : 0.0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(category.displayName),
                      ),
                      Text('$count (${percentage.toStringAsFixed(1)}%)'),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
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
                'By ${project.authorName}',
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

  void _commentProject(BuildContext context, Project project) {
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
  // If project has no assigned teacher, don't show to anyone (should be assigned first)
  if ((project.facultyId == null || project.facultyId!.isEmpty) && 
      (project.assistantTeacherId == null || project.assistantTeacherId!.isEmpty)) return false;
  // Only show to the assigned teacher or assistant teacher
  return project.facultyId == teacher.id || project.assistantTeacherId == teacher.id;
}

// Check if a project is visible to a teacher (for general visibility checks)
bool _isProjectVisibleToTeacher(Project project, User? teacher) {
  if (teacher == null) return false;
  
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

    final feedback = feedback_models.ProjectFeedback(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      projectId: widget.project.id,
      reviewerId: user.id,
      reviewerName: user.name,
      comment: _commentController.text.trim(),
      type: feedback_models.FeedbackType.values[_selectedType],
      createdAt: DateTime.now(),
    );

    final success = await widget.projectService.addFeedback(
      widget.project.id,
      _commentController.text.trim(),
      feedback_models.FeedbackType.values[_selectedType],
    );
    
    if (success && mounted) {
      // Update project status to needs revision
      final updatedProject = widget.project.copyWith(
        status: ProjectStatus.needsRevision,
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
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to reject project'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
