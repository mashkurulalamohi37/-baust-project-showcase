import 'package:flutter/material.dart';
import '../models/project.dart';
import '../models/user.dart';
import '../controllers/project_service.dart';
import '../controllers/auth_service.dart';
import 'project_detail.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
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
        title: const Text('Admin Dashboard'),
        backgroundColor: Theme.of(context).colorScheme.errorContainer,
        foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
        actions: [
          PopupMenuButton<String>(
            onSelected: (String value) async {
              if (value == 'logout') {
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
                    const Icon(Icons.admin_panel_settings),
                    const SizedBox(width: 8),
                    Text(_authService.currentUser?.name ?? 'Admin'),
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
              _OverviewTab(projectService: _projectService, authService: _authService),
              _UserManagementTab(projectService: _projectService, authService: _authService),
              _ProjectManagementTab(projectService: _projectService, authService: _authService),
              _SystemSettingsTab(projectService: _projectService, authService: _authService),
            ],
          );
        },
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int index) => setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Overview',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outlined),
            selectedIcon: Icon(Icons.people),
            label: 'Users',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder),
            label: 'Projects',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.projectService, required this.authService});
  final ProjectService projectService;
  final AuthService authService;

  @override
  Widget build(BuildContext context) {
    final allProjects = projectService.projects;
    final projectsByStatus = <ProjectStatus, List<Project>>{};
    
    for (final status in ProjectStatus.values) {
      projectsByStatus[status] = projectService.filterProjectsByStatus(status);
    }

    final totalUsers = 1; // Mock data - in real app, get from user service
    final pendingTeachers = 0; // Mock data - in real app, get from user service
    final totalReviews = projectService.reviews.length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header
        Card(
          color: Theme.of(context).colorScheme.errorContainer,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(
                  Icons.admin_panel_settings,
                  size: 48,
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
                const SizedBox(height: 12),
                Text(
                  'Admin Control Panel',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Manage users, projects, and system settings',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onErrorContainer.withOpacity(0.8),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Quick Stats
        Text(
          'Quick Statistics',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth > 600 ? 4 : 2;
            return GridView.count(
              crossAxisCount: crossAxisCount,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.5,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: [
                _AdminStatCard(
                  icon: Icons.people,
                  label: 'Total Users',
                  value: totalUsers.toString(),
                  color: Colors.blue,
                ),
                _AdminStatCard(
                  icon: Icons.pending_actions,
                  label: 'Pending Teachers',
                  value: pendingTeachers.toString(),
                  color: Colors.orange,
                ),
                _AdminStatCard(
                  icon: Icons.folder,
                  label: 'Total Projects',
                  value: allProjects.length.toString(),
                  color: Colors.green,
                ),
                _AdminStatCard(
                  icon: Icons.rate_review,
                  label: 'Total Reviews',
                  value: totalReviews.toString(),
                  color: Colors.purple,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),

        // Project Status Overview
        Text(
          'Project Status Overview',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _StatusRow(
                  status: 'Draft',
                  count: projectsByStatus[ProjectStatus.draft]?.length ?? 0,
                  color: Colors.grey,
                ),
                _StatusRow(
                  status: 'Pending',
                  count: projectsByStatus[ProjectStatus.pending]?.length ?? 0,
                  color: Colors.orange,
                ),
                _StatusRow(
                  status: 'Approved',
                  count: projectsByStatus[ProjectStatus.approved]?.length ?? 0,
                  color: Colors.green,
                ),
                _StatusRow(
                  status: 'Rejected',
                  count: projectsByStatus[ProjectStatus.rejected]?.length ?? 0,
                  color: Colors.red,
                ),
                _StatusRow(
                  status: 'Featured',
                  count: projectsByStatus[ProjectStatus.featured]?.length ?? 0,
                  color: Colors.purple,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Recent Activity
        Text(
          'Recent Activity',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _ActivityItem(
                  icon: Icons.upload,
                  title: 'New Project Uploaded',
                  subtitle: 'Student uploaded "Mobile App Development"',
                  time: '2 hours ago',
                ),
                const Divider(),
                _ActivityItem(
                  icon: Icons.rate_review,
                  title: 'Project Reviewed',
                  subtitle: 'Teacher reviewed "AI Chatbot Project"',
                  time: '4 hours ago',
                ),
                const Divider(),
                _ActivityItem(
                  icon: Icons.person_add,
                  title: 'New Teacher Registered',
                  subtitle: 'Dr. Smith registered for approval',
                  time: '1 day ago',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _UserManagementTab extends StatefulWidget {
  const _UserManagementTab({required this.projectService, required this.authService});
  final ProjectService projectService;
  final AuthService authService;

  @override
  State<_UserManagementTab> createState() => _UserManagementTabState();
}

class _UserManagementTabState extends State<_UserManagementTab> {
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    // Listen to auth service changes to refresh when roles change
    widget.authService.addListener(_onAuthServiceChanged);
  }

  @override
  void dispose() {
    widget.authService.removeListener(_onAuthServiceChanged);
    super.dispose();
  }

  void _onAuthServiceChanged() {
    // Refresh the current view when auth service changes
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
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
                  Icons.people,
                  size: 48,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
                const SizedBox(height: 12),
                Text(
                  'User Management',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Manage users, approve teachers, and control access',
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

        // Filter Tabs
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _FilterChip(
                label: 'All Users',
                isSelected: _selectedFilter == 'All',
                onTap: () => setState(() => _selectedFilter = 'All'),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Students',
                isSelected: _selectedFilter == 'Students',
                onTap: () => setState(() => _selectedFilter = 'Students'),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Teachers',
                isSelected: _selectedFilter == 'Teachers',
                onTap: () => setState(() => _selectedFilter = 'Teachers'),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Pending Approval',
                isSelected: _selectedFilter == 'Pending',
                onTap: () => setState(() => _selectedFilter = 'Pending'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Users List
        if (_selectedFilter == 'Pending')
          _PendingTeachersSection(authService: widget.authService)
        else
          _AllUsersSection(filter: _selectedFilter, authService: widget.authService),
      ],
    );
  }
}

class _ProjectManagementTab extends StatelessWidget {
  const _ProjectManagementTab({required this.projectService, required this.authService});
  final ProjectService projectService;
  final AuthService authService;

  @override
  Widget build(BuildContext context) {
    final allProjects = List<Project>.from(projectService.projects)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

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
                  Icons.folder,
                  size: 48,
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                ),
                const SizedBox(height: 12),
                Text(
                  'Project Management',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${allProjects.length} project${allProjects.length == 1 ? '' : 's'} in the system',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSecondaryContainer.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Projects List
        if (allProjects.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.folder_open, size: 48, color: Colors.grey),
                    SizedBox(height: 8),
                    Text('No projects found'),
                    SizedBox(height: 4),
                    Text('Students haven\'t uploaded any projects yet'),
                  ],
                ),
              ),
            ),
          )
        else
          ...allProjects.map((project) => _AdminProjectCard(
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

class _SystemSettingsTab extends StatelessWidget {
  const _SystemSettingsTab({required this.projectService, required this.authService});
  final ProjectService projectService;
  final AuthService authService;

  @override
  Widget build(BuildContext context) {
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
                  Icons.settings,
                  size: 48,
                  color: Theme.of(context).colorScheme.onTertiaryContainer,
                ),
                const SizedBox(height: 12),
                Text(
                  'System Settings',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onTertiaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Configure system preferences and security settings',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onTertiaryContainer.withOpacity(0.8),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Settings Sections
        _SettingsSection(
          title: 'User Management',
          items: [
            _SettingsItem(
              icon: Icons.person_add,
              title: 'Teacher Approval',
              subtitle: 'Manage teacher registration approvals',
              onTap: () {},
            ),
            _SettingsItem(
              icon: Icons.security,
              title: 'Access Control',
              subtitle: 'Configure user permissions and roles',
              onTap: () {},
            ),
            _SettingsItem(
              icon: Icons.block,
              title: 'User Suspension',
              subtitle: 'Suspend or activate user accounts',
              onTap: () {},
            ),
          ],
        ),
        const SizedBox(height: 16),

        _SettingsSection(
          title: 'Project Management',
          items: [
            _SettingsItem(
              icon: Icons.auto_awesome,
              title: 'Auto-approval',
              subtitle: 'Configure automatic project approval',
              onTap: () {},
            ),
            _SettingsItem(
              icon: Icons.star,
              title: 'Featured Projects',
              subtitle: 'Manage featured project settings',
              onTap: () {},
            ),
            _SettingsItem(
              icon: Icons.category,
              title: 'Categories',
              subtitle: 'Manage project categories',
              onTap: () {},
            ),
          ],
        ),
        const SizedBox(height: 16),

        _SettingsSection(
          title: 'System',
          items: [
            _SettingsItem(
              icon: Icons.backup,
              title: 'Backup & Restore',
              subtitle: 'Manage system backups',
              onTap: () {},
            ),
            _SettingsItem(
              icon: Icons.analytics,
              title: 'Analytics',
              subtitle: 'View system analytics and reports',
              onTap: () {},
            ),
            _SettingsItem(
              icon: Icons.notifications,
              title: 'Notifications',
              subtitle: 'Configure system notifications',
              onTap: () {},
            ),
          ],
        ),
      ],
    );
  }
}

// Helper Widgets
class _AdminStatCard extends StatelessWidget {
  const _AdminStatCard({
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
      margin: const EdgeInsets.all(4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          const SizedBox(height: 4),
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.status,
    required this.count,
    required this.color,
  });
  final String status;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(status)),
          Text(
            count.toString(),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  const _ActivityItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.time,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final String time;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: Theme.of(context).colorScheme.primaryContainer,
      checkmarkColor: Theme.of(context).colorScheme.onPrimaryContainer,
    );
  }
}

class _PendingTeachersSection extends StatefulWidget {
  const _PendingTeachersSection({required this.authService});
  final AuthService authService;

  @override
  State<_PendingTeachersSection> createState() => _PendingTeachersSectionState();
}

class _PendingTeachersSectionState extends State<_PendingTeachersSection> {
  List<User> _pendingTeachers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPendingTeachers();
  }

  Future<void> _loadPendingTeachers() async {
    setState(() => _isLoading = true);
    final teachers = await widget.authService.getPendingTeachers();
    setState(() {
      _pendingTeachers = teachers;
      _isLoading = false;
    });
  }

  // Method to refresh pending teachers from outside
  void refreshPendingTeachers() {
    _loadPendingTeachers();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Pending Teacher Approvals',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: _loadPendingTeachers,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_pendingTeachers.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.check_circle_outline, size: 48, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('No pending approvals'),
                        SizedBox(height: 4),
                        Text('All teachers have been approved'),
                      ],
                    ),
                  ),
                ),
              )
            else
              ..._pendingTeachers.map((teacher) => _TeacherApprovalCard(
                    teacher: teacher,
                    onApprove: () => _approveTeacher(context, teacher),
                    onReject: () => _rejectTeacher(context, teacher),
                  )),
          ],
        ),
      ),
    );
  }

  Future<void> _approveTeacher(BuildContext context, User teacher) async {
    try {
      final success = await widget.authService.approveTeacher(teacher.id);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${teacher.name} approved as teacher'),
            backgroundColor: Colors.green,
          ),
        );
        // Refresh the list
        _loadPendingTeachers();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to approve teacher: ${widget.authService.errorMessage}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error approving teacher: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _rejectTeacher(BuildContext context, User teacher) async {
    try {
      final success = await widget.authService.rejectTeacher(teacher.id);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${teacher.name} rejected'),
            backgroundColor: Colors.orange,
          ),
        );
        // Refresh the list
        _loadPendingTeachers();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reject teacher: ${widget.authService.errorMessage}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error rejecting teacher: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class _AllUsersSection extends StatefulWidget {
  const _AllUsersSection({required this.filter, required this.authService});
  final String filter;
  final AuthService authService;

  @override
  State<_AllUsersSection> createState() => _AllUsersSectionState();
}

