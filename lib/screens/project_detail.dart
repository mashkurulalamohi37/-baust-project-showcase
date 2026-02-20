import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../mvc/models/project.dart';
import '../mvc/models/user.dart';
import '../mvc/models/review.dart';
import '../mvc/models/feedback.dart' as feedback_models;
import '../mvc/controllers/project_service.dart';
import '../mvc/controllers/auth_service.dart';
import '../mvc/controllers/firestore_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../utils/youtube_web/youtube_web_shim.dart';
import '../widgets/showcase_evaluation_card.dart';
import 'student_portfolio_screen.dart';

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
  bool _isUploading = false;
  User? _facultyUser;
  YoutubePlayerController? _youtubeController;
  final GlobalKey _playerKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Load reviews for this project
    widget.projectService.loadReviewsForProject(widget.project.id);
    _loadFacultyDetails();
    _initYoutubeController();
  }

  void _initYoutubeController() {
    if (widget.project.youtubeUrl != null && widget.project.youtubeUrl!.isNotEmpty) {
      String? videoId = _extractVideoId(widget.project.youtubeUrl!);
      if (videoId != null) {
        _youtubeController = YoutubePlayerController(
          initialVideoId: videoId,
          flags: const YoutubePlayerFlags(
            autoPlay: false,
            mute: false,
            enableCaption: true,
            controlsVisibleAtStart: true,
            forceHD: false,
          ),
        );
      }
    }
  }

  String? _extractVideoId(String url) {
    if (url.trim().isEmpty) return null;
    
    // 1. Try standard library converter
    String? id = YoutubePlayer.convertUrlToId(url);
    if (id != null) return id;

    // 2. Handle Shorts specifically (sometimes missed by library)
    // Format: youtube.com/shorts/VIDEO_ID
    final RegExp shortsRegex = RegExp(r'youtube\.com\/shorts\/([a-zA-Z0-9_-]+)');
    final shortsMatch = shortsRegex.firstMatch(url);
    if (shortsMatch != null && shortsMatch.groupCount >= 1) {
      return shortsMatch.group(1);
    }
    
    // 3. Handle Live streams or other formats
    // Format: youtube.com/live/VIDEO_ID
    final RegExp liveRegex = RegExp(r'youtube\.com\/live\/([a-zA-Z0-9_-]+)');
    final liveMatch = liveRegex.firstMatch(url);
    if (liveMatch != null && liveMatch.groupCount >= 1) {
      return liveMatch.group(1);
    }

    // 4. Fallback Regex for standard formats if library fails
    final RegExp fallbackRegex = RegExp(r'^.*(youtu.be\/|v\/|u\/\w\/|embed\/|watch\?v=|\&v=)([^#\&\?]*).*');
    final match = fallbackRegex.firstMatch(url);
    if (match != null && match.groupCount >= 2) {
      final String extracted = match.group(2)!;
      // Filter out any potential garbage length
      if (extracted.length == 11) return extracted;
    }

    return null;
  }

  Future<void> _loadFacultyDetails() async {
    debugPrint('Loading faculty details for facultyId: ${widget.project.facultyId}');
    if (widget.project.facultyId != null) {
      try {
        final user = await FirestoreService.getUser(widget.project.facultyId!);
        debugPrint('Faculty user loaded: ${user?.name}, designation: ${user?.designation?.displayName}');
        if (mounted && user != null) {
          setState(() {
            _facultyUser = user;
          });
          debugPrint('Faculty user set in state: ${_facultyUser?.name}, designation: ${_facultyUser?.designation?.displayName}');
        }
      } catch (e) {
        debugPrint('Error loading faculty details: $e');
      }
    } else {
      debugPrint('No facultyId found in project');
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _ratingController.dispose();
    _youtubeController?.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    // Restrict students from reviewing
    if (widget.authService?.currentUser?.role == UserRole.student) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Students cannot submit reviews.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Reviews are only allowed after the project is accepted/approved
    if (widget.project.status != ProjectStatus.approved && 
        widget.project.status != ProjectStatus.featured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You can only submit reviews for approved projects.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
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
    if (kIsWeb || _youtubeController == null) {
      return LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 900) {
            return _buildDesktopLayout(context);
          }
          return _buildScaffold(context);
        },
      );
    }

    return YoutubePlayerBuilder(
      player: YoutubePlayer(
        controller: _youtubeController!,
        showVideoProgressIndicator: true,
        progressIndicatorColor: Colors.red,
        topActions: <Widget>[
          const SizedBox(width: 8.0),
          Expanded(
            child: Text(
              _youtubeController!.metadata.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18.0,
                overflow: TextOverflow.ellipsis,
              ),
              maxLines: 1,
            ),
          ),
        ],
      ),
      builder: (context, player) {
        return LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > 900) {
              return _buildDesktopLayout(context, player: player);
            }
            return _buildScaffold(context, player: player);
          },
        );
      },
    );
  }

  Widget _buildDesktopLayout(BuildContext context, {Widget? player}) {
    final project = widget.project;
    return Scaffold(
      appBar: AppBar(
        title: Text(project.title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                 Color(0xFF232526), // Midnight City
                 Color(0xFF414345),
              ],
            ),
          ),
        ),
        actions: <Widget>[
          AnimatedBuilder(
            animation: widget.projectService,
            builder: (context, child) {
              final isBookmarked = widget.projectService.isBookmarked(project.id);
              return IconButton(
                icon: Icon(isBookmarked ? Icons.bookmark : Icons.bookmark_border, color: Colors.white),
                onPressed: () => widget.projectService.toggleBookmark(project.id),
              );
            },
          ),
          if (widget.authService?.currentUser?.id == project.authorId)
             IconButton(
               icon: Icon(
                 (widget.authService?.currentUser?.pinnedProjectIds?.contains(project.id) ?? false) 
                     ? Icons.push_pin 
                     : Icons.push_pin_outlined,
                 color: Colors.white,
               ),
               onPressed: _togglePinProject,
               tooltip: (widget.authService?.currentUser?.pinnedProjectIds?.contains(project.id) ?? false)
                   ? 'Unpin from Profile'
                   : 'Pin to Profile',
             ),
        ],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Column: Project Details (60%)
              Expanded(
                flex: 6,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       // Header Info
                       _buildProjectHeader(context, isDesktop: true),
                       const SizedBox(height: 24),
                       // Abstract
                       Text('Abstract', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                       const SizedBox(height: 12),
                       Text(project.abstract, style: const TextStyle(fontSize: 16, height: 1.6)),
                       const SizedBox(height: 32),
                       
                       // Images
                       if (project.imageUrls.isNotEmpty) ...[
                         Text('Project Gallery', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                         const SizedBox(height: 16),
                         _buildImageGallery(project.imageUrls), // Needs adaptation for grid? Or keep list
                         const SizedBox(height: 32),
                       ],
                       
                       // YouTube
                       if (project.youtubeUrl != null && project.youtubeUrl!.isNotEmpty) ...[
                         Text('Project Demo', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                         const SizedBox(height: 16),
                         AspectRatio(
                           aspectRatio: 16 / 9,
                           child: kIsWeb
                             ? Builder(builder: (c) {
                                  final id = _extractVideoId(project.youtubeUrl!);
                                  return id != null ? buildWebYoutubePlayer(id) : _buildInvalidYoutubeCard();
                               })
                             : player ??
                                  (_youtubeController != null
                                  ? YoutubePlayer(
                                      controller: _youtubeController!,
                                      showVideoProgressIndicator: true,
                                      progressIndicatorColor: Colors.red,
                                    )
                                  : _buildInvalidYoutubeCard()),
                          ),
                        ],
                     ],
                   ),
                 ),
               ),
               // Right Column: Meta, Reviews, Eval (40%)
               Expanded(
                 flex: 4,
                 child: Container(
                   decoration: BoxDecoration(
                     border: Border(left: BorderSide(color: Theme.of(context).dividerColor)),
                   ),
                   child: ListView(
                     padding: const EdgeInsets.all(24),
                     children: [
                       _buildMetaInfoCard(context, project),
                       const SizedBox(height: 24),
                       if (project.versions.isNotEmpty) ...[
                         Text('Version History', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                         const SizedBox(height: 12),
                         _buildVersionHistory(project),
                         const SizedBox(height: 24),
                       ],
                       if (project.feedback.isNotEmpty) ...[
                         Text('Teacher Feedback', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                         const SizedBox(height: 12),
                         _buildFeedbackSection(project),
                         const SizedBox(height: 24),
                       ],
                        if (widget.authService?.currentUser?.role == UserRole.student && 
                           project.status == ProjectStatus.needsRevision) ...[
                         _buildRevisionUploadSection(project),
                         const SizedBox(height: 24),
                       ],
                       if (widget.authService?.currentUser != null &&
                           (widget.authService!.currentUser!.role == UserRole.admin ||
                            widget.authService!.currentUser!.role == UserRole.teacher) &&
                           project.submissionType == ProjectSubmissionType.projectShowcase &&
                           (project.status == ProjectStatus.approved || project.status == ProjectStatus.featured)) ...[
                         ShowcaseEvaluationCard(
                           project: project,
                           projectService: widget.projectService,
                           isAdmin: widget.authService!.currentUser!.role == UserRole.admin,
                         ),
                         const SizedBox(height: 24),
                       ],
                       Text('Reviews (${project.reviewCount})', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                       const SizedBox(height: 12),
                       _buildReviewsSection(project),
                     ],
                   ),
                 ),
               ),
             ],
           ),
         ),
       ),
    );
  }

  Widget _buildScaffold(BuildContext context, {Widget? player}) {
    final project = widget.project;

    return Scaffold(
      appBar: AppBar(
        title: Text(project.title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                 Color(0xFF232526), // Midnight City
                 Color(0xFF414345),
              ],
            ),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
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
          if (widget.authService?.currentUser?.id == project.authorId)
             IconButton(
               icon: Icon(
                 (widget.authService?.currentUser?.pinnedProjectIds?.contains(project.id) ?? false) 
                     ? Icons.push_pin 
                     : Icons.push_pin_outlined
               ),
               onPressed: _togglePinProject,
               tooltip: (widget.authService?.currentUser?.pinnedProjectIds?.contains(project.id) ?? false)
                   ? 'Unpin from Profile'
                   : 'Pin to Profile',
             ),

        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: AnimatedBuilder(
              animation: widget.projectService,
              builder: (context, child) {
                 final currentProject = widget.projectService.projects
                    .firstWhere((p) => p.id == project.id, orElse: () => project);
                 
                 return ListView(
                   padding: const EdgeInsets.all(16),
                   children: [
                     _buildProjectHeader(context),
                     const SizedBox(height: 16),
                     
                     Text('Abstract', style: Theme.of(context).textTheme.titleMedium),
                     const SizedBox(height: 8),
                     Text(currentProject.abstract),
                     const SizedBox(height: 16),
                     
                     if (currentProject.imageUrls.isNotEmpty) ...[
                        Text('Project Images', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        _buildImageGallery(currentProject.imageUrls),
                        const SizedBox(height: 16),
                     ],
                     
                     if (currentProject.youtubeUrl != null && currentProject.youtubeUrl!.isNotEmpty) ...[
                       Text('Project Demo Video', style: Theme.of(context).textTheme.titleMedium),
                       const SizedBox(height: 8),
                       if (kIsWeb)
                         Builder(builder: (context) {
                           final videoId = _extractVideoId(currentProject.youtubeUrl!);
                           if (videoId != null) return buildWebYoutubePlayer(videoId);
                           return _buildInvalidYoutubeCard();
                         })
                       else
                         player ?? (_youtubeController != null ? YoutubePlayer(controller: _youtubeController!, showVideoProgressIndicator: true, progressIndicatorColor: Colors.red,) : _buildInvalidYoutubeCard()),
                       const SizedBox(height: 16),
                     ],
                     
                     if (currentProject.versions.isNotEmpty) ...[
                        Text('Version History', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        _buildVersionHistory(currentProject),
                        const SizedBox(height: 16),
                     ],
                     
                     if (currentProject.feedback.isNotEmpty) ...[
                        Text('Teacher Feedback', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        _buildFeedbackSection(currentProject),
                        const SizedBox(height: 16),
                     ],
                     
                     if (widget.authService?.currentUser?.role == UserRole.student && 
                         currentProject.status == ProjectStatus.needsRevision) ...[
                       _buildRevisionUploadSection(currentProject),
                       const SizedBox(height: 16),
                     ],
                     
                     if (widget.authService?.currentUser != null &&
                        (widget.authService!.currentUser!.role == UserRole.admin ||
                         widget.authService!.currentUser!.role == UserRole.teacher) &&
                        currentProject.submissionType == ProjectSubmissionType.projectShowcase &&
                        (currentProject.status == ProjectStatus.approved || currentProject.status == ProjectStatus.featured)) ...[
                       ShowcaseEvaluationCard(
                         project: currentProject,
                         projectService: widget.projectService,
                         isAdmin: widget.authService!.currentUser!.role == UserRole.admin,
                       ),
                       const SizedBox(height: 16),
                     ],
                     
                     _buildMetaInfoCard(context, currentProject),
                     const SizedBox(height: 16),
                     
                     const Divider(),
                     const SizedBox(height: 8),
                     Text('Reviews', style: Theme.of(context).textTheme.titleMedium),
                     const SizedBox(height: 8),
                     _buildReviewsSection(currentProject),
                   ],
                 );
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _getAwardColor(ProjectAward award) {
    switch (award) {
      case ProjectAward.winner:
        return Colors.amber;
      case ProjectAward.firstRunnerUp:
        return Colors.grey.shade400;
      case ProjectAward.secondRunnerUp:
        return Colors.brown.shade300;
      case ProjectAward.thirdRunnerUp:
        return Colors.brown.shade200;
      default:
        return Colors.grey;
    }
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
        return Colors.amber[700]!;
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
                onTap: () => _showImageDialog(imageUrls, index),
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

  void _showImageDialog(List<String> imageUrls, int initialIndex) {
    showDialog(
      context: context,
      builder: (context) {
        int currentIndex = initialIndex;
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.black,
              insetPadding: const EdgeInsets.all(0),
              child: Stack(
                children: [
                  Center(
                    child: InteractiveViewer(
                      child: Image.network(
                        imageUrls[currentIndex],
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
                  // Close Button
                  Positioned(
                    top: 20,
                    right: 20,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.of(context).pop(),
                        borderRadius: BorderRadius.circular(30),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white24, width: 1),
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Previous Button
                  if (currentIndex > 0)
                    Positioned(
                      left: 20,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: GestureDetector(
                          onTap: () {
                            setState(() => currentIndex--);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white38, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.5),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.arrow_back_ios_new,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Next Button
                  if (currentIndex < imageUrls.length - 1)
                    Positioned(
                      right: 20,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: GestureDetector(
                          onTap: () {
                            setState(() => currentIndex++);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white38, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.5),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.arrow_forward_ios,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Image Counter
                  Positioned(
                    bottom: 30,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(25),
                          border: Border.all(color: Colors.white24, width: 1),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.5),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Text(
                          '${currentIndex + 1} / ${imageUrls.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openPdf(String pdfUrl) async {
    // On web, open PDF directly in browser (SfPdfViewer fails with CORS)
    if (kIsWeb) {
      final uri = Uri.tryParse(pdfUrl);
      if (uri != null && uri.hasScheme) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid PDF URL.')),
          );
        }
      }
      return;
    }

    // Show loading dialog first (mobile only)
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
            actions: [
              IconButton(
                icon: const Icon(Icons.download),
                onPressed: () {
                   canLaunchUrl(Uri.parse(pdfUrl)).then((canLaunch) {
                     if (canLaunch) {
                       launchUrl(Uri.parse(pdfUrl), mode: LaunchMode.externalApplication);
                     } else {
                       ScaffoldMessenger.of(context).showSnackBar(
                         const SnackBar(content: Text('Could not launch PDF download.')),
                       );
                     }
                   });
                },
              ),
            ],
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
                      content: Text('Failed to load PDF in app. Error: ${details.error}\n\nTap "Open" to view in browser.'),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 8),
                      action: SnackBarAction(
                        label: 'Open',
                        textColor: Colors.white,
                        onPressed: () {
                           canLaunchUrl(Uri.parse(pdfUrl)).then((canLaunch) {
                             if (canLaunch) {
                               launchUrl(Uri.parse(pdfUrl), mode: LaunchMode.externalApplication);
                             }
                           });
                        },
                      ),
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

  Future<void> _togglePinProject() async {
    final user = widget.authService?.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in to pin projects')));
      return;
    }

    // Determine current pin state
    final isPinned = user.pinnedProjectIds?.contains(widget.project.id) ?? false;
    
    try {
      final updatedPinnedIds = List<String>.from(user.pinnedProjectIds ?? []);
      if (isPinned) {
        updatedPinnedIds.remove(widget.project.id);
      } else {
        if (updatedPinnedIds.length >= 6) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You can only pin up to 6 projects.')));
           return;
        }
        updatedPinnedIds.add(widget.project.id);
      }

      final updatedUser = user.copyWith(pinnedProjectIds: updatedPinnedIds);
      
      await FirestoreService.updateUser(updatedUser);
      await widget.authService?.updateUserProfile(updatedUser);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isPinned ? 'Project unpinned from profile' : 'Project pinned to profile'),
            backgroundColor: isPinned ? Colors.grey : Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        setState(() {}); 
      }
    } catch (e) {
      debugPrint('Error updating pin: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating pin: $e'), backgroundColor: Colors.red));
      }
    }
  }



  Widget _buildInvalidYoutubeCard() {
    return Card(
      color: Colors.orange[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.orange[700]),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Invalid YouTube URL',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[900],
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'The provided YouTube link could not be loaded.',
                    style: TextStyle(fontSize: 12, color: Colors.orange),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }






  Widget _buildProjectHeader(BuildContext context, {bool isDesktop = false}) {
    final currentProject = widget.project;
    return Card(
      elevation: isDesktop ? 0 : 1,
      margin: EdgeInsets.zero,
      color: isDesktop ? Colors.transparent : null,
      child: Padding(
        padding: isDesktop ? EdgeInsets.zero : const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Award Badge (Visible to All)
            if (currentProject.award != ProjectAward.none) ...[
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _getAwardColor(currentProject.award).withOpacity(0.2),
                      _getAwardColor(currentProject.award).withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _getAwardColor(currentProject.award),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.emoji_events, 
                      color: _getAwardColor(currentProject.award),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      currentProject.award.displayName,
                      style: TextStyle(
                        color: _getAwardColor(currentProject.award),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            Row(
              children: <Widget>[
                Expanded(
                  child: SelectableText( // Use SelectableText for desktop
                    currentProject.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Chip(
                  label: Text(
                    currentProject.status.displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => StudentPortfolioScreen(userId: currentProject.authorId),
                      ),
                    );
                  },
                  child: Text(
                    'By ${currentProject.authorName}',
                    style: const TextStyle(
                      decoration: TextDecoration.underline,
                      color: Colors.blue, // Make it look like a link
                    ),
                  ),
                ),
              ],
            ),
            
            // Show Rejection Reason
            if (currentProject.status == ProjectStatus.rejected && 
                currentProject.rejectionReason != null && 
                currentProject.rejectionReason!.isNotEmpty) ...[ 
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.red.withOpacity(0.4),
                    width: 2,
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
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Rejection Reason',
                          style: TextStyle(
                            color: Colors.red[700],
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        currentProject.rejectionReason!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[800],
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
             // Show supervisor info if available
            if (currentProject.supervisor != null && currentProject.supervisor!.isNotEmpty) ...[
              const SizedBox(height: 8),
              FutureBuilder<List<User>>(
                future: FirestoreService.getAllUsers(),
                builder: (context, snapshot) {
                  User? supervisorUser;
                  if (snapshot.hasData) {
                    try {
                      final teachers = snapshot.data!.where((u) => u.role == UserRole.teacher).toList();
                      supervisorUser = teachers.firstWhere(
                        (user) => user.name == currentProject.supervisor,
                      );
                    } catch (e) { }
                  }

                  return Row(
                    children: [
                      const Icon(Icons.school, size: 16, color: Colors.blue),
                      const SizedBox(width: 4),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(
                              color: Colors.blue[700],
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                            children: [
                              const TextSpan(text: 'Supervisor: '),
                              TextSpan(text: currentProject.supervisor),
                              if (supervisorUser?.designation != null)
                                TextSpan(
                                  text: ' (${supervisorUser!.designation!.displayName})',
                                  style: TextStyle(
                                    fontStyle: FontStyle.italic,
                                    color: Colors.blue[600],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],

            // Show Assistant Teacher Info
            if (currentProject.submissionType == ProjectSubmissionType.academic &&
                currentProject.assistantTeacherId != null &&
                currentProject.assistantTeacherId!.isNotEmpty) ...[
              const SizedBox(height: 8),
              FutureBuilder<User?>(
                future: FirestoreService.getUser(currentProject.assistantTeacherId!),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox.shrink();
                  final assistantUser = snapshot.data!;
                  return Row(
                    children: [
                      Icon(Icons.person_outline, size: 16, color: Colors.teal),
                      const SizedBox(width: 4),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(
                              color: Colors.teal[700],
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                            children: [
                              const TextSpan(text: 'Assistant Teacher: '),
                              TextSpan(text: assistantUser.name),
                              if (assistantUser.designation != null)
                                TextSpan(
                                  text: ' (${assistantUser.designation!.displayName})',
                                  style: TextStyle(
                                    fontStyle: FontStyle.italic,
                                    color: Colors.teal[600],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
            
            // Show faculty (approver) info if available
            if (currentProject.facultyName != null && currentProject.facultyName!.isNotEmpty) ...[
              const SizedBox(height: 8),
              FutureBuilder<User?>(
                future: currentProject.facultyId != null 
                    ? FirestoreService.getUser(currentProject.facultyId!)
                    : null,
                builder: (context, snapshot) {
                  final facultyUser = snapshot.data;
                  return Row(
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
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(
                              color: currentProject.status == ProjectStatus.approved
                                  ? Colors.green[700]
                                  : Colors.orange[700],
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                            children: [
                              TextSpan(
                                text: currentProject.status == ProjectStatus.approved
                                    ? 'Approved by: '
                                    : 'Assigned to: ',
                              ),
                              TextSpan(
                                text: currentProject.facultyName,
                              ),
                              if (facultyUser?.designation != null)
                                TextSpan(
                                  text: ' (${facultyUser!.designation!.displayName})',
                                  style: TextStyle(
                                    fontStyle: FontStyle.italic,
                                    color: currentProject.status == ProjectStatus.approved
                                        ? Colors.green[600]
                                        : Colors.orange[600],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
            // Show Submission Type Info
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  currentProject.submissionType == ProjectSubmissionType.academic
                      ? Icons.school
                      : Icons.public,
                  size: 16,
                  color: Colors.teal,
                ),
                const SizedBox(width: 4),
                Text(
                  '${currentProject.submissionType == ProjectSubmissionType.academic ? 'Academic Submission' : 'Project Showcase'} • ${currentProject.semester.displayName} ${currentProject.year}',
                  style: TextStyle(
                    color: Colors.teal[700],
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            
            // Show Course Name for Academic Projects
            if (currentProject.submissionType == ProjectSubmissionType.academic && 
                currentProject.academicCourse != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.book, size: 16, color: Colors.indigo),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      currentProject.academicCourse!.displayName,
                      style: TextStyle(
                        color: Colors.indigo[700],
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ],

          ],
        ),
      ),
    );
  }

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
  Widget _buildMetaInfoCard(BuildContext context, Project project) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Project Type & Team Type Badges
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
             Chip(label: Text(
               project.category == ProjectCategory.other && project.customCategory != null
                   ? project.customCategory!
                   : project.category.displayName
             )),
             Chip(label: Text(project.year.toString())),
              Chip(
                avatar: Icon(
                  project.projectType == ProjectType.thesis ? Icons.school : Icons.assignment,
                  size: 18,
                  color: project.projectType == ProjectType.thesis ? Colors.purple[900] : Colors.blue[900],
                ),
                label: Text(
                  project.projectType.displayName,
                  style: TextStyle(
                    color: project.projectType == ProjectType.thesis ? Colors.purple[900] : Colors.blue[900],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                backgroundColor: project.projectType == ProjectType.thesis ? Colors.purple[100] : Colors.blue[100],
              ),
              Chip(
                avatar: Icon(
                  project.isGroupProject ? Icons.groups : Icons.person,
                  size: 18,
                  color: project.isGroupProject ? Colors.green[900] : Colors.orange[900],
                ),
                label: Text(
                  project.isGroupProject ? 'Group Project' : 'Individual Project',
                  style: TextStyle(
                    color: project.isGroupProject ? Colors.green[900] : Colors.orange[900],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                backgroundColor: project.isGroupProject ? Colors.green[100] : Colors.orange[100],
              ),
          ],
        ),
        const SizedBox(height: 24),
        
        // Student Info
        if (!project.isGroupProject && project.studentId != null) ...[
          Card(
            margin: EdgeInsets.zero,
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
                  _buildInfoRow('Student ID', project.studentId ?? 'N/A'),
                  if (project.batch != null) _buildInfoRow('Batch', project.batch.toString()),
                  if (project.level != null) _buildInfoRow('Level', project.level.toString()),
                  if (project.term != null) _buildInfoRow('Term', project.term.toString()),
                ],
              ),
            ),
          ),
        ],

        // Group Project Details
        if (project.isGroupProject) ...[
          Card(
            margin: EdgeInsets.zero,
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
                  if (project.groupName != null) _buildInfoRow('Group Name', project.groupName!),
                  _buildInfoRow('Team Size', '${project.teamMembers.length} members'),
                  const SizedBox(height: 12),
                  if (project.teamMembers.isNotEmpty) ...[ 
                    Text(
                      'Team Members:',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...project.teamMembers.asMap().entries.map((entry) {
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
                          title: Text(member.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('ID: ${member.id}'),
                          dense: true,
                        ),
                      );
                    }).toList(),
                  ],
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        
        // Action Buttons
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            if (project.driveLink != null && project.driveLink!.isNotEmpty)
              FilledButton.icon(
                onPressed: () => _openDriveLink(project.driveLink!),
                icon: const Icon(Icons.cloud),
                label: const Text('View Drive'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                ),
              ),
            if (project.pdfUrl != null && project.pdfUrl!.isNotEmpty)
              FilledButton.icon(
                onPressed: () => _openPdf(project.pdfUrl!),
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Open PDF'),
              ),
            if (project.githubUrl != null && project.githubUrl!.isNotEmpty)
              OutlinedButton.icon(
                onPressed: () => _openGitHub(project.githubUrl!),
                icon: const Icon(Icons.code),
                label: const Text('GitHub'),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildReviewsSection(Project project) {
    // We access projectService.reviews from here, filtered by project ID
    final projectReviews = widget.projectService.reviews
        .where((r) => r.projectId == project.id)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (projectReviews.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No reviews yet. Be the first to review!',
              style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
            ),
          )
        else
          ...projectReviews.map((review) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                         // Avatar
                        CircleAvatar(
                          radius: 16,
                          child: Text(review.reviewerName[0].toUpperCase()),
                        ),
                        const SizedBox(width: 8),
                        Text(review.reviewerName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        const Spacer(),
                        Row(
                          children: [
                            const Icon(Icons.star, size: 14, color: Colors.amber),
                            const SizedBox(width: 2),
                            Text(review.rating.toStringAsFixed(1)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(review.comment),
                    const SizedBox(height: 4),
                    Text(
                      '${review.createdAt.day}/${review.createdAt.month}/${review.createdAt.year}',
                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
          )).toList(),
          
        const SizedBox(height: 16),
        // Add Review Input - Hide for students AND pending projects
        if (widget.authService?.currentUser?.role != UserRole.student &&
            (project.status == ProjectStatus.approved || project.status == ProjectStatus.featured))
          Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Write a Review', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Rating: '),
                    RatingBar(
                      rating: _rating,
                      onRatingChanged: (rating) {
                        setState(() {
                          _rating = rating;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        maxLines: 3,
                        minLines: 1,
                        decoration: const InputDecoration(
                          hintText: 'Write your review...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: _isSubmitting ? null : _submitReview,
                      child: _isSubmitting ? const CircularProgressIndicator(color: Colors.white) : const Text('Post'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

}

class RatingBar extends StatelessWidget {
  final double rating;
  final ValueChanged<double> onRatingChanged;

  const RatingBar({super.key, required this.rating, required this.onRatingChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return IconButton(
          onPressed: () => onRatingChanged(index + 1.0),
          icon: Icon(
            index < rating ? Icons.star : Icons.star_border,
            color: Colors.amber,
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        );
      }),
    );
  }
}

class CustomYoutubePlayerBuilder extends StatefulWidget {
  final Widget player;
  final Widget Function(BuildContext, Widget) builder;
  final YoutubePlayerController controller;

  const CustomYoutubePlayerBuilder({
    Key? key,
    required this.player,
    required this.builder,
    required this.controller,
  }) : super(key: key);

  @override
  State<CustomYoutubePlayerBuilder> createState() =>
      _CustomYoutubePlayerBuilderState();
}

class _CustomYoutubePlayerBuilderState extends State<CustomYoutubePlayerBuilder> {
  bool _isFullScreen = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_listener);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_listener);
    super.dispose();
  }

  void _listener() {
    if (widget.controller.value.isFullScreen && !_isFullScreen) {
      if (mounted) {
        setState(() => _isFullScreen = true);
        _pushFullScreen();
      }
    } else if (!widget.controller.value.isFullScreen && _isFullScreen) {
      if (mounted) {
        setState(() => _isFullScreen = false);
        Navigator.of(context).maybePop();
      }
    }
  }

  void _pushFullScreen() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => Scaffold(
          backgroundColor: Colors.black,
          body: Center(child: widget.player),
        ),
        transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
      ),
    ).then((_) {
      if (mounted) {
        if (widget.controller.value.isFullScreen) {
          widget.controller.toggleFullScreenMode();
        }
        setState(() => _isFullScreen = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isFullScreen) {
      return widget.builder(context, Container(color: Colors.black));
    }
    return widget.builder(context, widget.player);
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
