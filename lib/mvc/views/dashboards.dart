import 'package:flutter/material.dart';
import '../models/project.dart';
import '../controllers/project_service.dart';
import '../controllers/auth_service.dart';
import 'project_detail.dart';

class TeacherDashboardScreen extends StatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  final ProjectService _projectService = ProjectService();
  final AuthService _authService = AuthService();

  Future<void> _approveProject(Project project) async {
    final updatedProject = project.copyWith(status: ProjectStatus.approved);
    final success = await _projectService.updateProject(updatedProject);
    
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${project.title} approved')),
      );
    }
  }

  Future<void> _rejectProject(Project project) async {
    final updatedProject = project.copyWith(status: ProjectStatus.rejected);
    final success = await _projectService.updateProject(updatedProject);
    
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${project.title} rejected')),
      );
    }
  }

  Future<void> _featureProject(Project project) async {
    final updatedProject = project.copyWith(
      status: ProjectStatus.featured,
      isFeatured: true,
    );
    final success = await _projectService.updateProject(updatedProject);
    
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${project.title} featured')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Teacher Dashboard')),
      body: AnimatedBuilder(
        animation: _projectService,
        builder: (context, child) {
          final pendingProjects = _projectService.filterProjectsByStatus(ProjectStatus.pending);
          final approvedProjects = _projectService.filterProjectsByStatus(ProjectStatus.approved);
          
          return ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
              // Statistics Cards
              Row(
                children: <Widget>[
                  Expanded(
                    child: _StatCard(
                      icon: Icons.pending_actions,
                      label: 'Pending',
                      value: pendingProjects.length.toString(),
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.check_circle,
                      label: 'Approved',
                      value: approvedProjects.length.toString(),
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.star,
                      label: 'Featured',
                      value: _projectService.featuredProjects.length.toString(),
                      color: Colors.purple,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Pending Approvals
          Text('Pending Approvals', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
              if (pendingProjects.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Column(
                        children: <Widget>[
                          Icon(Icons.check_circle_outline, size: 48),
                          SizedBox(height: 8),
                          Text('No pending approvals'),
                        ],
                      ),
                    ),
                  ),
                )
              else
                ...pendingProjects.map((project) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.pending_actions, color: Colors.orange),
                    title: Text(project.title),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('${project.category.displayName} • ${project.year} • By ${project.authorName}'),
                        Text(project.abstract, maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                    trailing: Wrap(
                      spacing: 8,
                      children: <Widget>[
                        IconButton(
                          onPressed: () => _approveProject(project),
                          icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                          tooltip: 'Approve',
                        ),
                        IconButton(
                          onPressed: () => _rejectProject(project),
                          icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                          tooltip: 'Reject',
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                            builder: (_) => ProjectDetailScreen(
                              project: project,
                              projectService: _projectService,
                              authService: _authService,
                            ),
                          )),
                          icon: const Icon(Icons.visibility),
                          tooltip: 'View Details',
                        ),
                      ],
                    ),
                  ),
                )),
              const SizedBox(height: 24),
              
              // Recent Reviews
              Text('Recent Reviews', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (_projectService.reviews.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Column(
                        children: <Widget>[
                          Icon(Icons.rate_review, size: 48),
                          SizedBox(height: 8),
                          Text('No reviews yet'),
                        ],
                      ),
                    ),
                  ),
                )
              else
                ..._projectService.reviews.take(5).map((review) {
                  final project = _projectService.projects.firstWhere((p) => p.id == review.projectId);
                  return Card(
            child: ListTile(
                      leading: const Icon(Icons.rate_review),
                      title: Text(project.title),
                      subtitle: Text('${review.reviewerName} rated ★${review.rating.toStringAsFixed(1)}'),
                      trailing: Text(
                        '${review.createdAt.day}/${review.createdAt.month}/${review.createdAt.year}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => ProjectDetailScreen(
                          project: project,
                          projectService: _projectService,
            ),
          )),
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
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
        children: <Widget>[
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

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final ProjectService _projectService = ProjectService();
  final AuthService _authService = AuthService();

  Future<void> _deleteProject(Project project) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Project'),
        content: Text('Are you sure you want to delete "${project.title}"?'),
        actions: <Widget>[
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
      final success = await _projectService.deleteProject(project.id);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${project.title} deleted')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Dashboard')),
      body: AnimatedBuilder(
        animation: _projectService,
        builder: (context, child) {
          final allProjects = _projectService.projects;
          final projectsByStatus = <ProjectStatus, List<Project>>{};
          
          for (final status in ProjectStatus.values) {
            projectsByStatus[status] = _projectService.filterProjectsByStatus(status);
          }

          return ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
              // Statistics Overview
              Text('Overview', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 2.5,
                children: <Widget>[
                  _AdminStatCard(
                    icon: Icons.folder,
                    label: 'Total Projects',
                    value: allProjects.length.toString(),
                    color: Colors.blue,
                  ),
                  _AdminStatCard(
                    icon: Icons.pending_actions,
                    label: 'Pending',
                    value: projectsByStatus[ProjectStatus.pending]?.length.toString() ?? '0',
                    color: Colors.orange,
                  ),
                  _AdminStatCard(
                    icon: Icons.check_circle,
                    label: 'Approved',
                    value: projectsByStatus[ProjectStatus.approved]?.length.toString() ?? '0',
                    color: Colors.green,
                  ),
                  _AdminStatCard(
                    icon: Icons.star,
                    label: 'Featured',
                    value: projectsByStatus[ProjectStatus.featured]?.length.toString() ?? '0',
                    color: Colors.purple,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Project Management
              Text('Project Management', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
              if (allProjects.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Column(
                        children: <Widget>[
                          Icon(Icons.folder_open, size: 48),
                          SizedBox(height: 8),
                          Text('No projects found'),
                        ],
                      ),
                    ),
                  ),
                )
              else
                ...allProjects.take(10).map((project) => Card(
            child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _getStatusColor(project.status),
                      child: Icon(
                        _getStatusIcon(project.status),
                        color: Colors.white,
                      ),
                    ),
                    title: Text(project.title),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('${project.category.displayName} • ${project.year} • By ${project.authorName}'),
                        Text('Status: ${project.status.displayName}'),
                      ],
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (String value) {
                        switch (value) {
                          case 'view':
                            Navigator.of(context).push(MaterialPageRoute<void>(
                              builder: (_) => ProjectDetailScreen(
                                project: project,
                                projectService: _projectService,
                              ),
                            ));
                            break;
                          case 'delete':
                            _deleteProject(project);
                            break;
                        }
                      },
                      itemBuilder: (context) => <PopupMenuEntry<String>>[
                        const PopupMenuItem(
                          value: 'view',
                          child: Row(
                            children: <Widget>[
                              Icon(Icons.visibility),
                              SizedBox(width: 8),
                              Text('View Details'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: <Widget>[
                              Icon(Icons.delete, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Delete', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          )),
              const SizedBox(height: 24),

              // System Information
              Text('System Information', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: <Widget>[
                      ListTile(
                        leading: const Icon(Icons.storage),
                        title: const Text('Database'),
                        subtitle: const Text('Local storage (mock data)'),
                        trailing: const Icon(Icons.check_circle, color: Colors.green),
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.security),
                        title: const Text('Authentication'),
                        subtitle: Text(_authService.isAuthenticated ? 'Logged in' : 'Not logged in'),
                        trailing: Icon(
                          _authService.isAuthenticated ? Icons.check_circle : Icons.cancel,
                          color: _authService.isAuthenticated ? Colors.green : Colors.red,
                        ),
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.analytics),
                        title: const Text('Analytics'),
                        subtitle: Text('${allProjects.length} projects, ${_projectService.reviews.length} reviews'),
                        trailing: const Icon(Icons.info),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
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
    }
  }

  IconData _getStatusIcon(ProjectStatus status) {
    switch (status) {
      case ProjectStatus.draft:
        return Icons.edit;
      case ProjectStatus.pending:
        return Icons.pending_actions;
      case ProjectStatus.approved:
        return Icons.check_circle;
      case ProjectStatus.rejected:
        return Icons.cancel;
      case ProjectStatus.featured:
        return Icons.star;
      case ProjectStatus.needsRevision:
        return Icons.feedback;
      case ProjectStatus.resubmitted:
        return Icons.refresh;
    }
  }
}

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
        children: <Widget>[
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
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}


