import 'package:flutter/material.dart';
import '../mvc/models/project.dart';
import '../mvc/controllers/project_service.dart';
import '../mvc/controllers/auth_service.dart';
import '../widgets/project_form.dart';

class ProjectFormScreen extends StatelessWidget {
  final Project? initialProject;
  final ProjectService projectService;
  final AuthService authService;

  const ProjectFormScreen({
    super.key,
    this.initialProject,
    required this.projectService,
    required this.authService,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(initialProject == null ? 'Upload Project' : 'Edit Project'),
      ),
      body: ProjectForm(
        initialProject: initialProject,
        projectService: projectService,
        authService: authService,
      ),
    );
  }
}
