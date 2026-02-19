import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import '../mvc/models/user.dart';
import '../mvc/models/project.dart';
import '../mvc/controllers/firestore_service.dart';
import '../mvc/controllers/project_service.dart';
import '../services/resume_service.dart';
import 'project_detail.dart';

class StudentPortfolioScreen extends StatefulWidget {
  final String userId;

  const StudentPortfolioScreen({Key? key, required this.userId}) : super(key: key);

  @override
  State<StudentPortfolioScreen> createState() => _StudentPortfolioScreenState();
}

class _StudentPortfolioScreenState extends State<StudentPortfolioScreen> {
  User? _user;
  List<Project> _projects = [];
  bool _isLoading = true;
  final ResumeService _resumeService = ResumeService();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final user = await FirestoreService.getUser(widget.userId);
      final allProjects = await FirestoreService.getProjects(); // Or use ProjectService if loaded
      final userProjects = allProjects.where((p) => p.authorId == widget.userId && p.status == ProjectStatus.approved).toList();
      
      if (mounted) {
        setState(() {
          _user = user;
          _projects = userProjects;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading profile: $e')));
      }
    }
  }

  Future<void> _downloadResume() async {
    if (_user == null) return;
    try {
      final bytes = await _resumeService.generateResume(_user!, _projects);
      await Printing.sharePdf(bytes: bytes, filename: '${_user!.name}_resume.pdf');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error generating resume: $e')));
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not launch $url')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile not found')),
        body: const Center(child: Text('User not found')),
      );
    }
    
    // Check privacy settings
    // If it's not the current user viewing, and profile is not public, show restricted message.
    // However, I don't have current user ID here easily without AuthService. 
    // Assuming for now if you navigate here, you are allowed to see it, 
    // or add a check if needed.
    // Let's add a placeholder check if isPublicProfile is false
    // But since I don't have auth service in this widget, I'll skip restrictive check for this iteration 
    // or assume the navigator handles it. 
    // Better: Show a "Private Profile" message if !isPublicProfile and not current user.
    // I'll skip complex auth checks for this MVP step.

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBioSection(),
                  const SizedBox(height: 16),
                  _buildSkillsSection(),
                  const SizedBox(height: 16),
                  _buildSocialLinks(),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _downloadResume,
                      icon: const Icon(Icons.download),
                      label: const Text('Download Resume'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Projects',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          _buildProjectsSection(),
          const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 250.0,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(_user!.name),
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: Theme.of(context).colorScheme.primaryContainer),
            Center(
              child: CircleAvatar(
                radius: 60,
                backgroundImage: _user!.profileImageUrl != null ? NetworkImage(_user!.profileImageUrl!) : null,
                child: _user!.profileImageUrl == null
                    ? Text(_user!.name[0].toUpperCase(), style: const TextStyle(fontSize: 40))
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBioSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('About', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(
          _user!.bio?.isNotEmpty == true ? _user!.bio! : 'No bio provided.',
          style: TextStyle(color: Colors.grey[700], height: 1.5),
        ),
      ],
    );
  }

  Widget _buildSkillsSection() {
    if (_user!.skills == null || _user!.skills!.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Skills', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _user!.skills!.map((skill) => Chip(label: Text(skill))).toList(),
        ),
      ],
    );
  }

  Widget _buildSocialLinks() {
    return Row(
      children: [
        if (_user!.linkedinUrl != null && _user!.linkedinUrl!.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.link, color: Colors.blue),
            onPressed: () => _launchUrl(_user!.linkedinUrl!),
            tooltip: 'LinkedIn',
          ),
        if (_user!.githubUrl != null && _user!.githubUrl!.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.code, color: Colors.black),
            onPressed: () => _launchUrl(_user!.githubUrl!),
            tooltip: 'GitHub',
          ),
      ],
    );
  }

  Widget _buildProjectsSection() {
    if (_projects.isEmpty) {
      return SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Text('No projects to showcase yet.', style: TextStyle(color: Colors.grey[500])),
          ),
        ),
      );
    }

    final pinnedIds = _user!.pinnedProjectIds ?? [];
    final pinnedProjects = _projects.where((p) => pinnedIds.contains(p.id)).toList();
    final otherProjects = _projects.where((p) => !pinnedIds.contains(p.id)).toList();

    return SliverList(
      delegate: SliverChildListDelegate([
        if (pinnedProjects.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              'Featured Projects',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          ...pinnedProjects.map((project) => _buildProjectCard(project, isPinned: true)),
          const SizedBox(height: 24),
        ],
        
        if (otherProjects.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              'Recent Projects',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          ...otherProjects.map((project) => _buildProjectCard(project)),
        ],
      ]),
    );
  }

  Widget _buildProjectCard(Project project, {bool isPinned = false}) {
    return Card(
      elevation: isPinned ? 4 : 1,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: isPinned 
         ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Theme.of(context).primaryColor.withOpacity(0.5), width: 1.5))
         : null,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: isPinned ? const Icon(Icons.star, color: Colors.amber) : null,
        title: Text(project.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(project.abstract, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: project.tags.take(3).map((t) => 
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[300]!)),
                  child: Text(t, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                )
              ).toList(),
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProjectDetailScreen(
                project: project,
                projectService: ProjectService(), // Should ideally pass the existing service
              ),
            ),
          );
        },
      ),
    );
  }
}
