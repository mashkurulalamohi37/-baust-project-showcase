import 'package:flutter/material.dart';
import '../mvc/models/project.dart';
import '../mvc/controllers/project_service.dart';
import '../mvc/controllers/auth_service.dart';
import 'project_detail.dart';
import '../../services/export_service.dart';

class SemesterArchiveScreen extends StatefulWidget {
  const SemesterArchiveScreen({super.key});

  @override
  State<SemesterArchiveScreen> createState() => _SemesterArchiveScreenState();
}

class _SemesterArchiveScreenState extends State<SemesterArchiveScreen> {
  final ProjectService _projectService = ProjectService();
  ProjectSubmissionType? _selectedSubmissionType;
  AcademicCourse? _selectedAcademicCourse;

  // Gets unique (Year, Semester) pairs and counts projects
  Map<String, List<Project>> _groupProjectsBySemester() {
    final Map<String, List<Project>> grouped = {};
    
    for (var project in _projectService.projects) {
      // Only show visible projects in the archive
      if (project.status != ProjectStatus.approved && 
          project.status != ProjectStatus.featured) {
        continue;
      }

      // Filter based on selection
      if (_selectedSubmissionType != null) {
        if (project.submissionType != _selectedSubmissionType) {
           // Handle legacy projects (assume showcase if submissionType is null/default) - though new model has default.
           // But wait, existing projects in JSON might not have the field.
           // However, Project model default is projectShowcase, so it should be fine if serialized correctly.
           // But standard json deserialization won't use default value if field is missing unless customized.
           // Assuming data migration or default handling is in place or not needed for now directly.
           // Actually, since I added the field to the class, runtime objects will have the default.
           continue; 
        }
      } else {
        // If nothing selected (shouldn't happen in this view function usage usually), maybe return all?
        // But the UI logic will separate them.
      }

      if (_selectedSubmissionType == ProjectSubmissionType.academic && 
          _selectedAcademicCourse != null) {
        if (project.academicCourse != _selectedAcademicCourse) {
          continue;
        }
      }

      final key = '${project.semester.displayName} ${project.year}';
      if (!grouped.containsKey(key)) {
        grouped[key] = [];
      }
      grouped[key]!.add(project);
    }
    
    return grouped;
  }

  void _resetSelection() {
    setState(() {
      _selectedAcademicCourse = null;
      _selectedSubmissionType = null;
    });
  }

  void _selectSubmissionType(ProjectSubmissionType type) {
    setState(() {
      _selectedSubmissionType = type;
      _selectedAcademicCourse = null;
    });
  }

