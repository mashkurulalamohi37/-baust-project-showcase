import 'package:flutter/material.dart';
import '../mvc/models/project.dart';
import '../mvc/models/user.dart';
import '../mvc/models/review.dart';
import '../mvc/models/feedback.dart' as feedback_models;
import '../mvc/controllers/project_service.dart';
import '../mvc/controllers/auth_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class ProjectDetailScreen extends StatefulWidget {
  const ProjectDetailScreen({
    super.key, 
    required this.project, 
    required this.projectService,
    this.authService,
  });
  final Project project;
  final ProjectService projectService;
  final AuthService? authService;

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  final _commentController = TextEditingController();
  final _ratingController = TextEditingController();
  double _rating = 0.0;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Load reviews for this project
    widget.projectService.loadReviewsForProject(widget.project.id);
  }

  @override
  void dispose() {
    _commentController.dispose();
    _ratingController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    if (_commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a comment')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final currentUser = widget.authService?.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to submit a review')),
      );
      return;
    }

    final review = Review(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      projectId: widget.project.id,
      reviewerId: currentUser.id,
      reviewerName: currentUser.name,
      rating: _rating,
      comment: _commentController.text.trim(),
      createdAt: DateTime.now(),
    );

    final success = await widget.projectService.addReview(
      widget.project.id,
      _rating,
      _commentController.text.trim(),
    );
    
    setState(() => _isSubmitting = false);

    if (success && mounted) {
      _commentController.clear();
      _ratingController.clear();
      setState(() => _rating = 0.0);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review submitted successfully!')),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to submit review. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final project = widget.project;

    return Scaffold(
      appBar: AppBar(
        title: Text(project.title),
        actions: <Widget>[
          AnimatedBuilder(
            animation: widget.projectService,
            builder: (context, child) {
              final isBookmarked = widget.projectService.isBookmarked(project.id);
              return IconButton(
                icon: Icon(isBookmarked ? Icons.bookmark : Icons.bookmark_border),
                onPressed: () => widget.projectService.toggleBookmark(project.id),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: AnimatedBuilder(
              animation: widget.projectService,
              builder: (context, child) {
                // Get most up-to-date project data from service
                final currentProject = widget.projectService.projects
                    .firstWhere((p) => p.id == project.id, orElse: () => project);
                    
                final isBookmarked = widget.projectService.isBookmarked(currentProject.id);
                final projectReviews = widget.projectService.reviews
                    .where((r) => r.projectId == currentProject.id)
                    .toList();

                return ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              // Project Header
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              currentProject.title,
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Chip(
                            label: Text(currentProject.status.displayName),
                            backgroundColor: _getStatusColor(currentProject.status, context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: <Widget>[
                          const Icon(Icons.star, size: 16, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text('${currentProject.rating.toStringAsFixed(1)} (${currentProject.reviewCount} reviews)'),
                          const SizedBox(width: 16),
                          Text('By ${currentProject.authorName}'),
                        ],
                      ),
                      // Show supervisor info if available
                      if (currentProject.supervisor != null && currentProject.supervisor!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.school, size: 16, color: Colors.blue),
                            const SizedBox(width: 4),
                            Text(
                              'Supervisor: ${currentProject.supervisor}',
                              style: TextStyle(
                                color: Colors.blue[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                      // Show faculty (approver) info if available
                      if (currentProject.facultyName != null && currentProject.facultyName!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              currentProject.status == ProjectStatus.approved
                                  ? Icons.verified
                                  : Icons.person,
                              size: 16,
                              color: currentProject.status == ProjectStatus.approved
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              currentProject.status == ProjectStatus.approved
                                  ? 'Approved by: ${currentProject.facultyName}'
                                  : 'Assigned to: ${currentProject.facultyName}',
                              style: TextStyle(
                                color: currentProject.status == ProjectStatus.approved
                                    ? Colors.green[700]
                                    : Colors.orange[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Abstract
              Text('Abstract', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(currentProject.abstract),
              const SizedBox(height: 16),

              // Project Images Gallery
              if (currentProject.imageUrls.isNotEmpty) ...[
                Text('Project Images', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                _buildImageGallery(currentProject.imageUrls),
                const SizedBox(height: 16),
              ],

              // Version History
              if (currentProject.versions.isNotEmpty) ...[
                Text('Version History', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                _buildVersionHistory(currentProject),
                const SizedBox(height: 16),
              ],

              // Feedback Section
              if (currentProject.feedback.isNotEmpty) ...[
                Text('Teacher Feedback', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                _buildFeedbackSection(currentProject),
                const SizedBox(height: 16),
              ],

              // Revision Upload (for students with projects that need revision)
              if (widget.authService?.currentUser?.role == UserRole.student && 
                  currentProject.status == ProjectStatus.needsRevision) ...[
                _buildRevisionUploadSection(currentProject),
                const SizedBox(height: 16),
              ],
              
              // Tags and Info
              Wrap(
                spacing: 8,
                children: <Widget>[
                  Chip(label: Text(currentProject.category.displayName)),
                  Chip(label: Text(currentProject.year.toString())),
                if (currentProject.facultyName != null && currentProject.facultyName!.isNotEmpty)
                  Chip(
                    label: Text(
                      currentProject.status == ProjectStatus.approved
                          ? 'Approved by: ${currentProject.facultyName}'
                          : 'Supervisor: ${currentProject.facultyName}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Project Type & Team Type Badges
              Row(
                children: [
                  Chip(
                    avatar: Icon(
                      currentProject.projectType == ProjectType.thesis ? Icons.school : Icons.assignment,
                      size: 18,
                      color: currentProject.projectType == ProjectType.thesis
                          ? Colors.purple[900]
                          : Colors.blue[900],
                    ),
                    label: Text(
                      currentProject.projectType.displayName,
                      style: TextStyle(
                        color: currentProject.projectType == ProjectType.thesis
                            ? Colors.purple[900]
                            : Colors.blue[900],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    backgroundColor: currentProject.projectType == ProjectType.thesis
                        ? Colors.purple[100]
                        : Colors.blue[100],
                  ),
                  const SizedBox(width: 8),
                  Chip(
                    avatar: Icon(
                      currentProject.isGroupProject ? Icons.groups : Icons.person,
                      size: 18,
                      color: currentProject.isGroupProject ? Colors.green[900] : Colors.orange[900],
                    ),
                    label: Text(
                      currentProject.isGroupProject ? 'Group Project' : 'Individual Project',
                      style: TextStyle(
                        color: currentProject.isGroupProject ? Colors.green[900] : Colors.orange[900],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    backgroundColor: currentProject.isGroupProject ? Colors.green[100] : Colors.orange[100],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Individual Student Details
              if (!currentProject.isGroupProject && currentProject.studentId != null) ...[ 
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.person, size: 20, color: Colors.blue),
                            const SizedBox(width: 8),
                            Text(
                              'Student Information',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const Divider(),
                        _buildInfoRow('Student ID', currentProject.studentId ?? 'N/A'),
                        if (currentProject.batch != null)
                          _buildInfoRow('Batch', currentProject.batch.toString()),
                        if (currentProject.level != null)
                          _buildInfoRow('Level', currentProject.level.toString()),
                        if (currentProject.term != null)
                          _buildInfoRow('Term', currentProject.term.toString()),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              // Group Project Details
              if (currentProject.isGroupProject) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.groups, size: 20, color: Colors.green),
                            const SizedBox(width: 8),
                            Text(
                              'Group Information',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const Divider(),
                        if (currentProject.groupName != null)
                          _buildInfoRow('Group Name', currentProject.groupName!),
                        _buildInfoRow('Team Size', '${currentProject.teamMembers.length} members'),
                        const SizedBox(height: 12),
                        if (currentProject.teamMembers.isNotEmpty) ...[ 
                          Text(
                            'Team Members:',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...currentProject.teamMembers.asMap().entries.map((entry) {
                            final index = entry.key;
                            final member = entry.value;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              elevation: 0,
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Theme.of(context).colorScheme.primary,
                                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                  child: Text('${index + 1}'),
                                ),
                                title: Text(
                                  member.name,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  'ID: ${member.id} • Batch: ${member.batch} • Level: ${member.level} • Term: ${member.term}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                dense: true,
                              ),
                            );
                          }).toList(),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              // Drive Link Button
              if (currentProject.driveLink != null && currentProject.driveLink!.isNotEmpty) ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _openDriveLink(currentProject.driveLink!),
                    icon: const Icon(Icons.cloud),
                    label: const Text('View Additional Resources (Drive)'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              const SizedBox(height: 16),
              
              // Action Buttons
              if (currentProject.pdfUrl != null && currentProject.pdfUrl!.isNotEmpty) ...[
                FilledButton.icon(
                  onPressed: () {
                    debugPrint('PDF button clicked. URL: ${currentProject.pdfUrl}');
                    _openPdf(currentProject.pdfUrl!);
                  },
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('Open PDF'),
                ),
                const SizedBox(height: 8),
              ] else if (currentProject.pdfUrl != null) ...[
                // Debug: Show if pdfUrl is empty string
                Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.orange[100],
                  child: Text('PDF URL is empty: ${currentProject.pdfUrl}'),
                ),
              ],
              if (currentProject.githubUrl != null && currentProject.githubUrl!.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () => _openGitHub(currentProject.githubUrl!),
                  icon: const Icon(Icons.code),
                  label: const Text('View on GitHub'),
                ),
              const SizedBox(height: 16),
              
              // Reviews Section
              const Divider(),
              const SizedBox(height: 8),
              Text('Reviews', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (projectReviews.isEmpty)
                Text(
                  widget.authService?.canCommentOnProjects() == true 
                    ? 'No reviews yet. Be the first to review!'
                    : 'No reviews yet. Only teachers can provide reviews.',
                )
              else
                ...projectReviews.map((review) => Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text((review.reviewerName.isNotEmpty ? review.reviewerName[0] : 'R').toUpperCase()),
                    ),
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(review.reviewerName.isNotEmpty ? review.reviewerName : 'Anonymous Reviewer'),
                        const SizedBox(height: 4),
                        Row(
                          children: List.generate(5, (index) => Icon(
                            index < review.rating.round() ? Icons.star : Icons.star_border,
                            size: 18,
                            color: Colors.amber,
                          )),
                        ),
                      ],
                    ),
                    subtitle: Text(review.comment),
                    trailing: Text(
                      '${review.createdAt.day}/${review.createdAt.month}/${review.createdAt.year}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                )),
              
              // Show message for students about commenting restrictions
              if (widget.authService?.canCommentOnProjects() != true) ...[
                const SizedBox(height: 16),
                Card(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Students can view projects and reviews but cannot comment or rate. Only teachers can provide feedback.',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    ),
    if (widget.authService?.canCommentOnProjects() == true || widget.authService?.canRateProjects() == true)
      Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              offset: const Offset(0, -2),
              blurRadius: 4,
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // Rating Input (only for teachers)
                if (widget.authService?.canRateProjects() == true) ...[
                  Row(
                    children: <Widget>[
                      const Text('Rating: '),
                      ...List.generate(5, (index) => IconButton(
                        icon: Icon(
                          index < _rating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                        ),
                        onPressed: () => setState(() => _rating = index + 1.0),
                      )),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                // Comment Input (only for teachers)
                if (widget.authService?.canCommentOnProjects() == true) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          maxLines: 3,
                          minLines: 1,
                          decoration: const InputDecoration(
                            hintText: 'Write your review comment...',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _isSubmitting ? null : _submitReview,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Post'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ],
  ),
);
  }

  Color _getStatusColor(ProjectStatus status, BuildContext context) {
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

  Widget _buildVersionHistory(Project project) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Current version
            _buildVersionCard(
              version: project.version,
              title: project.title,
              abstract: project.abstract,
              createdAt: project.updatedAt,
              isCurrent: true,
            ),
            const SizedBox(height: 12),
            // Previous versions
            ...project.versions.map((version) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildVersionCard(
                version: version.versionNumber,
                title: version.title,
                abstract: version.abstract,
                createdAt: version.createdAt,
                isCurrent: false,
                changeDescription: version.changeDescription,
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildVersionCard({
    required int version,
    required String title,
    required String abstract,
    required DateTime createdAt,
    required bool isCurrent,
    String? changeDescription,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCurrent ? Colors.blue.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCurrent ? Colors.blue : Colors.grey,
          width: isCurrent ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.history,
                size: 16,
                color: isCurrent ? Colors.blue : Colors.grey,
              ),
              const SizedBox(width: 8),
              Text(
                'Version $version${isCurrent ? ' (Current)' : ''}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isCurrent ? Colors.blue : Colors.grey[700],
                ),
              ),
              const Spacer(),
              Text(
                '${createdAt.day}/${createdAt.month}/${createdAt.year}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          if (changeDescription != null) ...[
            const SizedBox(height: 4),
            Text(
              changeDescription,
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: Colors.grey[600],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(
            abstract,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackSection(Project project) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: project.feedback.map((feedback) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildFeedbackCard(feedback),
          )).toList(),
        ),
      ),
    );
  }

  Widget _buildFeedbackCard(feedback_models.ProjectFeedback feedback) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: feedback.type == feedback_models.FeedbackType.issue 
            ? Colors.red.withOpacity(0.1)
            : feedback.type == feedback_models.FeedbackType.improvement
                ? Colors.orange.withOpacity(0.1)
                : Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: feedback.type == feedback_models.FeedbackType.issue 
              ? Colors.red
              : feedback.type == feedback_models.FeedbackType.improvement
                  ? Colors.orange
                  : Colors.blue,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                feedback.type.icon,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(width: 8),
              Text(
                feedback.type.displayName,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: feedback.type == feedback_models.FeedbackType.issue 
                      ? Colors.red
                      : feedback.type == feedback_models.FeedbackType.improvement
                          ? Colors.orange
                          : Colors.blue,
                ),
              ),
              const Spacer(),
              Text(
                'by ${feedback.reviewerName}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(feedback.comment),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                '${feedback.createdAt.day}/${feedback.createdAt.month}/${feedback.createdAt.year}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const Spacer(),
              if (feedback.isResolved)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Resolved',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRevisionUploadSection(Project project) {
    return Card(
      color: Colors.amber.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.feedback, color: Colors.amber),
                const SizedBox(width: 8),
                Text(
                  'Project Needs Revision',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.amber[800],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Your teacher has provided feedback. Please review the feedback above and upload a revised version of your project.',
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showRevisionUploadDialog(project),
                icon: const Icon(Icons.upload),
                label: const Text('Upload Revised Version'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRevisionUploadDialog(Project project) {
    showDialog(
      context: context,
      builder: (context) => _RevisionUploadDialog(
        project: project,
        projectService: widget.projectService,
      ),
    );
  }

  Widget _buildImageGallery(List<String> imageUrls) {
    return Container(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: imageUrls.length,
        itemBuilder: (context, index) {
          final imageUrl = imageUrls[index];
          return Container(
            width: 200,
            margin: const EdgeInsets.only(right: 8),
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => _showImageDialog(imageUrl),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[300],
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error, color: Colors.grey[600]),
                              const SizedBox(height: 4),
                              Text(
                                'Failed to load',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${index + 1}/${imageUrls.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showImageDialog(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                        color: Colors.white,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error, color: Colors.white),
                          SizedBox(height: 8),
                          Text(
                            'Failed to load image',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openPdf(String pdfUrl) async {
    // Show loading dialog first
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      debugPrint('Opening PDF from URL: $pdfUrl');
      
      // Check if it's a local file path (starts with / or contains file://)
      if (pdfUrl.startsWith('/') || pdfUrl.startsWith('file://') || !pdfUrl.contains('://')) {
        Navigator.of(context).pop(); // Close loading dialog
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('PDF not uploaded yet. URL is a local file path:\n$pdfUrl\n\nPlease wait for upload to complete or re-upload the project.'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 5),
            ),
          );
        }
        return;
      }
      
      // Verify URL is valid
      final uri = Uri.tryParse(pdfUrl);
      if (uri == null || !uri.hasScheme || (!uri.scheme.startsWith('http'))) {
        Navigator.of(context).pop(); // Close loading dialog
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Invalid PDF URL format. Must be a valid HTTP/HTTPS URL.\n\nCurrent URL: $pdfUrl'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
        return;
      }

      Navigator.of(context).pop(); // Close loading dialog
      
      // Navigate to PDF viewer
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(
              title: const Text('PDF Viewer'),
            ),
            body: SfPdfViewer.network(
              pdfUrl,
              canShowScrollHead: true,
              canShowScrollStatus: true,
              onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
                debugPrint('PDF Load Error: ${details.error}');
                debugPrint('PDF URL: $pdfUrl');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to load PDF. Error: ${details.error}\n\nURL: $pdfUrl'),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 5),
                    ),
                  );
                }
              },
            ),
          ),
        ),
      );
    } catch (e, stackTrace) {
      Navigator.of(context).pop(); // Close loading dialog if still open
      debugPrint('Error opening PDF: $e');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('PDF URL: $pdfUrl');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening PDF: $e\n\nURL: $pdfUrl'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _openGitHub(String githubUrl) async {
    try {
      debugPrint('Opening GitHub URL: $githubUrl');
      
      // Add https:// if URL doesn't have a scheme
      String urlToOpen = githubUrl.trim();
      if (!urlToOpen.contains('://')) {
        urlToOpen = 'https://$urlToOpen';
        debugPrint('Added https:// prefix. New URL: $urlToOpen');
      }
      
      final uri = Uri.tryParse(urlToOpen);
      if (uri == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Invalid GitHub URL format: $githubUrl'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      
      debugPrint('Parsed URI: $uri');
      
      // Try to launch URL directly - sometimes canLaunchUrl returns false even when URL can be opened
      try {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        
        if (launched) {
          debugPrint('GitHub URL opened successfully');
        } else {
          // If launchUrl returns false, try with platformDefault mode
          debugPrint('LaunchMode.externalApplication failed, trying platformDefault');
          await launchUrl(
            uri,
            mode: LaunchMode.platformDefault,
          );
        }
      } on Exception catch (e) {
        debugPrint('Exception launching URL: $e');
        // Try with platformDefault as fallback
        try {
          await launchUrl(
            uri,
            mode: LaunchMode.platformDefault,
          );
          debugPrint('Successfully opened with platformDefault mode');
        } catch (e2) {
          debugPrint('Failed to launch URL with platformDefault: $e2');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Could not open GitHub link.\n\nURL: $urlToOpen\n\nError: $e2\n\nPlease try copying the link manually.'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 5),
                action: SnackBarAction(
                  label: 'Copy URL',
                  onPressed: () {
                    // Copy URL to clipboard
                    // You might need to add clipboard package for this
                  },
                ),
              ),
            );
          }
        }
      }
    } catch (e, stackTrace) {
      debugPrint('Error opening GitHub: $e');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('GitHub URL: $githubUrl');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening GitHub: $e\n\nURL: $githubUrl'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
  
  // Helper method to build info rows
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
  
  // Helper method to open drive link
  Future<void> _openDriveLink(String driveLink) async {
    try {
      debugPrint('Opening Drive Link: $driveLink');
      
      String urlToOpen = driveLink.trim();
      if (!urlToOpen.contains('://')) {
        urlToOpen = 'https://$urlToOpen';
      }
      
      final uri = Uri.tryParse(urlToOpen);
      if (uri == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Invalid Drive URL format: $driveLink'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      
      final canLaunch = await canLaunchUrl(uri);
      if (!canLaunch) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to open Drive link. Please check if the URL is accessible.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      debugPrint('Error opening Drive link: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening Drive link: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _RevisionUploadDialog extends StatefulWidget {
  const _RevisionUploadDialog({
    required this.project,
    required this.projectService,
  });

  final Project project;
  final ProjectService projectService;

  @override
  State<_RevisionUploadDialog> createState() => _RevisionUploadDialogState();
}

class _RevisionUploadDialogState extends State<_RevisionUploadDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _abstractController = TextEditingController();
  final _changeDescriptionController = TextEditingController();
  final _githubController = TextEditingController();
  
  List<String> _selectedFiles = [];
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill with current project data
    _titleController.text = widget.project.title;
    _abstractController.text = widget.project.abstract;
    _githubController.text = widget.project.githubUrl ?? '';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _abstractController.dispose();
    _changeDescriptionController.dispose();
    _githubController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Upload Revised Version'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current Version: ${widget.project.version}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Project Title',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value?.isEmpty == true ? 'Title is required' : null,
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _abstractController,
                decoration: const InputDecoration(
                  labelText: 'Abstract',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                validator: (value) => value?.isEmpty == true ? 'Abstract is required' : null,
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _changeDescriptionController,
                decoration: const InputDecoration(
                  labelText: 'Changes Made (Optional)',
                  hintText: 'Describe what you changed in this revision...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _githubController,
                decoration: const InputDecoration(
                  labelText: 'GitHub URL (Optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              
              Text(
                'Upload Files',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              
              OutlinedButton.icon(
                onPressed: _selectFiles,
                icon: const Icon(Icons.attach_file),
                label: const Text('Select Files'),
              ),
              
              if (_selectedFiles.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Selected Files:',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                ..._selectedFiles.map((file) => Padding(
                  padding: const EdgeInsets.only(left: 8, top: 4),
                  child: Text(
                    '• ${file.split('/').last}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                )),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isUploading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isUploading ? null : _uploadRevision,
          child: _isUploading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Upload Revision'),
        ),
      ],
    );
  }

  Future<void> _selectFiles() async {
    // This would integrate with file_picker in a real implementation
    // For now, we'll simulate file selection
    setState(() {
      _selectedFiles = ['document.pdf', 'image1.jpg', 'image2.png'];
    });
  }

  Future<void> _uploadRevision() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isUploading = true);

    try {
      // Create revised project with updated data
      final revisedProject = widget.project.copyWith(
        title: _titleController.text.trim(),
        abstract: _abstractController.text.trim(),
        githubUrl: _githubController.text.trim().isEmpty ? null : _githubController.text.trim(),
        imageUrls: _selectedFiles, // In real implementation, these would be uploaded URLs
        updatedAt: DateTime.now(),
      );

      // Create project revision - this will update the project and set status to pending
      final success = await widget.projectService.createProjectRevision(
        widget.project.id,
        'Project updated: ${_titleController.text.trim()}',
        updatedProjectData: revisedProject,
      );

      if (success && mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Revision uploaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to upload revision'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }
}
