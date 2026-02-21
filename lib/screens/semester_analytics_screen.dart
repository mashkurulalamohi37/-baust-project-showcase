import 'package:flutter/material.dart';
import '../mvc/models/project.dart';
import '../mvc/controllers/project_service.dart';

// ─────────────────────────────────────────────
// Data record
// ─────────────────────────────────────────────
class _SemesterRecord {
  final String label;
  final int approved;
  final int rejected;
  final int pending;
  final int total;
  final int projectCount;
  final int thesisCount;
  final int hardwareCount;

  const _SemesterRecord({
    required this.label,
    required this.approved,
    required this.rejected,
    required this.pending,
    required this.total,
    required this.projectCount,
    required this.thesisCount,
    required this.hardwareCount,
  });
}

List<_SemesterRecord> _buildRecords(
    ProjectService ps, ProjectSubmissionType? filter) {
  final Map<String, List<Project>> grouped = {};
  for (final p in ps.projects) {
    if (filter != null && p.submissionType != filter) {
      continue;
    }
    final key = '${p.year}_${p.semester.name}';
    grouped.putIfAbsent(key, () => []).add(p);
  }

  final records = grouped.entries.map((e) {
    final parts = e.key.split('_');
    final year = int.tryParse(parts[0]) ?? 0;
    final sem = parts[1][0].toUpperCase() + parts[1].substring(1);
    final list = e.value;

    return _SemesterRecord(
      label: '$sem $year',
      approved: list
          .where((p) =>
              p.status == ProjectStatus.approved ||
              p.status == ProjectStatus.featured)
          .length,
      rejected: list.where((p) => p.status == ProjectStatus.rejected).length,
      pending: list
          .where((p) =>
              p.status == ProjectStatus.pending ||
              p.status == ProjectStatus.needsRevision ||
              p.status == ProjectStatus.resubmitted ||
              p.status == ProjectStatus.draft)
          .length,
      total: list.length,
      projectCount:
          list.where((p) => p.projectType == ProjectType.project).length,
      thesisCount:
          list.where((p) => p.projectType == ProjectType.thesis).length,
      hardwareCount:
          list.where((p) => p.projectType == ProjectType.hardware).length,
    );
  }).toList()
    ..sort((a, b) {
      final aYear = int.tryParse(a.label.split(' ').last) ?? 0;
      final bYear = int.tryParse(b.label.split(' ').last) ?? 0;
      final yCmp = bYear.compareTo(aYear);
      if (yCmp != 0) return yCmp;
      return a.label.compareTo(b.label);
    });
  return records;
}

// ─────────────────────────────────────────────
// Standalone screen (used by admin)
// ─────────────────────────────────────────────
class SemesterAnalyticsScreen extends StatelessWidget {
  const SemesterAnalyticsScreen({super.key, required this.projectService});
  final ProjectService projectService;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Semester-wise Analytics'),
        centerTitle: false,
      ),
      body: SemesterAnalyticsBody(projectService: projectService),
    );
  }
}

// ─────────────────────────────────────────────
// Embeddable body (used by teacher tab & admin screen)
// ─────────────────────────────────────────────
class SemesterAnalyticsBody extends StatefulWidget {
  const SemesterAnalyticsBody({super.key, required this.projectService});
  final ProjectService projectService;

  @override
  State<SemesterAnalyticsBody> createState() => _SemesterAnalyticsBodyState();
}

