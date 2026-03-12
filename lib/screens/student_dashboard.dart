import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import '../mvc/models/project.dart';
import '../mvc/models/user.dart';
import '../mvc/controllers/project_service.dart';
import '../mvc/models/team_member.dart';
import '../mvc/controllers/auth_service.dart';
import 'project_detail.dart';
import 'project_form_screen.dart';
import '../widgets/project_form.dart';
import 'search_filter.dart';
import 'semester_archive_new.dart';
import 'profile_settings_screen.dart';
import '../mvc/controllers/notification_service.dart';
import 'notifications_screen.dart';
import '../utils/responsive_layout.dart';
import '../widgets/web_notification_panel.dart';
import '../services/announcement_service.dart';
import '../models/announcement.dart';
import 'package:intl/intl.dart';

import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;

import '../widgets/announcement_carousel.dart';

class StudentDashboardScreen extends StatefulWidget {
  const StudentDashboardScreen({super.key});

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
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
        child: ResponsiveDashboardLayout(
          title: const Text('Student Dashboard'),
          selectedIndex: _selectedIndex,
          onDestinationSelected: (int index) => setState(() => _selectedIndex = index),
          userEmail: _authService.currentUser?.email,
          userRole: _authService.currentUser?.role.name.toUpperCase(),
          onLogout: () async {
            await _authService.logout();
            if (mounted) {
              Navigator.of(context).pushNamedAndRemoveUntil('/auth', (route) => false);
            }
          },
          actions: [
            IconButton(
              onPressed: () => Navigator.pushNamed(context, '/search'),
              icon: const Icon(Icons.search),
              tooltip: 'Search Projects',
            ),
            // Notification Icon
            LayoutBuilder(
              builder: (context, constraints) {
                 // Check screen width for responsive behavior
                 final isDesktop = MediaQuery.of(context).size.width >= 900;
                 
                 if (isDesktop) {
                   return WebNotificationPanel(
                     notificationService: _notificationService,
                     onViewAll: () {
                        // Close dropdown relies on internal logic, but here we navigate
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
                              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                            );
                          },
                          tooltip: 'Notifications',
                        ),
                      );
                    },
                   );
                 }
              }
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
          body: AnimatedBuilder(
            animation: _projectService,
            builder: (context, child) {
              return Stack(
                children: [
                  IndexedStack(
                    index: _selectedIndex,
                    children: [
                      _ExploreTab(
                        projectService: _projectService, 
                        authService: _authService,
                        announcementService: _announcementService,
                      ),
                      _UploadTab(projectService: _projectService, authService: _authService),
                      _MyProjectsTab(projectService: _projectService, authService: _authService),
                      _BookmarksTab(projectService: _projectService, authService: _authService),
                      const SemesterArchiveScreen(),
                    ],
                  ),
                  if (_projectService.isLoading && _projectService.projects.isEmpty)
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
      ),
    );
  }
}

class _ExploreTab extends StatefulWidget {
  const _ExploreTab({
    required this.projectService, 
    required this.authService,
    required this.announcementService,
  });
  final ProjectService projectService;
  final AuthService authService;
  final AnnouncementService announcementService;

  @override
  State<_ExploreTab> createState() => _ExploreTabState();
}

class _ExploreTabState extends State<_ExploreTab> {
  late Stream<List<Announcement>> _announcementStream;

  @override
  void initState() {
    super.initState();
    _announcementStream = widget.announcementService.getActiveAnnouncementsStream();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Announcements Section
        StreamBuilder<List<Announcement>>(
          stream: _announcementStream,
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox.shrink();
            
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: AnnouncementCarousel(announcements: snapshot.data!),
                ),
              ),
            );
          },
        ),

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
          ...widget.projectService.featuredProjects.take(3).map((project) => _ProjectCard(
            project: project,
            projectService: widget.projectService,
            authService: widget.authService,
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
        if (widget.projectService.projects.isEmpty)
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
          ...widget.projectService.projects
              .where((p) => p.status == ProjectStatus.approved)
              .take(5)
              .map((project) => _ProjectCard(
                    project: project,
                    projectService: widget.projectService,
                    authService: widget.authService,
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
          projectService: widget.projectService,
          authService: widget.authService,
        ),
      ),
    );
  }


}

class _UploadTab extends StatelessWidget {
  const _UploadTab({required this.projectService, required this.authService});
  final ProjectService projectService;
  final AuthService authService;

  @override
  Widget build(BuildContext context) {
    return ProjectForm(
      projectService: projectService,
      authService: authService,
      onSuccess: () {
        // Provide feedback if needed, but ProjectForm already does it
      },
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
                      'By ${project.isGroupProject ? project.authorName : ((project.studentName != null && project.studentName!.isNotEmpty) ? project.studentName! : project.authorName)}${!project.isGroupProject && project.batch != null ? ' (Batch: ${project.batch})' : ''}',
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
                      if (project.status == ProjectStatus.pending)
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => ProjectFormScreen(
                                  initialProject: project,
                                  projectService: projectService,
                                  authService: authService,
                                ),
                              ),
                            );
                          },
                          tooltip: 'Edit Project',
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
        return Colors.amber[700]!;
      case ProjectStatus.needsRevision:
        return Colors.amber;
      case ProjectStatus.resubmitted:
        return Colors.blue;
    }
  }
}
