import 'package:flutter/material.dart';
import '../models/project.dart';
import '../models/user.dart';
import '../models/feedback.dart' as feedback_models;
import '../models/review.dart';
import '../controllers/project_service.dart';
import '../controllers/auth_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class ProjectDetailScreen extends StatefulWidget {
  const ProjectDetailScreen({
    super.key,
    required this.project,
    required this.projectService,
    required this.authService,
  });

  final Project project;
  final ProjectService projectService;
  final AuthService authService;

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

    final currentUser = widget.authService.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to submit a review')),
      );
      setState(() => _isSubmitting = false);
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
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Project Header
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      project.abstract,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Chip(
                          label: Text(project.category.displayName),
                          backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                        ),
                        const SizedBox(width: 8),
                        Chip(
                          label: Text('${project.year}'),
                          backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
                        ),
                        const SizedBox(width: 8),
                        Chip(
                          label: Text(project.status.displayName),
                          backgroundColor: _getStatusColor(project.status, context).withOpacity(0.2),
                          labelStyle: TextStyle(
                            color: _getStatusColor(project.status, context),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(
                          Icons.person,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'By ${project.authorName}',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(width: 16),
                        Icon(
                          Icons.schedule,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${project.createdAt.day}/${project.createdAt.month}/${project.createdAt.year}',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (project.supervisor != null && project.supervisor!.isNotEmpty) ...[
                      Row(
                        children: [
                          const Icon(Icons.school, size: 16, color: Colors.blue),
                          const SizedBox(width: 4),
                          Text(
                            'Supervisor: ${project.supervisor}',
                            style: TextStyle(
                              color: Colors.blue[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (project.facultyName != null && project.facultyName!.isNotEmpty) ...[
                      Row(
                        children: [
                          Icon(
                            project.status == ProjectStatus.approved
                                ? Icons.verified
                                : Icons.person,
                            size: 16,
                            color: project.status == ProjectStatus.approved
                                ? Colors.green
                                : Colors.orange,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            project.status == ProjectStatus.approved
                                ? 'Approved by: ${project.facultyName}'
                                : 'Assigned to: ${project.facultyName}',
                            style: TextStyle(
                              color: project.status == ProjectStatus.approved
                                  ? Colors.green[700]
                                  : Colors.orange[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Project Images Gallery
            if (project.imageUrls.isNotEmpty) ...[
              Text('Project Images', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              _buildImageGallery(project.imageUrls),
              const SizedBox(height: 16),
            ],
            
            // Action Buttons
            if (project.pdfUrl != null) ...[
              FilledButton.icon(
                onPressed: () => _openPdf(project.pdfUrl!),
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Open PDF'),
              ),
              const SizedBox(height: 8),
            ],
            if (project.githubUrl != null)
              OutlinedButton.icon(
                onPressed: () => _openGitHub(project.githubUrl!),
                icon: const Icon(Icons.code),
                label: const Text('View on GitHub'),
              ),
            const SizedBox(height: 16),

            // Reviews Section
            Text(
              'Reviews',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            
            // Add Review Form
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add Review',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    
                    // Rating
                    Text('Rating:'),
                    const SizedBox(height: 8),
                    Row(
                      children: List.generate(5, (index) {
                        return IconButton(
                          onPressed: () {
                            setState(() {
                              _rating = index + 1.0;
                            });
                          },
                          icon: Icon(
                            index < _rating ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 16),
                    
                    // Comment
                    TextField(
                      controller: _commentController,
                      decoration: const InputDecoration(
                        labelText: 'Your Review',
                        hintText: 'Share your thoughts about this project...',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    
                    // Submit Button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton(
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
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Show each review with comment and reviewer name
            if (widget.projectService.getReviewsForProject != null)
              ...widget.projectService.getReviewsForProject(project.id).map((review) => Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(review.reviewerName?[0].toUpperCase() ?? 'R'),
                  ),
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(review.reviewerName ?? 'Unknown Reviewer'),
                      const SizedBox(height: 4),
                      Row(
                        children: List.generate(5, (index) => Icon(
                          index < review.rating.round() ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 18,
                        )),
                      ),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(review.comment),
                  ),
                  trailing: Text(
                    '${review.createdAt.day}/${review.createdAt.month}/${review.createdAt.year}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              )),
          ],
        ),
      ),
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
      case ProjectStatus.hidden:
        return Colors.blueGrey;
    }
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
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('PDF Viewer'),
          ),
          body: SfPdfViewer.network(pdfUrl),
        ),
      ),
    );
  }

  void _openGitHub(String githubUrl) {
    // For now, show a dialog with the GitHub URL
    // In a real app, you would use url_launcher to open the link
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('GitHub Repository'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('GitHub URL:'),
            const SizedBox(height: 8),
            SelectableText(
              githubUrl,
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 16),
            const Text(
              'Note: In a production app, this would open in the browser.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}