class _AllUsersSectionState extends State<_AllUsersSection> {
  List<User> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    List<User> users;
    
    if (widget.filter == 'All') {
      users = await widget.authService.getAllUsers();
    } else if (widget.filter == 'Students') {
      users = await widget.authService.getUsersByRole(UserRole.student);
    } else if (widget.filter == 'Teachers') {
      users = await widget.authService.getUsersByRole(UserRole.teacher);
    } else {
      users = [];
    }
    
    setState(() {
      _users = users;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'All Users (${widget.filter})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: _loadUsers,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_users.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(Icons.people_outline, size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      Text('No users found'),
                    ],
                  ),
                ),
              )
            else
              ..._users.map((user) => _UserManagementCard(
                user: user,
                onStatusChange: () => _loadUsers(),
                onRoleChange: () => _loadUsers(),
                onDelete: () => _loadUsers(),
                authService: widget.authService,
              )),
          ],
        ),
      ),
    );
  }
}

class _TeacherApprovalCard extends StatelessWidget {
  const _TeacherApprovalCard({
    required this.teacher,
    required this.onApprove,
    required this.onReject,
  });
  final User teacher;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Text(
                    teacher.name[0].toUpperCase(),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        teacher.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        teacher.email,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                      if (teacher.department != null)
                        Text(
                          teacher.department!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onApprove,
                    icon: const Icon(Icons.check),
                    label: const Text('Approve'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onReject,
                    icon: const Icon(Icons.close),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.user});
  final User user;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
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
        trailing: PopupMenuButton<String>(
          onSelected: (String value) {
            // Handle user actions
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'view',
              child: Row(
                children: [
                  Icon(Icons.visibility),
                  SizedBox(width: 8),
                  Text('View Details'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'suspend',
              child: Row(
                children: [
                  Icon(Icons.block, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Suspend', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminProjectCard extends StatelessWidget {
  const _AdminProjectCard({
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
              Text(
                'By ${project.authorName} • ${project.category.displayName} • ${project.year}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                project.abstract,
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.star, size: 16, color: Colors.amber),
                  const SizedBox(width: 4),
                  Text('${project.rating.toStringAsFixed(1)} (${project.reviewCount})'),
                  const Spacer(),
                  PopupMenuButton<String>(
                    onSelected: (String value) {
                      switch (value) {
                        case 'delete':
                          _deleteProject(context, project);
                          break;
                        case 'feature':
                          _featureProject(context, project);
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'feature',
                        child: Row(
                          children: [
                            Icon(Icons.star),
                            SizedBox(width: 8),
                            Text('Feature'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
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

  void _deleteProject(BuildContext context, Project project) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Project'),
        content: Text('Are you sure you want to delete "${project.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await projectService.deleteProject(project.id);
      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${project.title} deleted')),
        );
      }
    }
  }

  void _featureProject(BuildContext context, Project project) async {
    final updatedProject = project.copyWith(
      status: ProjectStatus.featured,
      isFeatured: true,
    );
    final success = await projectService.updateProject(updatedProject);
    
    if (success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${project.title} featured')),
      );
    }
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
    }
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.items,
  });
  final String title;
  final List<_SettingsItem> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...items,
          ],
        ),
      ),
    );
  }
}

class _SettingsItem extends StatelessWidget {
  const _SettingsItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _UserManagementCard extends StatelessWidget {
  const _UserManagementCard({
    required this.user,
    required this.onStatusChange,
    required this.onRoleChange,
    required this.onDelete,
    required this.authService,
  });
  
  final User user;
  final VoidCallback onStatusChange;
  final VoidCallback onRoleChange;
  final VoidCallback onDelete;
  final AuthService authService;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: _getRoleColor(user.role),
                  child: Icon(
                    _getRoleIcon(user.role),
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      Text(
                        user.email,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          _StatusChip(
                            label: user.role.displayName,
                            color: _getRoleColor(user.role),
                          ),
                          _StatusChip(
                            label: user.isActive ? 'Active' : 'Inactive',
                            color: user.isActive ? Colors.green : Colors.red,
                          ),
                          if (user.role == UserRole.teacher) ...[
                            _StatusChip(
                              label: user.isApproved ? 'Approved' : 'Pending',
                              color: user.isApproved ? Colors.blue : Colors.orange,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) => _handleAction(context, value),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'toggle_status',
                      child: Row(
                        children: [
                          Icon(user.isActive ? Icons.block : Icons.check_circle),
                          const SizedBox(width: 8),
                          Text(user.isActive ? 'Deactivate' : 'Activate'),
                        ],
                      ),
                    ),
                    if (user.role != UserRole.admin) ...[
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'change_role',
                        child: const Row(
                          children: [
                            Icon(Icons.swap_horiz),
                            SizedBox(width: 8),
                            Text('Change Role'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: const Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete User', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            if (user.role == UserRole.teacher) ...[
              const SizedBox(height: 8),
              if (user.department != null) ...[
                Text(
                  'Department: ${user.department}',
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
              if (user.employeeId != null) ...[
                Text(
                  'Employee ID: ${user.employeeId}',
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ],
            const SizedBox(height: 8),
            Text(
              'Joined: ${_formatDate(user.createdAt)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            if (user.lastLoginAt != null) ...[
              Text(
                'Last Login: ${_formatDate(user.lastLoginAt!)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _handleAction(BuildContext context, String action) async {
    switch (action) {
      case 'toggle_status':
        await _toggleUserStatus(context);
        break;
      case 'change_role':
        await _showRoleChangeDialog(context);
        break;
      case 'delete':
        await _deleteUser(context);
        break;
    }
  }

  Future<void> _toggleUserStatus(BuildContext context) async {
    try {
      final success = await authService.updateUserStatus(user.id, !user.isActive);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User ${user.isActive ? 'deactivated' : 'activated'} successfully'),
            backgroundColor: Colors.green,
          ),
        );
        onStatusChange();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update user status: ${authService.errorMessage}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating user status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showRoleChangeDialog(BuildContext context) async {
    UserRole? newRole = user.role;
    bool roleChanged = false;
    
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.swap_horiz),
              const SizedBox(width: 8),
              const Text('Change User Role'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Changing role for: ${user.name}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Current role: ${user.role.displayName}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Select new role:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              ...UserRole.values.map((role) {
                return RadioListTile<UserRole>(
                  title: Text(role.displayName),
                  subtitle: Text(role.description),
                  value: role,
                  groupValue: newRole,
                  onChanged: (value) {
                    setState(() {
                      newRole = value;
                      roleChanged = true;
                    });
                  },
                );
              }).toList(),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            if (roleChanged && newRole != user.role)
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _changeUserRole(context, newRole!);
                },
                child: const Text('Confirm Change'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _changeUserRole(BuildContext context, UserRole newRole) async {
    debugPrint('_UserManagementCard: Starting role change for ${user.name} to ${newRole.name}');
    
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Changing user role...'),
          ],
        ),
      ),
    );

    try {
      debugPrint('_UserManagementCard: Calling authService.changeUserRole');
      
      // Add timeout to prevent infinite loading
      final success = await Future.any([
        authService.changeUserRole(user.id, newRole),
        Future.delayed(const Duration(seconds: 10), () => false),
      ]);
      
      debugPrint('_UserManagementCard: Role change result: $success');
      
      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
        debugPrint('_UserManagementCard: Loading dialog closed');
      }
      
      if (success) {
        debugPrint('_UserManagementCard: Role change successful, showing success message');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('User role changed to ${newRole.displayName}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        // Call the callback to refresh the parent widget
        debugPrint('_UserManagementCard: Calling onRoleChange callback');
        onRoleChange();
      } else {
        debugPrint('_UserManagementCard: Role change failed, showing error message');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to change user role: ${authService.errorMessage ?? 'Operation timed out'}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('_UserManagementCard: Exception during role change: $e');
      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
        debugPrint('_UserManagementCard: Loading dialog closed after exception');
      }
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error changing user role: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _deleteUser(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text('Are you sure you want to delete ${user.name}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final success = await authService.deleteUser(user.id);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('User ${user.name} deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          onDelete();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete user: ${authService.errorMessage}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting user: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.student:
        return Colors.blue;
      case UserRole.teacher:
        return Colors.green;
      case UserRole.admin:
        return Colors.red;
    }
  }

  IconData _getRoleIcon(UserRole role) {
    switch (role) {
      case UserRole.student:
        return Icons.school;
      case UserRole.teacher:
        return Icons.rate_review;
      case UserRole.admin:
        return Icons.admin_panel_settings;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});
  
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }
}
