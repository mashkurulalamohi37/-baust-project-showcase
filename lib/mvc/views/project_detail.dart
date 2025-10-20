import 'package:flutter/material.dart';
import '../models/project.dart';
import '../models/user.dart';
import '../controllers/project_service.dart';
import '../controllers/auth_service.dart';

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

    final success = await widget.projectService.addReview(review);
    
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
    final isBookmarked = widget.projectService.isBookmarked(project.id);
    final projectReviews = widget.projectService.reviews
        .where((r) => r.projectId == project.id)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(project.title),
        actions: <Widget>[
          IconButton(
            icon: Icon(isBookmarked ? Icons.bookmark : Icons.bookmark_border),
            onPressed: () => widget.projectService.toggleBookmark(project.id),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: widget.projectService,
        builder: (context, child) {
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
                              project.title,
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Chip(
                            label: Text(project.status.displayName),
                            backgroundColor: _getStatusColor(project.status, context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: <Widget>[
                          const Icon(Icons.star, size: 16, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text('${project.rating.toStringAsFixed(1)} (${project.reviewCount} reviews)'),
                          const SizedBox(width: 16),
                          Text('By ${project.authorName}'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Abstract
              Text('Abstract', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(project.abstract),
              const SizedBox(height: 16),

              // Version History
              if (project.versions.isNotEmpty) ...[
                Text('Version History', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                _buildVersionHistory(project),
                const SizedBox(height: 16),
              ],

              // Feedback Section
              if (project.feedback.isNotEmpty) ...[
                Text('Teacher Feedback', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                _buildFeedbackSection(project),
                const SizedBox(height: 16),
              ],

              // Revision Upload (for students with projects that need revision)
              if (widget.authService?.currentUser?.role == UserRole.student && 
                  project.status == ProjectStatus.needsRevision) ...[
                _buildRevisionUploadSection(project),
                const SizedBox(height: 16),
              ],
              
              // Tags and Info
              Wrap(
                spacing: 8,
                children: <Widget>[
                  Chip(label: Text(project.category.displayName)),
                  Chip(label: Text(project.year.toString())),
                  if (project.facultyName != null)
                    Chip(label: Text('Supervisor: ${project.facultyName}')),
                ],
              ),
              const SizedBox(height: 16),
              
              // Action Buttons
              if (project.pdfUrl != null)
                FilledButton.icon(
                  onPressed: () {
                    // In a real app, open PDF
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('PDF viewer coming soon!')),
                    );
                  },
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('Open PDF'),
                ),
              if (project.pdfUrl != null) const SizedBox(height: 8),
              if (project.githubUrl != null)
                OutlinedButton.icon(
                  onPressed: () {
                    // In a real app, open GitHub link
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('GitHub link: ${project.githubUrl}')),
                    );
                  },
                  icon: const Icon(Icons.link),
                  label: const Text('GitHub'),
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
                      child: Text(review.reviewerName[0].toUpperCase()),
                    ),
                    title: Row(
                      children: <Widget>[
                        Text(review.reviewerName),
                        const SizedBox(width: 8),
                        ...List.generate(5, (index) => Icon(
                          index < review.rating ? Icons.star : Icons.star_border,
                          size: 16,
                          color: Colors.amber,
                        )),
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
      bottomNavigationBar: widget.authService?.canCommentOnProjects() == true || widget.authService?.canRateProjects() == true
          ? SafeArea(
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
                        children: <Widget>[
                          Expanded(
                            child: TextField(
                              controller: _commentController,
                              decoration: const InputDecoration(
                                hintText: 'Add a comment',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: _isSubmitting ? null : _submitReview,
                            child: _isSubmitting
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text('Post'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Color _getStatusColor(ProjectStatus status, BuildContext context) {
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

  Widget _buildFeedbackCard(ProjectFeedback feedback) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: feedback.type == FeedbackType.critical 
            ? Colors.red.withOpacity(0.1)
            : feedback.type == FeedbackType.improvement
                ? Colors.orange.withOpacity(0.1)
                : Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: feedback.type == FeedbackType.critical 
              ? Colors.red
              : feedback.type == FeedbackType.improvement
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
                  color: feedback.type == FeedbackType.critical 
                      ? Colors.red
                      : feedback.type == FeedbackType.improvement
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
      // Create revised project
      final revisedProject = widget.project.copyWith(
        title: _titleController.text.trim(),
        abstract: _abstractController.text.trim(),
        githubUrl: _githubController.text.trim().isEmpty ? null : _githubController.text.trim(),
        imageUrls: _selectedFiles, // In real implementation, these would be uploaded URLs
        updatedAt: DateTime.now(),
      );

      // Create project revision
      final success = await widget.projectService.createProjectRevision(
        widget.project,
        revisedProject,
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
