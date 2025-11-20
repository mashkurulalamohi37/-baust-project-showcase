import 'package:flutter/material.dart';
import '../mvc/models/project.dart';
import '../mvc/controllers/project_service.dart';
import '../mvc/controllers/auth_service.dart';
import 'project_detail.dart';

class SearchFilterScreen extends StatefulWidget {
  const SearchFilterScreen({super.key});

  @override
  State<SearchFilterScreen> createState() => _SearchFilterScreenState();
}

class _SearchFilterScreenState extends State<SearchFilterScreen> {
  final ProjectService _projectService = ProjectService();
  final _searchController = TextEditingController();
  final _supervisorController = TextEditingController();
  
  ProjectCategory? _selectedCategory;
  int? _selectedYear;
  List<Project> _filteredProjects = [];
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _filteredProjects = _projectService.projects;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _supervisorController.dispose();
    super.dispose();
  }

  void _performSearch() {
    setState(() {
      _hasSearched = true;
      _filteredProjects = _projectService.projects.where((project) {
        // Text search
        final searchQuery = _searchController.text.toLowerCase();
        final matchesSearch = searchQuery.isEmpty ||
            project.title.toLowerCase().contains(searchQuery) ||
            project.abstract.toLowerCase().contains(searchQuery) ||
            project.authorName.toLowerCase().contains(searchQuery) ||
            project.tags.any((tag) => tag.toLowerCase().contains(searchQuery));

        // Category filter
        final matchesCategory = _selectedCategory == null || project.category == _selectedCategory;

        // Year filter
        final matchesYear = _selectedYear == null || project.year == _selectedYear;

        // Supervisor filter
        final supervisorQuery = _supervisorController.text.toLowerCase();
        final matchesSupervisor = supervisorQuery.isEmpty ||
            (project.facultyName?.toLowerCase().contains(supervisorQuery) ?? false);

        return matchesSearch && matchesCategory && matchesYear && matchesSupervisor;
      }).toList();
    });
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _supervisorController.clear();
      _selectedCategory = null;
      _selectedYear = null;
      _hasSearched = false;
      _filteredProjects = _projectService.projects;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search & Filter'),
        actions: <Widget>[
          if (_hasSearched)
            TextButton(
              onPressed: _clearFilters,
              child: const Text('Clear'),
            ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _projectService,
        builder: (context, child) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              // Search Input
              TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search keywords, title, authors...',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _performSearch(),
              ),
              const SizedBox(height: 16),
              
              // Filter Row
              Row(
                children: <Widget>[
                  Expanded(
                    child: DropdownButtonFormField<ProjectCategory>(
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                      value: _selectedCategory,
                      items: [
                        const DropdownMenuItem<ProjectCategory>(
                          value: null,
                          child: Text('All Categories'),
                        ),
                        ...ProjectCategory.values.map((category) => DropdownMenuItem(
                          value: category,
                          child: Text(category.displayName),
                        )),
                      ],
                      onChanged: (ProjectCategory? value) {
                        setState(() => _selectedCategory = value);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      decoration: const InputDecoration(
                        labelText: 'Year',
                        border: OutlineInputBorder(),
                      ),
                      value: _selectedYear,
                      items: [
                        const DropdownMenuItem<int>(
                          value: null,
                          child: Text('All Years'),
                        ),
                        ...List.generate(8, (int i) {
                          final int year = DateTime.now().year - i;
                          return DropdownMenuItem<int>(
                            value: year,
                            child: Text(year.toString()),
                          );
                        }),
                      ],
                      onChanged: (int? value) {
                        setState(() => _selectedYear = value);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Supervisor Filter
              TextField(
                controller: _supervisorController,
                decoration: const InputDecoration(
                  labelText: 'Supervisor',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              
              // Action Buttons
              Row(
                children: <Widget>[
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _performSearch,
                      icon: const Icon(Icons.search),
                      label: const Text('Search'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _clearFilters,
                      icon: const Icon(Icons.clear),
                      label: const Text('Clear'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Results
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    'Results (${_filteredProjects.length})',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (_filteredProjects.isNotEmpty)
                    DropdownButton<String>(
                      hint: const Text('Sort by'),
                      items: const <DropdownMenuItem<String>>[
                        DropdownMenuItem(value: 'title', child: Text('Title')),
                        DropdownMenuItem(value: 'rating', child: Text('Rating')),
                        DropdownMenuItem(value: 'year', child: Text('Year')),
                        DropdownMenuItem(value: 'recent', child: Text('Most Recent')),
                      ],
                      onChanged: (String? value) {
                        setState(() {
                          switch (value) {
                            case 'title':
                              _filteredProjects.sort((a, b) => a.title.compareTo(b.title));
                              break;
                            case 'rating':
                              _filteredProjects.sort((a, b) => b.rating.compareTo(a.rating));
                              break;
                            case 'year':
                              _filteredProjects.sort((a, b) => b.year.compareTo(a.year));
                              break;
                            case 'recent':
                              _filteredProjects.sort((a, b) => b.createdAt.compareTo(a.createdAt));
                              break;
                          }
                        });
                      },
                    ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Project List
              if (_filteredProjects.isEmpty && _hasSearched)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(
                      children: <Widget>[
                        Icon(Icons.search_off, size: 64),
                        SizedBox(height: 16),
                        Text('No projects found'),
                        SizedBox(height: 8),
                        Text('Try adjusting your search criteria'),
                      ],
                    ),
                  ),
                )
              else if (_filteredProjects.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(
                      children: <Widget>[
                        Icon(Icons.search, size: 64),
                        SizedBox(height: 16),
                        Text('Search for projects'),
                        SizedBox(height: 8),
                        Text('Use the filters above to find specific projects'),
                      ],
                    ),
                  ),
                )
              else
                ..._filteredProjects.map((project) => Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    title: Text(project.title),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(project.abstract, maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Row(
                          children: <Widget>[
                            Chip(
                              label: Text(project.category.displayName),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            const SizedBox(width: 8),
                            Text('${project.year}'),
                            if (project.facultyName != null) ...[
                              const SizedBox(width: 8),
                              Text('• ${project.facultyName}'),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: <Widget>[
                            const Icon(Icons.star, size: 16, color: Colors.amber),
                            const SizedBox(width: 4),
                            Text('${project.rating.toStringAsFixed(1)} (${project.reviewCount})'),
                            const SizedBox(width: 16),
                            Text('By ${project.authorName}'),
                          ],
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        IconButton(
                          icon: Icon(
                            _projectService.isBookmarked(project.id)
                                ? Icons.bookmark
                                : Icons.bookmark_border,
                          ),
                          onPressed: () => _projectService.toggleBookmark(project.id),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => ProjectDetailScreen(
                        project: project,
                        projectService: _projectService,
                        authService: AuthService(),
                      ),
                    )),
                  ),
                )),
            ],
          );
        },
      ),
    );
  }
}


