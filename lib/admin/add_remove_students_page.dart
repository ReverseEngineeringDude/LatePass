// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously, curly_braces_in_flow_control_structures, deprecated_member_use

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart'
    hide Border; // Hidden to avoid conflict with Flutter's Border class
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:latepass/admin/student_model.dart';

class AddRemoveStudentsPage extends StatefulWidget {
  const AddRemoveStudentsPage({super.key});

  @override
  _AddRemoveStudentsPageState createState() => _AddRemoveStudentsPageState();
}

class _AddRemoveStudentsPageState extends State<AddRemoveStudentsPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = "";
  bool _isImporting = false;

  // Selection State
  final Set<String> _selectedIds = {};
  List<Student> _currentFilteredStudents = [];

  /// Starts the bulk import process by letting the user pick a file.
  Future<void> _startBulkImport() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx'],
        withData: true,
      );

      if (result == null || result.files.single.bytes == null) {
        return;
      }

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
          batch.set(docRef, {
            'id': docId,
            'name': student['name']?.toString() ?? 'Unknown',
            'department': student['department']?.toString() ?? 'General',
            'year': int.tryParse(student['year']?.toString() ?? '1') ?? 1,
          });
          count++;
        }

        if (count >= 500) break;
      }

      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully imported $count students'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
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
          if (header != null) {
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
        student[headers[j]] = row[j];
      }
      results.add(student);
    }
    return results;
  }

  void _addStudent() {
    final TextEditingController idController = TextEditingController();
    final TextEditingController nameController = TextEditingController();
    String? selectedDepartment;
    int? selectedYear;

    final List<String> departments = [
      'Computer Engineering',
      'Electronics',
      'Mechanical',
      'Civil',
      'Electrical',
    ];
    final List<int> years = [1, 2, 3, 4];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
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
                  _buildDialogTextField(
                    controller: idController,
                    label: 'Admission ID',
                    hint: 'e.g. 2024CS01',
                    icon: Icons.badge_outlined,
                  ),
                  const SizedBox(height: 16),
                  _buildDialogTextField(
                    controller: nameController,
                    label: 'Full Name',
                    hint: 'Enter student name',
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: 16),
                  _buildDialogDropdown<String>(
                    label: 'Department',
                    value: selectedDepartment,
                    items: departments,
                    icon: Icons.business_rounded,
                    onChanged: (val) =>
                        setDialogState(() => selectedDepartment = val),
                  ),
                  const SizedBox(height: 16),
                  _buildDialogDropdown<int>(
                    label: 'Current Year',
                    value: selectedYear,
                    items: years,
                    icon: Icons.school_outlined,
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
            ElevatedButton(
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  _firestore
                      .collection('students')
                      .doc(idController.text.trim())
                      .set({
                        'id': idController.text.trim(),
                        'name': nameController.text.trim(),
                        'department': selectedDepartment,
                        'year': selectedYear,
                      });
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Add Student'),
            ),
          ],
        ),
      ),
    );
  }

  void _selectAll() {
    setState(() {
      for (var student in _currentFilteredStudents) {
        _selectedIds.add(student.id);
      }
    });
  }

  Future<void> _deleteSelectedStudents() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${_selectedIds.length} students?'),
        content: const Text(
          'This action is permanent and will remove all selected student profiles.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete',
              style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.bold),
            ),
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Removed ${_selectedIds.length} students')),
      );

      setState(() {
        _selectedIds.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    bool isSelectionMode = _selectedIds.isNotEmpty;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isSelectionMode ? theme.colorScheme.primary : theme.appBarTheme.backgroundColor,
        iconTheme: isSelectionMode ? theme.primaryIconTheme : theme.iconTheme,
        title: Text(
          isSelectionMode
              ? '${_selectedIds.length} Selected'
              : 'Student Management',
          style: TextStyle(
            color: isSelectionMode ? theme.colorScheme.onPrimary : theme.textTheme.titleLarge?.color,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          if (isSelectionMode)
            IconButton(
              icon: const Icon(Icons.select_all_rounded),
              tooltip: 'Select All Visible',
              onPressed: _selectAll,
            ),
          if (isSelectionMode)
            IconButton(
              icon: const Icon(Icons.delete_rounded),
              onPressed: _deleteSelectedStudents,
            ),
          if (isSelectionMode)
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () => setState(() => _selectedIds.clear()),
            ),
          if (!isSelectionMode)
            IconButton(
              onPressed: _startBulkImport,
              icon: Icon(Icons.upload_file_rounded, color: theme.colorScheme.primary),
              tooltip: 'Bulk Import (Excel/CSV)',
            ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: isSelectionMode
          ? null
          : FloatingActionButton.extended(
              onPressed: _addStudent,
              backgroundColor: theme.colorScheme.primary,
              icon: Icon(Icons.add_rounded, color: theme.colorScheme.onPrimary),
              label: Text(
                'Add Student',
                style: TextStyle(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
      body: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(32),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Database Registry",
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodySmall?.color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Manage Students",
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _searchController,
                      onChanged: (value) =>
                          setState(() => _searchQuery = value),
                      decoration: InputDecoration(
                        hintText: 'Search by Name or ID',
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: theme.colorScheme.primary,
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = "");
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: theme.scaffoldBackgroundColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      ),
                    ),
                  ],
                ),
              ),

              // Student List
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _firestore.collection('students').snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError)
                      return const Center(child: Text("Error loading data"));
                    if (!snapshot.hasData)
                      return Center(
                        child: CircularProgressIndicator(color: theme.colorScheme.primary),
                      );

                    final allStudents = snapshot.data!.docs
                        .map((doc) => Student.fromFirestore(doc))
                        .toList();

                    _currentFilteredStudents = allStudents.where((s) {
                      final query = _searchQuery.toLowerCase();
                      return s.name.toLowerCase().contains(query) ||
                          s.id.toLowerCase().contains(query);
                    }).toList();

                    if (_currentFilteredStudents.isEmpty)
                      return _buildEmptyState();

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                      itemCount: _currentFilteredStudents.length,
                      itemBuilder: (context, index) {
                        final student = _currentFilteredStudents[index];
                        final isSelected = _selectedIds.contains(student.id);
                        return _buildStudentCard(student, isSelected);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          if (_isImporting) _buildImportOverlay(),
        ],
      ),
    );
  }

  Widget _buildImportOverlay() {
    final theme = Theme.of(context);
    return Container(
      color: Colors.black54,
      child: Center(
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: theme.colorScheme.primary),
                const SizedBox(height: 24),
                Text(
                  "Bulk Importing...",
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  "Processing your document and updating the registry.",
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _searchQuery.isEmpty
                ? Icons.people_outline_rounded
                : Icons.search_off_rounded,
            size: 64,
            color: theme.dividerColor,
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty
                ? "No students registered yet"
                : "No matching students found",
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildStudentCard(Student student, bool isSelected) {
    final theme = Theme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected ? theme.colorScheme.primary.withOpacity(0.05) : theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? theme.colorScheme.primary : Colors.transparent,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onLongPress: () {
          setState(() {
            if (isSelected)
              _selectedIds.remove(student.id);
            else
              _selectedIds.add(student.id);
          });
        },
        onTap: () {
          if (_selectedIds.isNotEmpty) {
            setState(() {
              if (isSelected)
                _selectedIds.remove(student.id);
              else
                _selectedIds.add(student.id);
            });
          }
        },
        leading: isSelected
            ? CircleAvatar(
                backgroundColor: theme.colorScheme.primary,
                child: Icon(Icons.check, color: theme.colorScheme.onPrimary, size: 20),
              )
            : CircleAvatar(
                backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                child: Icon(Icons.person, color: theme.colorScheme.primary, size: 20),
              ),
        title: Text(
          student.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text(
          "${student.department} • Year ${student.year}",
          style: theme.textTheme.bodySmall,
        ),
        trailing: isSelected
            ? null
            : IconButton(
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: theme.colorScheme.error,
                  size: 22,
                ),
                onPressed: () => _confirmDelete(student),
              ),
      ),
    );
  }

  void _confirmDelete(Student student) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Remove Student?'),
        content: Text('Delete ${student.name} from the database?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _firestore.collection('students').doc(student.id).delete();
              Navigator.pop(context);
            },
            child: Text('Remove', style: TextStyle(color: theme.colorScheme.error)),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogTextField({
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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      validator: (value) =>
          (value == null || value.isEmpty) ? 'Required' : null,
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
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      items: items
          .map(
            (item) =>
                DropdownMenuItem<T>(value: item, child: Text(item.toString())),
          )
          .toList(),
      onChanged: onChanged,
      validator: (val) => val == null ? 'Required' : null,
    );
  }
}
