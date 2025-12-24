import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:latepass/admin/student_model.dart';

class AddRemoveStudentsPage extends StatefulWidget {
  final bool isSuperAdmin;
  final String? initialDepartment;

  const AddRemoveStudentsPage({
    super.key,
    this.isSuperAdmin = false,
    this.initialDepartment,
  });

  @override
  State<AddRemoveStudentsPage> createState() => _AddRemoveStudentsPageState();
}

class _AddRemoveStudentsPageState extends State<AddRemoveStudentsPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = "";
  String _selectedDeptFilter = 'All Departments';
  bool _isImporting = false;

  // Finalized department list - NO "General" allowed
  final List<String> _departments = [
    'All Departments',
    'Computer Engineering',
    'Electronics',
    'Mechanical',
    'Civil',
    'Electrical',
  ];

  // Selection State
  final Set<String> _selectedIds = {};
  List<Student> _currentFilteredStudents = [];

  @override
  void initState() {
    super.initState();
    // Enforce department locking for non-superadmins.
    if (!widget.isSuperAdmin) {
      // Logic: Lock the view and actions to the Admin's specific department
      if (widget.initialDepartment != null &&
          _departments.contains(widget.initialDepartment) &&
          widget.initialDepartment != 'All Departments') {
        _selectedDeptFilter = widget.initialDepartment!;
      } else {
        // Fallback only if metadata is missing
        _selectedDeptFilter = _departments[1];
      }
    } else if (widget.initialDepartment != null &&
        widget.initialDepartment!.isNotEmpty) {
      _selectedDeptFilter = widget.initialDepartment!;
    }
  }

  Future<void> _startBulkImport() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx'],
        withData: true,
      );

      if (result == null || result.files.single.bytes == null) return;

      setState(() => _isImporting = true);

      final file = result.files.single;
      final fileBytes = file.bytes!;
      List<Map<String, dynamic>> studentsData = [];

      if (file.extension == 'xlsx') {
        studentsData = _parseExcel(fileBytes);
      } else if (file.extension == 'csv') {
        studentsData = _parseCsv(fileBytes);
      }

      if (studentsData.isEmpty) {
        throw Exception(
          "No valid student records found. Check headers: id, name, department, year",
        );
      }

      final WriteBatch batch = _firestore.batch();
      int count = 0;

      for (var student in studentsData) {
        final String? docId = student['id']?.toString().trim();
        if (docId != null && docId.isNotEmpty) {
          final docRef = _firestore.collection('students').doc(docId);

          // Force strict departmental validity
          String studentDept;
          if (widget.isSuperAdmin) {
            final String rawImportDept =
                student['department']?.toString().trim() ?? "";
            studentDept = _departments.contains(rawImportDept)
                ? rawImportDept
                : _departments[1];
          } else {
            // Regular Admins can ONLY import into their own department
            studentDept = widget.initialDepartment ?? _departments[1];
          }

          batch.set(docRef, {
            'id': docId,
            'name': student['name']?.toString() ?? 'Unknown',
            'department': studentDept,
            'year': int.tryParse(student['year']?.toString() ?? '1') ?? 1,
          });
          count++;
        }
        if (count >= 500) break;
      }

      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Successfully imported $count students to ${widget.isSuperAdmin ? "Registry" : _selectedDeptFilter}',
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Import Failed: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  List<Map<String, dynamic>> _parseExcel(Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);
    final List<Map<String, dynamic>> results = [];

    for (var table in excel.tables.keys) {
      final sheet = excel.tables[table]!;
      if (sheet.maxRows < 2) continue;

      final headers = sheet.rows.first
          .map((cell) => cell?.value.toString().toLowerCase().trim())
          .toList();

      for (var i = 1; i < sheet.rows.length; i++) {
        final row = sheet.rows[i];
        final Map<String, dynamic> student = {};
        for (var j = 0; j < headers.length; j++) {
          final header = headers[j];
          if (header != null && j < row.length) {
            student[header] = row[j]?.value;
          }
        }
        results.add(student);
      }
    }
    return results;
  }

  List<Map<String, dynamic>> _parseCsv(Uint8List bytes) {
    final csvString = utf8.decode(bytes);
    final List<List<dynamic>> rows = const CsvToListConverter().convert(
      csvString,
    );
    if (rows.length < 2) return [];

    final List<Map<String, dynamic>> results = [];
    final headers = rows.first
        .map((h) => h.toString().toLowerCase().trim())
        .toList();

    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      final Map<String, dynamic> student = {};
      for (var j = 0; j < headers.length; j++) {
        if (j < row.length) student[headers[j]] = row[j];
      }
      results.add(student);
    }
    return results;
  }

  void _addStudent() {
    final idController = TextEditingController();
    final nameController = TextEditingController();

    // Default selection is now locked to the admin's department
    String? selectedDepartment = widget.isSuperAdmin
        ? (_selectedDeptFilter == 'All Departments'
              ? _departments[1]
              : _selectedDeptFilter)
        : (widget.initialDepartment ?? _departments[1]);

    int? selectedYear;

    // Filtered choices for regular admins: only their own department is selectable
    final List<String> availableDepartments = widget.isSuperAdmin
        ? _departments.where((d) => d != 'All Departments').toList()
        : [widget.initialDepartment ?? _departments[1]];

    final List<int> years = [1, 2, 3];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          title: const Text(
            'Add New Student',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDialogField(
                    controller: idController,
                    label: 'Admission ID',
                    hint: 'e.g. 2024CS01',
                    icon: Icons.badge_outlined,
                  ),
                  const SizedBox(height: 16),
                  _buildDialogField(
                    controller: nameController,
                    label: 'Full Name',
                    hint: 'Enter student name',
                    icon: Icons.person_outline_rounded,
                  ),
                  const SizedBox(height: 16),

                  _buildDialogDropdown<String>(
                    label: 'Department',
                    value: selectedDepartment,
                    items: availableDepartments,
                    icon: Icons.business_rounded,
                    onChanged: (val) =>
                        setDialogState(() => selectedDepartment = val),
                  ),
                  const SizedBox(height: 16),
                  _buildDialogDropdown<int>(
                    label: 'Current Year',
                    value: selectedYear,
                    items: years,
                    icon: Icons.school_rounded,
                    onChanged: (val) =>
                        setDialogState(() => selectedYear = val),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                  await _firestore
                      .collection('students')
                      .doc(idController.text.trim())
                      .set({
                        'id': idController.text.trim(),
                        'name': nameController.text.trim(),
                        'department': selectedDepartment,
                        'year': selectedYear,
                      });
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: const Text('Save Student'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteSelectedStudents() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text('Remove ${_selectedIds.length} Students?'),
        content: const Text(
          'This action is permanent and will remove selected student profiles from the database.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final batch = _firestore.batch();
      for (var id in _selectedIds) {
        batch.delete(_firestore.collection('students').doc(id));
      }
      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully removed ${_selectedIds.length} students'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      setState(() => _selectedIds.clear());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    bool isSelectionMode = _selectedIds.isNotEmpty;

    // Security Gate: Prevent access if user is not a SuperAdmin and has no department
    if (!widget.isSuperAdmin && widget.initialDepartment == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Access Denied")),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_person_rounded, size: 80, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                "Unauthorized Access",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              Text("Only Admins and SuperAdmins can view this page."),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(
          isSelectionMode
              ? '${_selectedIds.length} Selected'
              : 'Student Database',
        ),
        centerTitle: true,
        backgroundColor: isSelectionMode
            ? theme.colorScheme.primaryContainer
            : null,
        foregroundColor: isSelectionMode
            ? theme.colorScheme.onPrimaryContainer
            : null,
        actions: [
          if (isSelectionMode) ...[
            IconButton(
              icon: const Icon(Icons.select_all_rounded),
              onPressed: () => setState(
                () => _selectedIds.addAll(
                  _currentFilteredStudents.map((s) => s.id),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded),
              onPressed: _deleteSelectedStudents,
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () => setState(() => _selectedIds.clear()),
            ),
          ] else
            IconButton(
              onPressed: _startBulkImport,
              icon: const Icon(Icons.drive_folder_upload_rounded),
            ),
        ],
      ),
      floatingActionButton: isSelectionMode
          ? null
          : FloatingActionButton.extended(
              onPressed: _addStudent,
              icon: const Icon(Icons.add_rounded),
              label: const Text('New Student'),
            ),
      body: Stack(
        children: [
          Column(
            children: [
              _buildHeader(theme),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _firestore.collection('students').snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError)
                      return const Center(
                        child: Text("Error fetching records"),
                      );
                    if (!snapshot.hasData)
                      return const Center(child: CircularProgressIndicator());

                    final allStudents = snapshot.data!.docs
                        .map((doc) => Student.fromFirestore(doc))
                        .toList();
                    _currentFilteredStudents = allStudents.where((s) {
                      final q = _searchQuery.toLowerCase();
                      final matchesSearch =
                          s.name.toLowerCase().contains(q) ||
                          s.id.toLowerCase().contains(q);

                      // Filter list: Regular Admins are hard-locked to their own department
                      bool matchesDept;
                      if (widget.isSuperAdmin) {
                        matchesDept =
                            (_selectedDeptFilter == 'All Departments' ||
                            s.department == _selectedDeptFilter);
                      } else {
                        matchesDept =
                            (s.department == widget.initialDepartment);
                      }

                      return matchesSearch && matchesDept;
                    }).toList();

                    if (_currentFilteredStudents.isEmpty)
                      return _buildEmptyState(theme);

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 20,
                      ),
                      itemCount: _currentFilteredStudents.length,
                      itemBuilder: (context, index) => _buildStudentCard(
                        _currentFilteredStudents[index],
                        theme,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          if (_isImporting) _buildImportOverlay(theme),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: theme.dividerColor.withOpacity(0.05)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "REGISTRY MANAGEMENT",
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (widget.isSuperAdmin) _buildDeptFilter(theme),
              if (!widget.isSuperAdmin)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    widget.initialDepartment ?? "Registry",
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'Search by student name or ID...',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
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

  Widget _buildDeptFilter(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
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
          items: _departments
              .map<DropdownMenuItem<String>>(
                (String value) => DropdownMenuItem<String>(
                  value: value,
                  child: Text(
                    value == 'All Departments' ? 'Global View' : value,
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildStudentCard(Student student, ThemeData theme) {
    final isSelected = _selectedIds.contains(student.id);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.dividerColor.withOpacity(0.1),
          width: isSelected ? 2 : 1,
        ),
      ),
      color: isSelected
          ? theme.colorScheme.primaryContainer.withOpacity(0.2)
          : null,
      child: ListTile(
        onLongPress: () => setState(() => _selectedIds.add(student.id)),
        onTap: () {
          if (_selectedIds.isNotEmpty)
            setState(
              () => isSelected
                  ? _selectedIds.remove(student.id)
                  : _selectedIds.add(student.id),
            );
        },
        leading: CircleAvatar(
          backgroundColor: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.primary.withOpacity(0.1),
          child: isSelected
              ? const Icon(Icons.check_rounded, color: Colors.white)
              : Text(
                  student.name[0].toUpperCase(),
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
        title: Text(
          student.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text("${student.department} • Year ${student.year}"),
        trailing: _selectedIds.isEmpty
            ? IconButton(
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: theme.colorScheme.error,
                ),
                onPressed: () => _confirmSingleDelete(student, theme),
              )
            : null,
      ),
    );
  }

  void _confirmSingleDelete(Student student, ThemeData theme) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Student?'),
        content: Text('Remove ${student.name} from registry?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              await _firestore.collection('students').doc(student.id).delete();
              if (context.mounted) Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.group_off_rounded,
            size: 80,
            color: theme.disabledColor.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty ? 'No students found' : 'No matching results',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            _searchQuery.isEmpty
                ? 'Add your first student to begin.'
                : 'Try a different search term.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.disabledColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImportOverlay(ThemeData theme) {
    return Container(
      color: Colors.black45,
      child: Center(
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 24),
                Text(
                  'Processing File...',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text('Syncing data with cloud registry'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDialogField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: Theme.of(
          context,
        ).colorScheme.surfaceVariant.withOpacity(0.2),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
    );
  }

  Widget _buildDialogDropdown<T>({
    required String label,
    required T? value,
    required List<T> items,
    required IconData icon,
    required Function(T?) onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      items: items
          .map((i) => DropdownMenuItem<T>(value: i, child: Text(i.toString())))
          .toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: Theme.of(
          context,
        ).colorScheme.surfaceVariant.withOpacity(0.2),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
      validator: (v) => v == null ? 'Required' : null,
    );
  }
}
