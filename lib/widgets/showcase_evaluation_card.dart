import 'package:flutter/material.dart';
import '../mvc/models/project.dart';
import '../mvc/models/user.dart'; // For UserRole if needed contextually, though we pass role in constructor or check externally
import '../mvc/controllers/project_service.dart';
import '../mvc/controllers/auth_service.dart';

class ShowcaseEvaluationCard extends StatefulWidget {
  final Project project;
  final ProjectService projectService;
  final bool isAdmin;

  const ShowcaseEvaluationCard({
    Key? key,
    required this.project,
    required this.projectService,
    required this.isAdmin,
  }) : super(key: key);

  @override
  State<ShowcaseEvaluationCard> createState() => _ShowcaseEvaluationCardState();
}

class _ShowcaseEvaluationCardState extends State<ShowcaseEvaluationCard> {
  // Rubric Scores
  double _innovationScore = 0.0;
  double _technicalScore = 0.0;
  double _presentationScore = 0.0;
  
  final TextEditingController _feedbackController = TextEditingController();
  
  bool _isDirty = false;
  bool _isSaving = false;

  double get _currentAverage => (_innovationScore + _technicalScore + _presentationScore) / 3;

  @override
  void initState() {
    super.initState();
    _loadUserEvaluation();
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  void _loadUserEvaluation() {
    final currentUser = AuthService().currentUser;
    if (currentUser != null) {
      final evaluation = widget.project.evaluations.firstWhere(
        (e) => e.teacherId == currentUser.id,
        orElse: () => ShowcaseEvaluation(
          teacherId: '', 
          teacherName: '', 
          mark: 0.0, 
          updatedAt: DateTime.now()
        ),
      );

      if (evaluation.teacherId.isNotEmpty) {
        // Load existing criteria or fallback to legacy mark
        if (evaluation.criteria.isNotEmpty) {
          _innovationScore = evaluation.criteria['Innovation'] ?? 0.0;
          _technicalScore = evaluation.criteria['Technical'] ?? 0.0;
          _presentationScore = evaluation.criteria['Presentation'] ?? 0.0;
        } else {
          // Legacy support: set all to the single mark
          _innovationScore = evaluation.mark;
          _technicalScore = evaluation.mark;
          _presentationScore = evaluation.mark;
        }
        _feedbackController.text = evaluation.feedback ?? '';
      } else {
        _innovationScore = 0.0;
        _technicalScore = 0.0;
        _presentationScore = 0.0;
        _feedbackController.text = '';
      }
    }
  }

  @override
  void didUpdateWidget(covariant ShowcaseEvaluationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.project.id != widget.project.id) {
      _loadUserEvaluation();
      _isDirty = false;
    }
  }

  Future<void> _handleSave() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final criteria = {
        'Innovation': _innovationScore,
        'Technical': _technicalScore,
        'Presentation': _presentationScore,
      };