class _SemesterAnalyticsBodyState extends State<SemesterAnalyticsBody> {
  ProjectSubmissionType? _filter;
  String? _selectedSemester;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.projectService,
      builder: (context, _) {
        final allRecords = _buildRecords(widget.projectService, _filter);
        final availableSemesters = allRecords.map((e) => e.label).toList();

        if (allRecords.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bar_chart_outlined, size: 72, color: Colors.grey),
                SizedBox(height: 16),
                Text('No project data yet',
                    style: TextStyle(color: Colors.grey, fontSize: 16)),
              ],
            ),
          );
        }

        final displayRecords = _selectedSemester == null
            ? allRecords
            : allRecords.where((e) => e.label == _selectedSemester).toList();

        final totalApproved = displayRecords.fold(0, (s, r) => s + r.approved);
        final totalRejected = displayRecords.fold(0, (s, r) => s + r.rejected);
        final totalPending = displayRecords.fold(0, (s, r) => s + r.pending);
        final grandTotal = displayRecords.fold(0, (s, r) => s + r.total);

        // Project type counts
        final thesisCount = displayRecords.fold(0, (s, r) => s + r.thesisCount);
        final hardwareCount =
            displayRecords.fold(0, (s, r) => s + r.hardwareCount);
        final projectCount =
            displayRecords.fold(0, (s, r) => s + r.projectCount);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Title & Semester Dropdown
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Project Overview',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('Grouped by semester & academic year',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.grey)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: availableSemesters.contains(_selectedSemester)
                            ? _selectedSemester
                            : null,
                        hint: const Text('All Semesters'),
                        icon: const Icon(Icons.arrow_drop_down, size: 20),
                        isDense: true,
                        style: Theme.of(context).textTheme.bodyMedium,
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('All Semesters'),
                          ),
                          ...availableSemesters.map((s) => DropdownMenuItem(
                                value: s,
                                child: Text(s),
                              )),
                        ],
                        onChanged: (val) =>
                            setState(() => _selectedSemester = val),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('All'),
                      selected: _filter == null,
                      onSelected: (val) => setState(() => _filter = null),
                      showCheckmark: false,
                      selectedColor:
                          Theme.of(context).colorScheme.primaryContainer,
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Project Showcase'),
                      selected:
                          _filter == ProjectSubmissionType.projectShowcase,
                      onSelected: (val) => setState(() =>
                          _filter = ProjectSubmissionType.projectShowcase),
                      showCheckmark: false,
                      selectedColor:
                          Theme.of(context).colorScheme.primaryContainer,
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Academic Research'),
                      selected: _filter == ProjectSubmissionType.academic,
                      onSelected: (val) => setState(
                          () => _filter = ProjectSubmissionType.academic),
                      showCheckmark: false,
                      selectedColor:
                          Theme.of(context).colorScheme.primaryContainer,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Summary cards row
              Row(
                children: [
                  _SummaryCard(
                      label: 'Total',
                      value: grandTotal,
                      icon: Icons.folder_copy_rounded,
                      color: Colors.blue.shade600),
                  const SizedBox(width: 10),
                  _SummaryCard(
                      label: 'Approved',
                      value: totalApproved,
                      icon: Icons.check_circle_rounded,
                      color: Colors.green.shade600),
                  const SizedBox(width: 10),
                  _SummaryCard(
                      label: 'Rejected',
                      value: totalRejected,
                      icon: Icons.cancel_rounded,
                      color: Colors.red.shade600),
                  const SizedBox(width: 10),
                  _SummaryCard(
                      label: 'Pending',
                      value: totalPending,
                      icon: Icons.hourglass_top_rounded,
                      color: Colors.orange.shade700),
                ],
              ),
              const SizedBox(height: 28),

              // ── Table title
              Text('Per-Semester Breakdown',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),

              // ── Table
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant)),
                child: Column(
                  children: [
                    // Header
                    _TableHeader(),
                    const Divider(height: 1),
                    // Rows
                    ...displayRecords.asMap().entries.map((e) {
                      final i = e.key;
                      final r = e.value;
                      return Column(
                        children: [
                          _TableRow(record: r, isEven: i.isEven),
                          if (i < displayRecords.length - 1)
                            Divider(
                                height: 1,
                                color: Theme.of(context)
                                    .colorScheme
                                    .outlineVariant
                                    .withValues(alpha: 0.5)),
                        ],
                      );
                    }),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // ── Project Type Breakdown
              Text('By Project Type',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(
                children: [
                  _SummaryCard(
                      label: 'Project',
                      value: projectCount,
                      icon: Icons.code_rounded,
                      color: Colors.blue.shade500),
                  const SizedBox(width: 10),
                  _SummaryCard(
                      label: 'Thesis',
                      value: thesisCount,
                      icon: Icons.menu_book_rounded,
                      color: Colors.purple.shade500),
                  const SizedBox(width: 10),
                  _SummaryCard(
                      label: 'Hardware',
                      value: hardwareCount,
                      icon: Icons.memory_rounded,
                      color: Colors.teal.shade500),
                ],
              ),
              const SizedBox(height: 24),

              // ── Legend
              Wrap(
                spacing: 18,
                runSpacing: 6,
                children: [
                  _Legend(
                      color: Colors.green.shade600,
                      label: 'Approved (incl. Featured)'),
                  _Legend(color: Colors.red.shade600, label: 'Rejected'),
                  _Legend(
                      color: Colors.orange.shade700,
                      label: 'Pending (incl. Draft, Needs Revision)'),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// Table header
// ─────────────────────────────────────────────
class _TableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context)
        .textTheme
        .labelMedium
        ?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 0.5);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
      ),
      child: Row(
        children: [
          Expanded(flex: 5, child: Text('Semester', style: style)),
          Expanded(
              flex: 3,
              child: Text('✅ Approved',
                  style: style?.copyWith(color: Colors.green.shade600),
                  textAlign: TextAlign.center)),
          Expanded(
              flex: 3,
              child: Text('❌ Rejected',
                  style: style?.copyWith(color: Colors.red.shade600),
                  textAlign: TextAlign.center)),
          Expanded(
              flex: 3,
              child: Text('⏳ Pending',
                  style: style?.copyWith(color: Colors.orange.shade700),
                  textAlign: TextAlign.center)),
          Expanded(
              flex: 2,
              child: Text('Total',
                  style: style, textAlign: TextAlign.center)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Table row
// ─────────────────────────────────────────────
class _TableRow extends StatelessWidget {
  const _TableRow({required this.record, required this.isEven});
  final _SemesterRecord record;
  final bool isEven;

  @override
  Widget build(BuildContext context) {
    final bg = isEven
        ? Colors.transparent
        : Theme.of(context).colorScheme.surfaceContainerLowest;

    return Container(
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(record.label,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                _MiniBar(
                    approved: record.approved,
                    rejected: record.rejected,
                    pending: record.pending,
                    total: record.total),
                const SizedBox(height: 5),
                // Project type chips
                Wrap(
                  spacing: 4,
                  runSpacing: 2,
                  children: [
                    if (record.projectCount > 0)
                      _TypeChip(
                          label: '${record.projectCount} Projects',
                          color: Colors.blue.shade400),
                    if (record.thesisCount > 0)
                      _TypeChip(
                          label: '${record.thesisCount} Thesis',
                          color: Colors.purple.shade400),
                    if (record.hardwareCount > 0)
                      _TypeChip(
                          label: '${record.hardwareCount} Hardware',
                          color: Colors.teal.shade400),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
              flex: 3,
              child: Text('${record.approved}',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.green.shade600,
                      fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center)),
          Expanded(
              flex: 3,
              child: Text('${record.rejected}',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.red.shade600, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center)),
          Expanded(
              flex: 3,
              child: Text('${record.pending}',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center)),
          Expanded(
              flex: 2,
              child: Text('${record.total}',
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Mini progress bar inside each row
// ─────────────────────────────────────────────
class _MiniBar extends StatelessWidget {
  const _MiniBar(
      {required this.approved,
      required this.rejected,
      required this.pending,
      required this.total});
  final int approved, rejected, pending, total;

  @override
  Widget build(BuildContext context) {
    if (total == 0) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Row(
        children: [
          if (approved > 0)
            Expanded(
                flex: approved,
                child: Container(height: 5, color: Colors.green.shade500)),
          if (rejected > 0)
            Expanded(
                flex: rejected,
                child: Container(height: 5, color: Colors.red.shade500)),
          if (pending > 0)
            Expanded(
                flex: pending,
                child: Container(height: 5, color: Colors.orange.shade500)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Summary card
// ─────────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  const _SummaryCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});
  final String label;
  final int value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text('$value',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 3),
            Text(label,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: color, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Legend item
// ─────────────────────────────────────────────
class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        Text(label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.grey.shade600)),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Type chip
// ─────────────────────────────────────────────
class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
      ),
    );
  }
}
