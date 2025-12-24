import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:latepass/admin/student_model.dart';

class ReportStudentPage extends StatefulWidget {
  final bool isSuperAdmin;
  final String? adminDepartment;

  const ReportStudentPage({
    super.key,
    this.isSuperAdmin = false,
    this.adminDepartment,
  });

  @override
  State<ReportStudentPage> createState() => _ReportStudentPageState();
}

class _ReportStudentPageState extends State<ReportStudentPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  String _selectedDeptFilter = 'All Departments';

  // Specific department list matching the system registry
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
    _syncFilter();
  }

  @override
  void didUpdateWidget(ReportStudentPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.adminDepartment != widget.adminDepartment) {
      _syncFilter();
    }
  }

  void _syncFilter() {
    // If regular admin, default to their department
    if (!widget.isSuperAdmin && widget.adminDepartment != null) {
      final String normalizedDept = widget.adminDepartment!.trim();

      // Safety check: Ensure the department exists in the list to avoid dropdown errors
      if (_departments.contains(normalizedDept)) {
        setState(() => _selectedDeptFilter = normalizedDept);
      } else {
        // If the admin's department is unique/custom, we add it to the dropdown dynamically
        // to prevent a crash, while keeping the main list clean.
        setState(() {
          if (!_departments.contains(normalizedDept)) {
            _departments.add(normalizedDept);
          }
          _selectedDeptFilter = normalizedDept;
        });
      }
    }
  }

  // Logic to handle reporting with a polished dialog
  Future<void> _reportStudent(Student student) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;

    await showDialog(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark
                  ? const Color(0xFF1E293B)
                  : theme.colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              title: Row(
                children: [
                  Icon(
                    Icons.report_gmailerrorred_rounded,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'File Incident Report',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Reporting: ${student.name}",
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: reasonController,
                      maxLines: 4,
                      autofocus: true,
                      enabled: !isSubmitting,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Incident Details',
                        hintText: 'Provide context for this report...',
                        alignLabelWithHint: true,
                        filled: true,
                        fillColor: isDark
                            ? Colors.white.withOpacity(0.05)
                            : theme.colorScheme.surfaceVariant.withOpacity(0.3),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                          ? 'Required'
                          : null,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (formKey.currentState!.validate()) {
                            setDialogState(() => isSubmitting = true);
                            try {
                              await FirebaseFirestore.instance
                                  .collection('reports')
                                  .add({
                                    'studentId': student.id,
                                    'studentName': student.name,
                                    'studentDepartment': student.department,
                                    'studentYear': student.year,
                                    'reason': reasonController.text.trim(),
                                    'timestamp': FieldValue.serverTimestamp(),
                                  });
                              if (context.mounted) Navigator.pop(context);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Incident report for ${student.name} submitted',
                                    ),
                                    backgroundColor: theme.colorScheme.error,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            } catch (e) {
                              setDialogState(() => isSubmitting = false);
                            }
                          }
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.error,
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Submit Report'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Report Student',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildHeader(theme, isDark),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('students')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError)
                  return const Center(child: Text('Error fetching data'));
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());

                final students = snapshot.data!.docs
                    .map((doc) => Student.fromFirestore(doc))
                    .where((s) {
                      final matchesSearch =
                          s.name.toLowerCase().contains(
                            _searchQuery.toLowerCase(),
                          ) ||
                          s.id.toLowerCase().contains(
                            _searchQuery.toLowerCase(),
                          );

                      // Normalize comparison strings
                      final String studentDept = s.department
                          .trim()
                          .toLowerCase();
                      final String targetDept = _selectedDeptFilter
                          .trim()
                          .toLowerCase();

                      final matchesDept =
                          _selectedDeptFilter == 'All Departments' ||
                          studentDept == targetDept;

                      return matchesSearch && matchesDept;
                    })
                    .toList();

                if (students.isEmpty) return _buildEmptyState(theme, isDark);

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 20,
                  ),
                  itemCount: students.length,
                  itemBuilder: (context, index) =>
                      _buildStudentItem(students[index], theme, isDark),
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
                "DIRECTORY SEARCH",
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.bold,
                ),
              ),
              _buildDeptFilter(theme, isDark),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _searchQuery = v),
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              hintText: 'Search by name or student ID...',
              hintStyle: TextStyle(
                color: isDark ? Colors.white38 : Colors.black38,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: theme.colorScheme.primary,
              ),
              filled: true,
              fillColor: isDark
                  ? Colors.white.withOpacity(0.05)
                  : theme.colorScheme.surfaceVariant.withOpacity(0.3),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
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
            if (newValue != null)
              setState(() => _selectedDeptFilter = newValue);
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

  Widget _buildStudentItem(Student student, ThemeData theme, bool isDark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: theme.dividerColor.withOpacity(0.08)),
      ),
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
          child: Text(
            student.name.isNotEmpty ? student.name[0].toUpperCase() : '?',
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          student.name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "${student.department} • Year ${student.year}",
              style: TextStyle(
                color: isDark ? Colors.white38 : theme.disabledColor,
              ),
            ),
            Text(
              "ID: ${student.id}",
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark ? Colors.white38 : theme.disabledColor,
              ),
            ),
          ],
        ),
        trailing: IconButton.filledTonal(
          onPressed: () => _reportStudent(student),
          icon: const Icon(Icons.report_problem_rounded),
          style: IconButton.styleFrom(
            foregroundColor: theme.colorScheme.error,
            backgroundColor: theme.colorScheme.errorContainer.withOpacity(
              isDark ? 0.2 : 0.4,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_search_rounded,
            size: 80,
            color: isDark
                ? Colors.white10
                : theme.disabledColor.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty ? 'No students found' : 'No matching results',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white38 : theme.disabledColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _searchQuery.isEmpty
                ? 'The directory for $_selectedDeptFilter is empty.'
                : 'Try a different name, ID, or department filter.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? Colors.white38 : theme.disabledColor,
            ),
          ),
        ],
      ),
    );
  }
}
