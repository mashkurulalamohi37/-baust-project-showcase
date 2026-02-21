import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import '../mvc/models/project.dart';
import '../mvc/models/user.dart';
import '../mvc/models/team_member.dart';
import '../mvc/controllers/project_service.dart';
import '../mvc/controllers/auth_service.dart';

class ProjectForm extends StatefulWidget {
  final Project? initialProject;
  final ProjectService projectService;
  final AuthService authService;
  final VoidCallback? onSuccess;

  const ProjectForm({
    super.key,
    this.initialProject,
    required this.projectService,
    required this.authService,
    this.onSuccess,
  });

  @override
  State<ProjectForm> createState() => _ProjectFormState();
}

class _ProjectFormState extends State<ProjectForm> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _titleController = TextEditingController();
  final _abstractController = TextEditingController();
  final _yearController = TextEditingController();
  final _githubController = TextEditingController();
  final _customCategoryController = TextEditingController();
  final _groupNameController = TextEditingController();
  final _studentIdController = TextEditingController();
  final _batchController = TextEditingController();
  final _levelController = TextEditingController();
  final _termController = TextEditingController();
  final _driveLinkController = TextEditingController();
  final _youtubeLinkController = TextEditingController();
  final _supervisorController = TextEditingController();
  
  final List<Map<String, TextEditingController>> _teamMemberControllers = [];
  
  // Form State
  ProjectSubmissionType _submissionType = ProjectSubmissionType.projectShowcase;
  AcademicCourse? _selectedAcademicCourse;
  String? _selectedAssistantTeacherId;
  ProjectCategory _selectedCategory = ProjectCategory.other;
  ProjectType _selectedProjectType = ProjectType.project;
  Semester _selectedSemester = Semester.winter;
  bool _isGroupProject = false;
  int _numberOfMembers = 2;
  
  // File State
  final List<String> _selectedImagePaths = [];
  List<Uint8List> _selectedImageBytes = [];
  String? _selectedPdfPath;
  Uint8List? _selectedPdfBytes;
  
  // Existing URLs (for Edit mode)
  List<String> _existingImageUrls = [];
  String? _existingPdfUrl;
  
  // Support Data
  List<User> _approvedTeachers = [];
  String? _selectedTeacherId;
  bool _isLoadingTeachers = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadTeachers();
    if (widget.initialProject != null) {
      _prefillForm(widget.initialProject!);
    } else {
      _initializeTeamMembers();
      _yearController.text = DateTime.now().year.toString();
    }
  }

  void _prefillForm(Project project) {
    _titleController.text = project.title;
    _abstractController.text = project.abstract;
    _yearController.text = project.year.toString();
    _githubController.text = project.githubUrl ?? '';
    _customCategoryController.text = project.customCategory ?? '';
    _groupNameController.text = project.groupName ?? '';
    _studentIdController.text = project.studentId ?? '';
    _batchController.text = project.batch?.toString() ?? '';
    _levelController.text = project.level?.toString() ?? '';
    _termController.text = project.term?.toString() ?? '';
    _driveLinkController.text = project.driveLink ?? '';
    _youtubeLinkController.text = project.youtubeUrl ?? '';
    
    _submissionType = project.submissionType;
    _selectedAcademicCourse = project.academicCourse;
    _selectedAssistantTeacherId = project.assistantTeacherId;
    _selectedCategory = project.category;
    _selectedProjectType = project.projectType;
    _selectedSemester = project.semester;
    _isGroupProject = project.isGroupProject;
    _numberOfMembers = project.teamMembers.isEmpty ? 2 : project.teamMembers.length;
    
    _selectedTeacherId = project.facultyId;
    _supervisorController.text = project.supervisor ?? ''; 

    // Handle existing files
    _existingImageUrls = List.from(project.imageUrls);
    _existingPdfUrl = project.pdfUrl;
    
    if (_existingPdfUrl != null) {
      _selectedPdfPath = 'Existing PDF';
    }

    _initializeTeamMembers(initialMembers: project.teamMembers);
  }

  void _initializeTeamMembers({List<TeamMember>? initialMembers}) {
    _teamMemberControllers.clear();
    int count = initialMembers?.length ?? _numberOfMembers;
    for (int i = 0; i < count; i++) {
      final member = initialMembers != null && i < initialMembers.length ? initialMembers[i] : null;
      _teamMemberControllers.add({
        'name': TextEditingController(text: member?.name ?? ''),
        'id': TextEditingController(text: member?.id ?? ''),
        'batch': TextEditingController(text: member?.batch.toString() ?? ''),
        'level': TextEditingController(text: member?.level.toString() ?? ''),
        'term': TextEditingController(text: member?.term.toString() ?? ''),
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _abstractController.dispose();
    _yearController.dispose();
    _githubController.dispose();
    _customCategoryController.dispose();
    _groupNameController.dispose();
    _studentIdController.dispose();
    _batchController.dispose();
    _levelController.dispose();
    _termController.dispose();
    _driveLinkController.dispose();
    _youtubeLinkController.dispose();
    _supervisorController.dispose();
    for (var controllers in _teamMemberControllers) {
      for (var c in controllers.values) {
        c.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _loadTeachers() async {
    if (!mounted) return;
    setState(() => _isLoadingTeachers = true);
    try {
      final teachers = await widget.authService.getUsersByRole(UserRole.teacher);
      final approved = teachers.where((teacher) => 
        teacher.isApproved && teacher.id != widget.authService.currentUser?.id
      ).toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      if (mounted) {
        setState(() {
          _approvedTeachers = approved;
          _isLoadingTeachers = false;
        });
      }
    } catch (e) {
      debugPrint('ProjectForm: Error loading teachers $e');
      if (mounted) {
        setState(() => _isLoadingTeachers = false);
      }
    }
  }

  Future<void> _pickImages() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'webp'],
      );
      if (result != null) {
        if (result.files.length > 5) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Maximum 5 images allowed.')),
            );
          }
          return;
        }
        
        setState(() {
          if (kIsWeb) {
            _selectedImageBytes = result.files.map((e) => e.bytes!).toList();
            _selectedImagePaths.clear();
            _selectedImagePaths.addAll(result.files.map((e) => e.name).toList());
          } else {
            _selectedImagePaths.clear();
            _selectedImagePaths.addAll(result.paths.whereType<String>());
            _selectedImageBytes.clear();
          }
          _existingImageUrls = []; 
        });
      }
    } catch (e) {
      debugPrint('ProjectForm: Error picking images $e');
    }
  }

  Future<void> _pickPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: kIsWeb, // Crucial for reading file bytes on the Web
      );
      if (result != null) {
        setState(() {
          if (kIsWeb) {
            _selectedPdfBytes = result.files.single.bytes;
            _selectedPdfPath = result.files.single.name;
          } else if (result.files.single.path != null) {
            _selectedPdfPath = result.files.single.path;
            _selectedPdfBytes = null;
          }
          _existingPdfUrl = null; 
        });
      }
    } catch (e) {
      debugPrint('ProjectForm: Error picking PDF $e');
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSubmitting = true);
    
    if (_selectedTeacherId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a teacher')));
      setState(() => _isSubmitting = false);
      return;
    }

    final List<TeamMember> teamMembers = [];
    if (_isGroupProject) {
      for (var controllers in _teamMemberControllers) {
        teamMembers.add(TeamMember(
          name: controllers['name']!.text.trim(),
          id: controllers['id']!.text.trim(),
          batch: int.tryParse(controllers['batch']!.text) ?? 0,
          level: int.tryParse(controllers['level']!.text) ?? 0,
          term: int.tryParse(controllers['term']!.text) ?? 0,
        ));
      }
    }

    final String? supervisor = _supervisorController.text.trim().isNotEmpty 
        ? _supervisorController.text.trim() 
        : null;

    final project = Project(
      id: widget.initialProject?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleController.text.trim(),
      abstract: _abstractController.text.trim(),
      authorId: widget.authService.currentUser!.id,
      authorName: widget.authService.currentUser!.name,
      category: _selectedCategory,
      customCategory: _selectedCategory == ProjectCategory.other ? _customCategoryController.text.trim() : null,
      year: int.tryParse(_yearController.text) ?? DateTime.now().year,
      semester: _selectedSemester,
      createdAt: widget.initialProject?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      status: widget.initialProject?.status == ProjectStatus.rejected ? ProjectStatus.pending : (widget.initialProject?.status ?? ProjectStatus.pending),
      githubUrl: _githubController.text.trim().isNotEmpty ? _githubController.text.trim() : null,
      imageUrls: _existingImageUrls.isNotEmpty ? _existingImageUrls : [], // URLs only
      pdfUrl: _existingPdfUrl, // Network URL only
      supervisor: supervisor,
      facultyId: _selectedTeacherId!,
      facultyName: _approvedTeachers.firstWhere((t) => t.id == _selectedTeacherId).name,
      projectType: _selectedProjectType,
      isGroupProject: _isGroupProject,
      groupName: _isGroupProject ? _groupNameController.text.trim() : null,
      teamMembers: teamMembers,
      driveLink: _driveLinkController.text.trim().isNotEmpty ? _driveLinkController.text.trim() : null,
      youtubeUrl: _youtubeLinkController.text.trim().isNotEmpty ? _youtubeLinkController.text.trim() : null,
      studentId: !_isGroupProject ? _studentIdController.text.trim() : null,
      batch: !_isGroupProject ? int.tryParse(_batchController.text) : null,
      level: !_isGroupProject ? int.tryParse(_levelController.text) : null,
      term: !_isGroupProject ? int.tryParse(_termController.text) : null,
      submissionType: _submissionType,
      academicCourse: _submissionType == ProjectSubmissionType.academic ? _selectedAcademicCourse : null,
      assistantTeacherId: _submissionType == ProjectSubmissionType.academic ? _selectedAssistantTeacherId : null,
      version: widget.initialProject != null ? (widget.initialProject!.version + 1) : 1,
    );

    final statusNotifier = ValueNotifier<String>('Uploading...');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ValueListenableBuilder<String>(
        valueListenable: statusNotifier,
        builder: (context, status, _) => AlertDialog(
          title: Text(widget.initialProject == null ? 'Uploading Project' : 'Updating Project'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(status),
            ],
          ),
        ),
      ),
    );

    try {
      // GitHub Visibility Check
      if (_githubController.text.trim().isNotEmpty) {
        statusNotifier.value = 'Verifying GitHub repository...';
        final isPublic = await _isGitHubRepoPublic(_githubController.text.trim());
        if (!isPublic) {
          if (mounted) {
            Navigator.of(context, rootNavigator: true).pop(); // Close dialog
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Please provide a public GitHub repository URL. Private repositories are not supported.')),
            );
          }
          return;
        }
      }

      bool success = false;
      if (widget.initialProject == null) {
        success = await widget.projectService.createProject(
          project,
          pdfBytes: _selectedPdfBytes,
          imageBytes: _selectedImageBytes,
          pdfPath: _selectedPdfPath,
          imagePaths: _selectedImagePaths,
        );
      } else {
        success = await widget.projectService.updateProjectWithFiles(
          project,
          pdfBytes: _selectedPdfBytes,
          imageBytes: _selectedImageBytes,
          pdfPath: _selectedPdfPath,
          imagePaths: _selectedImagePaths,
        );
      }

      if (mounted) Navigator.of(context, rootNavigator: true).pop(); // Close dialog

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Project ${widget.initialProject == null ? 'submitted' : 'updated'} successfully!')),
        );
        if (widget.onSuccess != null) {
          widget.onSuccess!();
        } else {
          Navigator.of(context).pop();
        }
      } else if (mounted) {
        final errorMsg = widget.projectService.lastUploadError ?? 'Failed to save project.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg)),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Dismiss loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
      debugPrint('ProjectForm: Error submitting $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  List<ProjectCategory> _categoriesForType(ProjectType type) {
    if (type == ProjectType.hardware) {
      return const [
        ProjectCategory.iot,
        ProjectCategory.marine,
        ProjectCategory.engineering,
        ProjectCategory.energy,
        ProjectCategory.other,
      ];
    }
    return ProjectCategory.values;
  }

  Future<bool> _isGitHubRepoPublic(String url) async {
    try {
      // Basic URL cleanup
      String cleanUrl = url.trim().toLowerCase();
      if (cleanUrl.endsWith('/')) cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
      
      // Handle https://github.com/owner/repo or github.com/owner/repo
      if (!cleanUrl.startsWith('http')) {
        cleanUrl = 'https://$cleanUrl';
      }
      
      final uri = Uri.parse(cleanUrl);
      if (uri.host != 'github.com' && uri.host != 'www.github.com') return false;
      
      final segments = uri.pathSegments;
      if (segments.length < 2) return false;
      
      final owner = segments[0];
      String repo = segments[1];
      if (repo.endsWith('.git')) {
        repo = repo.substring(0, repo.length - 4);
      }
      
      debugPrint('ProjectForm: Checking GitHub visibility for $owner/$repo');
      
      final response = await http.get(
        Uri.parse('https://api.github.com/repos/$owner/$repo'),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['private'] == false;
      } else if (response.statusCode == 404) {
        debugPrint('ProjectForm: GitHub repo not found (could be private)');
        return false;
      } else if (response.statusCode == 403) {
        debugPrint('ProjectForm: GitHub API rate limited. Failing open to allow submission.');
        return true;
      }
      
      debugPrint('ProjectForm: GitHub API error ${response.statusCode}. Failing open.');
      return true;
    } catch (e) {
      debugPrint('ProjectForm: Error checking GitHub visibility: $e. Failing open.');
      return true;
    }
  }

  int _getWordCount(String text) {
    if (text.trim().isEmpty) return 0;
    return text.trim().split(RegExp(r'\s+')).length;
  }

  String? _getValidValue(String text) {
    if (text.isEmpty || text == '0') return null;
    return text;
  }

  List<DropdownMenuItem<String>> _getBatchItems(String currentValue) {
    List<String> options = List.generate(8, (i) => (i + 15).toString());
    if (currentValue.isNotEmpty && currentValue != '0' && !options.contains(currentValue)) {
      options.add(currentValue);
      options.sort((a, b) => (int.tryParse(a) ?? 0).compareTo(int.tryParse(b) ?? 0));
    }
    return options.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList();
  }

  List<DropdownMenuItem<String>> _getLevelItems(String currentValue) {
    List<String> options = ['1', '2', '3', '4'];
    if (currentValue.isNotEmpty && currentValue != '0' && !options.contains(currentValue)) {
      options.add(currentValue);
    }
    return options.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList();
  }

  List<DropdownMenuItem<String>> _getTermItems(String currentValue) {
    List<String> options = ['1', '2'];
    if (currentValue.isNotEmpty && currentValue != '0' && !options.contains(currentValue)) {
      options.add(currentValue);
    }
    return options.map((t) {
      String label = t == '1' ? 'I' : t == '2' ? 'II' : t;
      return DropdownMenuItem(value: t, child: Text(label));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {

    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

            // Submission Category
            _SectionCard(
              title: 'Submission Category',
              icon: Icons.category_outlined,
              child: SegmentedButton<ProjectSubmissionType>(
                segments: const [
                  ButtonSegment(
                    value: ProjectSubmissionType.projectShowcase,
                    label: Text('Project Showcase'),
                    icon: Icon(Icons.public),
                  ),
                  ButtonSegment(
                    value: ProjectSubmissionType.academic,
                    label: Text('Academic'),
                    icon: Icon(Icons.school),
                  ),
                ],
                selected: {_submissionType},
                onSelectionChanged: (s) => setState(() => _submissionType = s.first),
              ),
            ),
            const SizedBox(height: 16),
            
            // Submission Type
            _SectionCard(
              title: 'Submission Type',
              icon: Icons.layers_outlined,
              child: SegmentedButton<ProjectType>(
                segments: const [
                  ButtonSegment(
                    value: ProjectType.project,
                    label: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Software Project'),
                        Text('Optional: GitHub, Images', style: TextStyle(fontSize: 10)),
                      ],
                    ),
                    icon: Icon(Icons.code),
                  ),
                  ButtonSegment(
                    value: ProjectType.thesis,
                    label: Text('Thesis/Research Paper'),
                    icon: Icon(Icons.menu_book),
                  ),
                  ButtonSegment(
                    value: ProjectType.hardware,
                    label: Text('Hardware'),
                    icon: Icon(Icons.memory),
                  ),
                ],
                selected: {_selectedProjectType},
                onSelectionChanged: (s) => setState(() {
                  _selectedProjectType = s.first;
                  // Auto-select a valid category for this type if necessary
                   if (_selectedProjectType == ProjectType.hardware) {
                     _selectedCategory = ProjectCategory.iot;
                   }
                }),
              ),
            ),
            const SizedBox(height: 16),

            // Basic Info
            _SectionCard(
              title: 'Basic Info',
              icon: Icons.info_outline,
              child: Column(
                children: [
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: 'Project Title', prefixIcon: Icon(Icons.title)),
                    validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _abstractController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: 'Abstract', 
                      prefixIcon: const Icon(Icons.description), 
                      alignLabelWithHint: true,
                      counterText: '${_getWordCount(_abstractController.text)} / 100 words',
                      counterStyle: TextStyle(
                        color: _getWordCount(_abstractController.text) > 100 ? Colors.red : null,
                        fontWeight: _getWordCount(_abstractController.text) > 100 ? FontWeight.bold : null,
                      ),
                    ),
                    onChanged: (v) => setState(() {}),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      if (_getWordCount(v) > 100) return 'Abstract must be maximum 100 words';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<ProjectCategory>(
                    value: _selectedCategory,
                    decoration: const InputDecoration(labelText: 'Category', prefixIcon: Icon(Icons.category)),
                    items: _categoriesForType(_selectedProjectType)
                        .map((c) => DropdownMenuItem(value: c, child: Text(c.displayName)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedCategory = v!),
                  ),
                  if (_selectedCategory == ProjectCategory.other) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _customCategoryController,
                      decoration: const InputDecoration(labelText: 'Specify Category', prefixIcon: Icon(Icons.edit)),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Year + Semester
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _yearController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Year', prefixIcon: Icon(Icons.calendar_today)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<Semester>(
                    value: _selectedSemester,
                    decoration: const InputDecoration(labelText: 'Semester'),
                    items: Semester.values.map((s) => DropdownMenuItem(value: s, child: Text(s.displayName))).toList(),
                    onChanged: (v) => setState(() => _selectedSemester = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Academic Info (only when Academic type)
            // Supervision & Academic Info
            _SectionCard(
              title: 'Supervision',
              icon: Icons.assignment_ind_outlined,
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: _selectedTeacherId,
                    decoration: const InputDecoration(labelText: 'Assign to Teacher', prefixIcon: Icon(Icons.person_search)),
                    items: _approvedTeachers.map((t) => DropdownMenuItem(value: t.id, child: Text(t.designation != null ? '${t.name} (${t.designation!.displayName})' : t.name))).toList(),
                    onChanged: (v) => setState(() => _selectedTeacherId = v),
                    validator: (v) => v == null ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _supervisorController,
                    decoration: const InputDecoration(labelText: 'Supervisor Name (optional)', prefixIcon: Icon(Icons.person_outline)),
                  ),
                  if (_submissionType == ProjectSubmissionType.academic) ...[
                    const SizedBox(height: 16),
                    DropdownButtonFormField<AcademicCourse>(
                      value: _selectedAcademicCourse,
                      decoration: const InputDecoration(labelText: 'Academic Course', prefixIcon: Icon(Icons.book_outlined)),
                      items: AcademicCourse.values.map((c) => DropdownMenuItem(value: c, child: Text(c.displayName))).toList(),
                      onChanged: (v) => setState(() => _selectedAcademicCourse = v),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedAssistantTeacherId,
                      decoration: const InputDecoration(labelText: 'Assistant Teacher (optional)', prefixIcon: Icon(Icons.person_add)),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('None')),
                        ..._approvedTeachers.map((t) => DropdownMenuItem(value: t.id, child: Text(t.designation != null ? '${t.name} (${t.designation!.displayName})' : t.name))),
                      ],
                      onChanged: (v) => setState(() => _selectedAssistantTeacherId = v),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Group Project Switch
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Group Project'),
              subtitle: const Text('Enable if more than one student'),
              value: _isGroupProject,
              onChanged: (v) => setState(() {
                _isGroupProject = v;
                _initializeTeamMembers();
              }),
            ),
            const SizedBox(height: 8),

            if (_isGroupProject) ...[
              TextFormField(
                controller: _groupNameController,
                decoration: const InputDecoration(labelText: 'Group Name', prefixIcon: Icon(Icons.group)),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text('Number of Members:', style: theme.textTheme.bodyMedium),
                  const SizedBox(width: 16),
                  DropdownButton<int>(
                    value: _numberOfMembers,
                    items: List.generate(3, (i) => i + 2)
                        .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
                        .toList(),
                    onChanged: (n) {
                      if (n == null) return;
                      setState(() {
                        if (n > _numberOfMembers) {
                          for (int i = _numberOfMembers; i < n; i++) {
                            _teamMemberControllers.add({
                              'name': TextEditingController(),
                              'id': TextEditingController(),
                              'batch': TextEditingController(),
                              'level': TextEditingController(),
                              'term': TextEditingController(),
                            });
                          }
                        } else {
                          for (int i = _numberOfMembers; i > n; i--) {
                            _teamMemberControllers.removeLast().values.forEach((c) => c.dispose());
                          }
                        }
                        _numberOfMembers = n;
                      });
                    },
                  ),
                ],
              ),
              ...List.generate(_numberOfMembers, (i) {
                if (i >= _teamMemberControllers.length) return const SizedBox.shrink();
                final c = _teamMemberControllers[i];
                return Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Member ${i + 1}', style: theme.textTheme.labelLarge),
                      const SizedBox(height: 8),
                      TextFormField(controller: c['name'], decoration: const InputDecoration(labelText: 'Name', prefixIcon: Icon(Icons.person))),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: c['id'],
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(labelText: 'Student ID', prefixIcon: Icon(Icons.badge)),
                      ),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _getValidValue(c['batch']!.text),
                            decoration: const InputDecoration(labelText: 'Batch'),
                            items: _getBatchItems(c['batch']!.text),
                            onChanged: (v) {
                              if (v != null) setState(() => c['batch']!.text = v);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _getValidValue(c['level']!.text),
                            decoration: const InputDecoration(labelText: 'Level'),
                            items: _getLevelItems(c['level']!.text),
                            onChanged: (v) {
                              if (v != null) setState(() => c['level']!.text = v);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _getValidValue(c['term']!.text),
                            decoration: const InputDecoration(labelText: 'Term'),
                            items: _getTermItems(c['term']!.text),
                            onChanged: (v) {
                              if (v != null) setState(() => c['term']!.text = v);
                            },
                          ),
                        ),
                      ]),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 16),
            ] else ...[
              TextFormField(
                controller: _studentIdController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Student ID', prefixIcon: Icon(Icons.badge)),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _getValidValue(_batchController.text),
                    decoration: const InputDecoration(labelText: 'Batch'),
                    items: _getBatchItems(_batchController.text),
                    onChanged: (v) {
                      if (v != null) setState(() => _batchController.text = v);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _getValidValue(_levelController.text),
                    decoration: const InputDecoration(labelText: 'Level'),
                    items: _getLevelItems(_levelController.text),
                    onChanged: (v) {
                      if (v != null) setState(() => _levelController.text = v);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _getValidValue(_termController.text),
                    decoration: const InputDecoration(labelText: 'Term'),
                    items: _getTermItems(_termController.text),
                    onChanged: (v) {
                      if (v != null) setState(() => _termController.text = v);
                    },
                  ),
                ),
              ]),
              const SizedBox(height: 16),
            ],


            // GitHub (hidden for Hardware)
            if (_selectedProjectType != ProjectType.hardware) ...[
              TextFormField(
                controller: _githubController,
                decoration: const InputDecoration(labelText: 'GitHub URL (optional)', prefixIcon: Icon(Icons.code)),
              ),
              const SizedBox(height: 16),
            ],

            // YouTube
            TextFormField(
              controller: _youtubeLinkController,
              decoration: const InputDecoration(labelText: 'YouTube Demo Link (optional)', prefixIcon: Icon(Icons.play_circle_outline)),
            ),
            const SizedBox(height: 16),

            // Drive
            TextFormField(
              controller: _driveLinkController,
              decoration: const InputDecoration(labelText: 'Google Drive Link (optional)', prefixIcon: Icon(Icons.drive_folder_upload_outlined)),
            ),
            const SizedBox(height: 16),

            // PDF Attach
            OutlinedButton.icon(
              onPressed: _pickPdf,
              icon: Icon(_selectedPdfPath != null || _existingPdfUrl != null ? Icons.check_circle_outline : Icons.attach_file),
              label: Text(_selectedPdfPath != null || _existingPdfUrl != null ? 'PDF Attached' : 'Attach PDF'),
            ),
            if (_selectedPdfPath != null && _selectedPdfPath != 'Existing PDF')
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Row(
                  children: [
                    const Icon(Icons.picture_as_pdf, size: 16, color: Colors.redAccent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _selectedPdfPath!.split('/').last.split('\\').last,
                        style: theme.textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => setState(() {
                        _selectedPdfPath = null;
                        _selectedPdfBytes = null;
                      }),
                    ),
                  ],
                ),
              )
            else if (_existingPdfUrl != null)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Row(
                  children: [
                    const Icon(Icons.picture_as_pdf, size: 16, color: Colors.redAccent),
                    const SizedBox(width: 6),
                    const Expanded(child: Text('Existing PDF attached', overflow: TextOverflow.ellipsis)),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => setState(() => _existingPdfUrl = null),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),

            // Images Attach
            OutlinedButton.icon(
              onPressed: _pickImages,
              icon: Icon(_selectedImagePaths.isNotEmpty || _existingImageUrls.isNotEmpty ? Icons.check_circle_outline : Icons.add_photo_alternate),
              label: Text(_selectedImagePaths.isNotEmpty || _existingImageUrls.isNotEmpty ? 'Images Selected' : 'Add Images'),
            ),
            if (_selectedImagePaths.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: _selectedImagePaths.map((p) {
                    final name = p.split('/').last.split('\\').last;
                    return Chip(
                      avatar: const Icon(Icons.image, size: 14),
                      label: Text(name, style: const TextStyle(fontSize: 11)),
                      deleteIcon: const Icon(Icons.close, size: 14),
                      onDeleted: () => setState(() => _selectedImagePaths.remove(p)),
                    );
                  }).toList(),
                ),
              )
            else if (_existingImageUrls.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: List.generate(_existingImageUrls.length, (i) => Chip(
                    avatar: const Icon(Icons.image, size: 14),
                    label: Text('Image ${i + 1}', style: const TextStyle(fontSize: 11)),
                    deleteIcon: const Icon(Icons.close, size: 14),
                    onDeleted: () => setState(() => _existingImageUrls.removeAt(i)),
                  )),
                ),
              ),
            const SizedBox(height: 24),

            // Submit
            FilledButton(
              onPressed: _isSubmitting ? null : _submit,
              child: Text(_isSubmitting ? 'Processing...' : (widget.initialProject == null ? 'Submit Project' : 'Save Changes')),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.icon, required this.child});
  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(title,
                    style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary)),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}