  void _selectCourse(AcademicCourse course) {
    setState(() {
      _selectedAcademicCourse = course;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Top Level: Select Type
    if (_selectedSubmissionType == null) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text('Project Archives', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          elevation: 0,
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
          actions: [
            const SizedBox(width: 16),
          ],
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Theme.of(context).colorScheme.surface,
                Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
              ],
            ),
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 100, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  Text(
                    'Explore Collections',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Browse through years of student innovation and academic excellence.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildSelectionCard(
                    'Project Showcase',
                    Icons.rocket_launch_outlined,
                    const LinearGradient(
                      colors: [Color(0xFF2C3E50), Color(0xFF4CA1AF)], // Dark Slate to Blue Gray
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    () => _selectSubmissionType(ProjectSubmissionType.projectShowcase),
                    'Creative projects, hackathons, and innovative showcases.',
                  ),
                  const SizedBox(height: 16),
                  _buildSelectionCard(
                    'Academic Research',
                    Icons.school_outlined,
                    const LinearGradient(
                      colors: [Color(0xFF141E30), Color(0xFF243B55)], // Royal Navy
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    () => _selectSubmissionType(ProjectSubmissionType.academic),
                    'Course projects, thesis work, and academic research.',
                  ),
                  // Add extra padding at bottom to ensure last card is fully visible/touchable above nav bar/safe area if needed
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Academic Level: Select Course
    if (_selectedSubmissionType == ProjectSubmissionType.academic && _selectedAcademicCourse == null) {
       return PopScope(
         canPop: false,
         onPopInvokedWithResult: (didPop, result) {
           if (didPop) return;
           setState(() => _selectedSubmissionType = null);
         },
         child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text('Academic Courses', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          elevation: 0,
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => setState(() => _selectedSubmissionType = null),
          ),
          automaticallyImplyLeading: false,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF232526),
                  Color(0xFF414345),
                ],
              ),
            ),
          ),
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Theme.of(context).colorScheme.surface,
                Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
              ],
            ),
          ),
          child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 100, 20, 20),
          itemCount: AcademicCourse.values.length,
          itemBuilder: (context, index) {
            final course = AcademicCourse.values[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.3),
                ),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF141E30), Color(0xFF243B55)], // Royal Navy
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.book_outlined,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                title: Text(
                  course.displayName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                subtitle: const Text('View projects'),
                trailing: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                onTap: () => _selectCourse(course),
              ),
            );
          },
        ),
        ),
       ),
      );
    }

    // Archive Grid View (Filtered)
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

    String title = 'Project Archives';
    if (_selectedSubmissionType == ProjectSubmissionType.projectShowcase) {
      title = 'Project Showcase';
    } else if (_selectedAcademicCourse != null) {
      title = _selectedAcademicCourse!.displayName;
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_selectedSubmissionType == ProjectSubmissionType.academic && _selectedAcademicCourse != null) {
          setState(() => _selectedAcademicCourse = null);
        } else {
          setState(() => _selectedSubmissionType = null);
        }
      },
      child: Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (_selectedSubmissionType == ProjectSubmissionType.academic && _selectedAcademicCourse != null) {
              setState(() => _selectedAcademicCourse = null);
            } else {
              setState(() => _selectedSubmissionType = null);
            }
          },
        ),
        automaticallyImplyLeading: false,
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
        actions: [
          const SizedBox(width: 16),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Theme.of(context).colorScheme.surface,
                Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
              ],
            ),
        ),
        child: groupedProjects.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                     Icon(Icons.archive_outlined, size: 80, color: Theme.of(context).colorScheme.outline.withOpacity(0.5)),
                     const SizedBox(height: 16),
                     Text(
                       'No archives found',
                       style: Theme.of(context).textTheme.titleLarge?.copyWith(
                         color: Theme.of(context).colorScheme.onSurfaceVariant,
                       ),
                     ),
                  ],
                ),
              )
            : GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 120, 16, 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.9,
              ),
              itemCount: keys.length,
              itemBuilder: (context, index) {
                final key = keys[index];
                final projects = groupedProjects[key]!;
                final parts = key.split(' ');
                final semesterName = parts[0];
                final year = parts.length > 1 ? parts[1] : '';
                
                final isSummer = semesterName == 'Summer';

                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: (isSummer ? Colors.orange : Colors.blue).withOpacity(0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Material(
                    clipBehavior: Clip.antiAlias,
                    borderRadius: BorderRadius.circular(24),
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
                            colors: isSummer
                                ? [const Color(0xFF667EEA), const Color(0xFF764BA2)] // Purple Dream
                                : [const Color(0xFF11998E), const Color(0xFF38EF7D)], // Emerald Teal
                          ),
                        ),
                        child: Stack(
                          children: [
                            Positioned(
                              right: -20,
                              top: -20,
                              child: Icon(
                                isSummer ? Icons.wb_sunny : Icons.ac_unit,
                                size: 100,
                                color: Colors.white.withOpacity(0.15),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.25),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      isSummer ? Icons.wb_sunny : Icons.ac_unit,
                                      size: 24,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    semesterName,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    year,
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.white.withOpacity(0.9),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '${projects.length} Projects',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
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
      ),
      ),
    );
  }

  Widget _buildSelectionCard(String title, IconData icon, Gradient gradient, VoidCallback onTap, String subtitle) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: gradient,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(icon, size: 28, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SemesterProjectsScreen extends StatefulWidget {
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
  State<SemesterProjectsScreen> createState() => _SemesterProjectsScreenState();
}

class _SemesterProjectsScreenState extends State<SemesterProjectsScreen> {
  final ProjectService _projectService = ProjectService();
  bool _isExporting = false;

  Future<void> _showExportFilterDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Export Projects'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Theme.of(context).cardColor,
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'all'),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text('All Projects'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'accepted'),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text('Accepted Projects Only'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'rejected'),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text('Rejected Projects Only'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'decided'),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text('Consolidated (Accepted + Rejected)'),
            ),
          ),
        ],
      ),
    );

    if (result != null) {
      _exportProjects(result);
    }
  }

  Future<void> _exportProjects(String filter) async {
    setState(() => _isExporting = true);
    try {
      // Fetch ALL projects from service to include rejected ones which might be hidden in main view
      final allProjects = _projectService.projects;
      List<Project> projectsToExport = [];

      for (var project in allProjects) {
        // 1. Filter by Semester and Year
        if (project.semester.displayName != widget.semesterName || project.year != widget.year) {
          continue;
        }

        // 2. Apply Status Filter
        if (filter == 'accepted' && project.status != ProjectStatus.approved) continue;
        if (filter == 'rejected' && project.status != ProjectStatus.rejected) continue;
        if (filter == 'decided' && 
            project.status != ProjectStatus.approved && 
            project.status != ProjectStatus.rejected) {
          continue;
        }

        projectsToExport.add(project);
      }

      debugPrint('SemesterProjectsScreen: Found ${allProjects.length} total projects, filtering for $filter for ${widget.semesterName} ${widget.year} -> ${projectsToExport.length} projects to export');

      if (projectsToExport.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No projects found matching criteria')),
          );
        }
        return;
      }

      final capitalizedFilter = filter[0].toUpperCase() + filter.substring(1);
      final fileName = '${widget.semesterName}_${widget.year}_Projects_$capitalizedFilter.csv';
      await ExportService.exportProjects(projectsToExport, fileName: fileName);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export completed successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Sort projects: Winners first, then others
    final sortedProjects = List<Project>.from(widget.projects)..sort((a, b) {
      if (a.award != ProjectAward.none && b.award == ProjectAward.none) return -1;
      if (a.award == ProjectAward.none && b.award != ProjectAward.none) return 1;
      if (a.award != ProjectAward.none && b.award != ProjectAward.none) {
        return a.award.index.compareTo(b.award.index);
      }
      return b.rating.compareTo(a.rating); // Fallback: Sort by rating
    });

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          '${widget.semesterName} ${widget.year} Projects',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF232526),
                Color(0xFF414345),
              ],
            ),
          ),
        ),
        actions: [
          if (AuthService().isAdmin || AuthService().isTeacher)
            IconButton(
              icon: _isExporting 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.download, color: Colors.white),
              onPressed: _isExporting ? null : _showExportFilterDialog,
              tooltip: 'Export Semester Data',
            ),
          const SizedBox(width: 16),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.surface,
              Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
            ],
          ),
        ),
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 100, 16, 16),
          itemCount: sortedProjects.length,
          itemBuilder: (context, index) {
            final project = sortedProjects[index];
            final awardInfo = _getAwardInfo(project.award);
            final hasAward = project.award != ProjectAward.none;
            
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: hasAward
                    ? [
                        BoxShadow(
                          color: awardInfo.color.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                          spreadRadius: 2,
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
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
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: hasAward
                          ? LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                awardInfo.color.withOpacity(0.15),
                                awardInfo.color.withOpacity(0.05),
                              ],
                            )
                          : null,
                      color: hasAward ? null : Theme.of(context).colorScheme.surfaceContainer,
                      border: hasAward
                          ? Border.all(
                              color: awardInfo.color.withOpacity(0.5),
                              width: 2.5,
                            )
                          : Border.all(
                              color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.3),
                              width: 1,
                            ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          // Leading Icon/Avatar
                          if (hasAward)
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    awardInfo.color,
                                    awardInfo.color.withOpacity(0.7),
                                  ],
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: awardInfo.color.withOpacity(0.4),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Icon(
                                awardInfo.icon,
                                color: Colors.white,
                                size: 32,
                              ),
                            )
                          else
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primaryContainer,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  project.title.isNotEmpty ? project.title.substring(0, 1).toUpperCase() : '?',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(width: 16),
                          
                          // Content
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Title
                                Text(
                                  project.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: hasAward ? 17 : 16,
                                    color: hasAward
                                        ? Theme.of(context).colorScheme.onSurface
                                        : null,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                
                                // Author and Award Badge Row
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'By ${project.authorName}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                          fontWeight: hasAward ? FontWeight.w500 : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                    if (hasAward) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              awardInfo.color,
                                              awardInfo.color.withOpacity(0.8),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(6),
                                          boxShadow: [
                                            BoxShadow(
                                              color: awardInfo.color.withOpacity(0.4),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Text(
                                          project.award.displayName,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 8),
                                
                                // Rating and Category
                                Row(
                                  children: [
                                    Icon(
                                      Icons.star,
                                      size: 16,
                                      color: hasAward ? awardInfo.color : Colors.amber,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      project.rating.toStringAsFixed(1),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: hasAward ? awardInfo.color : null,
                                      ),
                                    ),
                                    if (project.reviewCount > 0) ...[
                                      Text(
                                        ' (${project.reviewCount})',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(width: 12),
                                    Flexible(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: hasAward
                                              ? awardInfo.color.withOpacity(0.2)
                                              : Theme.of(context).colorScheme.secondaryContainer,
                                          borderRadius: BorderRadius.circular(6),
                                          border: hasAward
                                              ? Border.all(
                                                  color: awardInfo.color.withOpacity(0.4),
                                                  width: 1,
                                                )
                                              : null,
                                        ),
                                        child: Text(
                                          project.category.displayName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: hasAward
                                                ? awardInfo.color
                                                : Theme.of(context).colorScheme.onSecondaryContainer,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          
                          // Trailing Arrow
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 20,
                            color: hasAward
                                ? awardInfo.color
                                : Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  ({Color color, IconData icon, Gradient gradient}) _getAwardInfo(ProjectAward award) {
    switch (award) {
      case ProjectAward.winner:
        return (
          color: const Color(0xFFFFB800), // Rich Gold
          icon: Icons.emoji_events,
          gradient: const LinearGradient(
            colors: [Color(0xFFFFD700), Color(0xFFFFB800)],
          ),
        );
      case ProjectAward.firstRunnerUp:
        return (
          color: const Color(0xFFA8A8A8), // Polished Silver
          icon: Icons.emoji_events,
          gradient: const LinearGradient(
            colors: [Color(0xFFC0C0C0), Color(0xFFA8A8A8)],
          ),
        );
      case ProjectAward.secondRunnerUp:
        return (
          color: const Color(0xFFB87333), // Rich Bronze
          icon: Icons.emoji_events,
          gradient: const LinearGradient(
            colors: [Color(0xFFCD7F32), Color(0xFFB87333)],
          ),
        );
      case ProjectAward.thirdRunnerUp:
        return (
          color: const Color(0xFF4A90E2), // Premium Blue
          icon: Icons.workspace_premium,
          gradient: const LinearGradient(
            colors: [Color(0xFF5B9FED), Color(0xFF4A90E2)],
          ),
        );
      default:
        return (
          color: Colors.grey,
          icon: Icons.star,
          gradient: const LinearGradient(
            colors: [Colors.grey, Colors.grey],
          ),
        );
    }
  }
}
