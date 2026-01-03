import 'package:flutter/material.dart';
import '../mvc/models/project.dart';
import '../mvc/controllers/project_service.dart';
import '../mvc/controllers/auth_service.dart';
import 'project_detail.dart';

class SemesterArchiveScreen extends StatefulWidget {
  const SemesterArchiveScreen({super.key});

  @override
  State<SemesterArchiveScreen> createState() => _SemesterArchiveScreenState();
}

class _SemesterArchiveScreenState extends State<SemesterArchiveScreen> {
  final ProjectService _projectService = ProjectService();
  
  // Gets unique (Year, Semester) pairs and counts projects
  Map<String, List<Project>> _groupProjectsBySemester() {
    final Map<String, List<Project>> grouped = {};
    
    for (var project in _projectService.projects) {
      // Only show visible projects in the archive
      if (project.status != ProjectStatus.approved && 
          project.status != ProjectStatus.featured) {
        continue;
      }

      final key = '${project.semester.displayName} ${project.year}';
      if (!grouped.containsKey(key)) {
        grouped[key] = [];
      }
      grouped[key]!.add(project);
    }
    
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final groupedProjects = _groupProjectsBySemester();
    final keys = groupedProjects.keys.toList()
      ..sort((a, b) {
        final partsA = a.split(' ');
        final partsB = b.split(' ');
        if (partsA.length < 2 || partsB.length < 2) return 0;
        
        final yearA = int.tryParse(partsA[1]) ?? 0;
        final yearB = int.tryParse(partsB[1]) ?? 0;
        if (yearA != yearB) return yearB.compareTo(yearA);
        
        return (partsA[0] == 'Summer' ? 1 : 0).compareTo(partsB[0] == 'Summer' ? 1 : 0);
      });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Project Archives'),
      ),
      body: groupedProjects.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Icon(Icons.archive_outlined, size: 64, color: Colors.grey),
                   SizedBox(height: 16),
                   Text('No archives found'),
                ],
              ),
            )
      : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.0, // Increased height ratio to prevent overflow
              ),
              itemCount: keys.length,
              itemBuilder: (context, index) {
                final key = keys[index];
                final projects = groupedProjects[key]!;
                final parts = key.split(' ');
                final semesterName = parts[0];
                final year = parts.length > 1 ? parts[1] : '';

                return Card(
                  elevation: 2,
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SemesterProjectsScreen(
                            semesterName: semesterName,
                            year: int.tryParse(year) ?? 0,
                            projects: projects,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: semesterName == 'Summer'
                              ? [Colors.orange.shade100, Colors.orange.shade50]
                              : [Colors.blue.shade100, Colors.blue.shade50],
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              semesterName == 'Summer' ? Icons.wb_sunny : Icons.ac_unit,
                              size: 40,
                              color: semesterName == 'Summer' ? Colors.orange[800] : Colors.blue[800],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              key,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${projects.length} Projects',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class SemesterProjectsScreen extends StatelessWidget {
  final String semesterName;
  final int year;
  final List<Project> projects;

  const SemesterProjectsScreen({
    super.key,
    required this.semesterName,
    required this.year,
    required this.projects,
  });

  @override
  Widget build(BuildContext context) {
    // Sort projects: Winners first, then others
    final sortedProjects = List<Project>.from(projects)..sort((a, b) {
      if (a.award != ProjectAward.none && b.award == ProjectAward.none) return -1;
      if (a.award == ProjectAward.none && b.award != ProjectAward.none) return 1;
      if (a.award != ProjectAward.none && b.award != ProjectAward.none) {
        return a.award.index.compareTo(b.award.index);
      }
      return b.rating.compareTo(a.rating); // Fallback: Sort by rating
    });

    return Scaffold(
      appBar: AppBar(
        title: Text('$semesterName $year Projects'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: sortedProjects.length,
        itemBuilder: (context, index) {
          final project = sortedProjects[index];
          final awardInfo = _getAwardInfo(project.award);
          
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: project.award != ProjectAward.none ? 4 : 1,
            shape: project.award != ProjectAward.none 
                ? RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: awardInfo.color, width: 2),
                  )
                : null,
            child: ListTile(
              leading: project.award != ProjectAward.none
                  ? CircleAvatar(
                      backgroundColor: awardInfo.color.withOpacity(0.2),
                      child: Icon(awardInfo.icon, color: awardInfo.color),
                    )
                  : CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      child: Text(
                        project.title.isNotEmpty ? project.title.substring(0, 1).toUpperCase() : '?',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
              title: Row(
                children: [
                   Expanded(
                     child: Text(
                       project.title,
                       maxLines: 1,
                       overflow: TextOverflow.ellipsis,
                       style: const TextStyle(fontWeight: FontWeight.bold),
                     ),
                   ),
                   if (project.award != ProjectAward.none) ...[
                     const SizedBox(width: 8),
                     Container(
                       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                       decoration: BoxDecoration(
                         color: awardInfo.color.withOpacity(0.1),
                         borderRadius: BorderRadius.circular(4),
                         border: Border.all(color: awardInfo.color, width: 1),
                       ),
                       child: Text(
                         project.award.displayName,
                         style: TextStyle(
                           fontSize: 10,
                           color: awardInfo.color,
                           fontWeight: FontWeight.bold,
                         ),
                       ),
                     ),
                   ],
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('By ${project.authorName}'),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                       const Icon(Icons.star, size: 14, color: Colors.amber),
                       Text(' ${project.rating.toStringAsFixed(1)}'),
                       const SizedBox(width: 12),
                       Container(
                         padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                         decoration: BoxDecoration(
                           color: Theme.of(context).colorScheme.secondaryContainer,
                           borderRadius: BorderRadius.circular(4),
                         ),
                         child: Text(
                           project.category.displayName,
                           style: TextStyle(
                             fontSize: 10,
                             color: Theme.of(context).colorScheme.onSecondaryContainer,
                             fontWeight: FontWeight.w500,
                           ),
                         ),
                       ),
                    ],
                  ),
                ],
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProjectDetailScreen(
                      project: project,
                      projectService: ProjectService(),
                      authService: AuthService(),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  ({Color color, IconData icon}) _getAwardInfo(ProjectAward award) {
    switch (award) {
      case ProjectAward.winner:
        return (color: const Color(0xFFFFD700), icon: Icons.emoji_events); // Gold
      case ProjectAward.firstRunnerUp:
        return (color: const Color(0xFFC0C0C0), icon: Icons.emoji_events); // Silver
      case ProjectAward.secondRunnerUp:
        return (color: const Color(0xFFCD7F32), icon: Icons.emoji_events); // Bronze
      case ProjectAward.thirdRunnerUp:
        return (color: Colors.blue, icon: Icons.workspace_premium);
      default:
        return (color: Colors.grey, icon: Icons.star);
    }
  }
}