      await widget.projectService.updateShowcaseEvaluation(
        widget.project.id, 
        criteria,
        _feedbackController.text.trim(),
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Evaluation saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          _isDirty = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving evaluation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Color _getScoreColor(double score) {
    if (score >= 8) return Colors.green;
    if (score >= 5) return Colors.orange;
    return Colors.red;
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Color _getScoreColorLight(double score) {
    if (score >= 8) return Colors.green.shade400;
    if (score >= 5) return Colors.orange.shade400;
    return Colors.red.shade400;
  }

  Widget _buildOtherEvaluations() {
    final currentUserId = AuthService().currentUser?.id ?? '';
    final others = widget.project.evaluations
        .where((e) => e.teacherId.isNotEmpty && e.teacherId != currentUserId)
        .toList();

    if (others.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(color: Colors.white24, height: 20),
        Text(
          'Other Evaluations (${others.length})',
          style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...others.map((e) {
          final avg = e.criteria.isNotEmpty
              ? e.criteria.values.fold<double>(0.0, (double a, double b) => a + b) / e.criteria.length
              : e.mark;
          final innovation = e.criteria['Innovation'] ?? e.mark;
          final technical = e.criteria['Technical'] ?? e.mark;
          final presentation = e.criteria['Presentation'] ?? e.mark;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Teacher name + avg score
                Row(
                  children: [
                    const Icon(Icons.person_outline, size: 14, color: Colors.white54),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        e.teacherName.isNotEmpty ? e.teacherName : 'Teacher',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getScoreColorLight(avg).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _getScoreColorLight(avg), width: 1),
                      ),
                      child: Text(
                        avg.toStringAsFixed(1),
                        style: TextStyle(color: _getScoreColorLight(avg), fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Criteria scores in a row
                Row(
                  children: [
                    _scorePill('Inno', innovation),
                    const SizedBox(width: 4),
                    _scorePill('Tech', technical),
                    const SizedBox(width: 4),
                    _scorePill('Pres', presentation),
                    const Spacer(),
                    Text(
                      _formatDate(e.updatedAt),
                      style: const TextStyle(color: Colors.white38, fontSize: 10),
                    ),
                  ],
                ),
                // Feedback (if any)
                if ((e.feedback ?? '').isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    e.feedback!,
                    style: const TextStyle(color: Colors.white54, fontSize: 11, fontStyle: FontStyle.italic),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _scorePill(String label, double score) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label: ${score.toStringAsFixed(1)}',
        style: const TextStyle(color: Colors.white60, fontSize: 10),
      ),
    );
  }

  Widget _buildSliderRow(String label, double value, Function(double) onChanged) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            Text(value.toStringAsFixed(1), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: primaryColor,
            inactiveTrackColor: primaryColor.withOpacity(0.1),
            trackHeight: 3.0,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
            thumbColor: Colors.white,
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12.0),
            valueIndicatorColor: primaryColor,
          ),
          child: Slider(
            value: value,
            min: 0,
            max: 10,
            divisions: 20,
            label: value.toString(),
            onChanged: (val) {
              onChanged(val);
              setState(() => _isDirty = true);
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;

    return Card(
      elevation: 8,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: primaryColor.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF2C3E50), // Dark Slate
              const Color(0xFF34495E), // Slightly lighter slate
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.rate_review_rounded, color: primaryColor, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Showcase Evaluation',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Detailed Rubric Grading',
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 16, color: Colors.white24),

              // Total Score Display
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getScoreColor(_currentAverage).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _getScoreColor(_currentAverage), width: 1.5),
                      ),
                      child: Text(
                        _currentAverage.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: _getScoreColor(_currentAverage),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('avg', style: TextStyle(color: Colors.white38, fontSize: 11)),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Rubric Sliders
              _buildSliderRow('Innovation & Creativity', _innovationScore, (val) => setState(() => _innovationScore = val)),
              const SizedBox(height: 4),
              _buildSliderRow('Technical Implementation', _technicalScore, (val) => setState(() => _technicalScore = val)),
              const SizedBox(height: 4),
              _buildSliderRow('Presentation & Impact', _presentationScore, (val) => setState(() => _presentationScore = val)),

              const SizedBox(height: 12),

              // Feedback Input
              Text('Private Feedback', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 6),
              TextField(
                controller: _feedbackController,
                maxLines: 2,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Enter feedback...',
                  hintStyle: TextStyle(color: Colors.white30),
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                onChanged: (_) => setState(() => _isDirty = true),
              ),

              const SizedBox(height: 12),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 38,
                child: ElevatedButton(
                  onPressed: _isDirty && !_isSaving ? _handleSave : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[700],
                    disabledForegroundColor: Colors.grey[500],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isSaving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(_isDirty ? Icons.save_rounded : Icons.check_circle_outline, size: 16),
                            const SizedBox(width: 6),
                            Text(_isDirty ? 'Submit Evaluation' : 'Evaluation Saved', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          ],
                        ),
                ),
              ),

              // Admin Awards Control
              if (widget.isAdmin) ...[
                const SizedBox(height: 24),
                const Divider(color: Colors.white24),
                const SizedBox(height: 16),
                Text('Project Award (Visible to All)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                 const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white24),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<ProjectAward>(
                        isExpanded: true,
                        value: widget.project.award,
                        icon: const Icon(Icons.arrow_drop_down_rounded, color: Colors.white70),
                        dropdownColor: Colors.grey[900],
                        style: const TextStyle(color: Colors.white),
                        items: ProjectAward.values.map((award) {
                          return DropdownMenuItem(
                            value: award,
                            child: Row(
                              children: [
                                if (award != ProjectAward.none)
                                  Icon(Icons.emoji_events_rounded, size: 20, color: _getAwardColor(award)),
                                if (award != ProjectAward.none) const SizedBox(width: 8),
                                Text(award == ProjectAward.none ? 'No Award' : award.displayName),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) async {
                          if (value != null && value != widget.project.award) {
                            await widget.projectService.updateProjectAward(widget.project.id, value);
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Award updated!'), backgroundColor: Colors.amber[700]));
                          }
                        },
                      ),
                    ),
                  ),
              ],
              
              // Other teachers' evaluations (visible to all teachers & admin)
              _buildOtherEvaluations(),
            ],
          ),
        ),
      ),
    );
  }
}
