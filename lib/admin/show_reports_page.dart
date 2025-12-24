import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ShowReportsPage extends StatefulWidget {
  final bool isFaculty;
  final String department;
  final bool isSuperAdmin;

  const ShowReportsPage({
    super.key,
    required this.isFaculty,
    required this.department,
    this.isSuperAdmin = false,
  });

  @override
  State<ShowReportsPage> createState() => _ShowReportsPageState();
}

class _ShowReportsPageState extends State<ShowReportsPage> {
  String _selectedDeptFilter = 'All Departments';

  final List<String> _departments = [
    'All Departments',
    'Computer Engineering',
    'Electronics',
    'Mechanical',
    'Civil',
    'Electrical',
  ];

  @override
  void initState() {
    super.initState();
    _initializeFilter();
  }

  @override
  void didUpdateWidget(ShowReportsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.department != widget.department ||
        oldWidget.isFaculty != widget.isFaculty) {
      _initializeFilter();
    }
  }

  void _initializeFilter() {
    // For regular admins/faculty, lock the view to their specific department
    if (widget.isFaculty && !widget.isSuperAdmin) {
      if (widget.department.isNotEmpty) {
        setState(() {
          _selectedDeptFilter = widget.department;
        });
      }
    }
  }

  Future<void> _resolveReport(DocumentSnapshot report) async {
    Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text('Mark as Resolved?'),
        content: Text(
          'This will permanently remove the incident report for ${report['studentName']} from the system.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Resolve'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('reports')
            .doc(report.id)
            .delete();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Report for ${report['studentName']} resolved'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update registry')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Security Gate
    if (!widget.isSuperAdmin && !widget.isFaculty) {
      return _buildAccessDenied(theme);
    }

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Incident Registry',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildHeader(theme, isDark),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              // RULE 2: Fetching all and filtering in memory ensures immediate visibility
              // and resolves comparison issues caused by trailing spaces or case differences.
              stream: FirebaseFirestore.instance
                  .collection('reports')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return _buildErrorState(theme);
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allReports = snapshot.data!.docs;

                final filteredReports = allReports.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;

                  // Extract department safely and normalize (trim and lower-case)
                  final String reportDept = (data['studentDepartment'] ?? '')
                      .toString()
                      .trim()
                      .toLowerCase();

                  // Determine target department string
                  // If SuperAdmin is using "All Departments", show everything
                  if (widget.isSuperAdmin &&
                      _selectedDeptFilter == 'All Departments') {
                    return true;
                  }

                  // Otherwise, match against the selected filter or the forced department
                  final String targetDept = _selectedDeptFilter
                      .trim()
                      .toLowerCase();

                  return reportDept == targetDept;
                }).toList();

                if (filteredReports.isEmpty) {
                  return _buildEmptyState(theme, isDark);
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 24,
                  ),
                  itemCount: filteredReports.length,
                  itemBuilder: (context, index) =>
                      _buildReportCard(filteredReports[index], theme, isDark),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: theme.dividerColor.withOpacity(0.05)),
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.isSuperAdmin ? "SYSTEM-WIDE LOGS" : "DEPARTMENTAL LOGS",
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (widget.isSuperAdmin) _buildDeptFilter(theme, isDark),
              if (!widget.isSuperAdmin)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: theme.colorScheme.primary.withOpacity(0.2),
                    ),
                  ),
                  child: Text(
                    widget.department.isNotEmpty
                        ? widget.department
                        : "General",
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _selectedDeptFilter == 'All Departments'
                ? "All Active Incidents"
                : "Logs: $_selectedDeptFilter",
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : Colors.black87,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeptFilter(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedDeptFilter,
          icon: Icon(
            Icons.filter_list_rounded,
            size: 18,
            color: theme.colorScheme.primary,
          ),
          dropdownColor: isDark
              ? const Color(0xFF1E293B)
              : theme.colorScheme.surface,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : theme.colorScheme.onSurface,
          ),
          onChanged: (String? newValue) {
            if (newValue != null) {
              setState(() => _selectedDeptFilter = newValue);
            }
          },
          items: _departments.map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value == 'All Departments' ? 'Global View' : value),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildReportCard(
    DocumentSnapshot report,
    ThemeData theme,
    bool isDark,
  ) {
    final data = report.data() as Map<String, dynamic>;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: theme.dividerColor.withOpacity(isDark ? 0.08 : 0.1),
        ),
      ),
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 12,
            ),
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.error.withOpacity(0.1),
              child: Icon(
                Icons.gavel_rounded,
                color: theme.colorScheme.error,
                size: 22,
              ),
            ),
            title: Text(
              data['studentName'] ?? 'Unknown Student',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            subtitle: Text(
              "ID: ${data['studentId']} • Year ${data['studentYear']}",
              style: TextStyle(
                color: isDark ? Colors.white38 : theme.disabledColor,
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 14,
                      color: theme.colorScheme.secondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "REPORTED INCIDENT",
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  data['reason'] ?? 'No reason provided.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    height: 1.5,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                if (widget.isSuperAdmin)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      data['studentDepartment'] ?? 'General',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _resolveReport(report),
                  icon: const Icon(Icons.done_all_rounded, size: 18),
                  label: const Text("Mark as Resolved"),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.greenAccent,
                    backgroundColor: Colors.greenAccent.withOpacity(0.05),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.assignment_turned_in_outlined,
              size: 64,
              color: theme.colorScheme.primary.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Registry is Clear',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'No pending reports found for $_selectedDeptFilter.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? Colors.white38 : theme.disabledColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 64,
            color: theme.colorScheme.error.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            "Sync Failed",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const Text("Please check your database permissions."),
        ],
      ),
    );
  }

  Widget _buildAccessDenied(ThemeData theme) {
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(elevation: 0),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock_person_rounded,
                  size: 80,
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Security Restriction',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Only authorized administrative accounts are permitted to view student incident logs.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.disabledColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
