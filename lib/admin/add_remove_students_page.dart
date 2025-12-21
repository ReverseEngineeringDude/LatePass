// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
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
  bool _isImporting = false;

  // Theme Colors
  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color backgroundGrey = Color(0xFFF8FAFC);
  static const Color errorRed = Color(0xFFEF4444);

  /// Starts the bulk import process by letting the user pick a file.
  Future<void> _startBulkImport() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx'],
        withData: true, // Crucial for web/mobile to get bytes directly
      );

      if (result == null || result.files.single.bytes == null) {
        return; // User cancelled
      }

      setState(() => _isImporting = true);

      final file = result.files.single;
      final fileBytes = file.bytes!;
      List<Map<String, dynamic>> studentsData = [];

      // Parse the file based on extension
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

      // Execute Firestore Batch Write
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

        // Firestore batch limit is 500 operations
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
          backgroundColor: errorRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  /// Extracts data from Excel Bytes
  List<Map<String, dynamic>> _parseExcel(Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);
    final List<Map<String, dynamic>> results = [];

    for (var table in excel.tables.keys) {
      final sheet = excel.tables[table]!;
      if (sheet.maxRows < 2) continue;

      // Extract Headers from first row
      final headers = sheet.rows.first
          .map((cell) => cell?.value.toString().toLowerCase().trim())
          .toList();

      // Map rows to JSON objects
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

  /// Extracts data from CSV Bytes
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
                backgroundColor: primaryBlue,
                foregroundColor: Colors.white,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundGrey,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text(
          'Student Management',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _startBulkImport,
            icon: const Icon(Icons.upload_file_rounded, color: primaryBlue),
            tooltip: 'Bulk Import (Excel/CSV)',
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addStudent,
        backgroundColor: primaryBlue,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Add Student',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24.0),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(32),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Database Registry",
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Manage Students",
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _firestore.collection('students').snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData)
                      return const Center(
                        child: CircularProgressIndicator(color: primaryBlue),
                      );
                    final students = snapshot.data!.docs
                        .map((doc) => Student.fromFirestore(doc))
                        .toList();
                    if (students.isEmpty) return _buildEmptyState();
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                      itemCount: students.length,
                      itemBuilder: (context, index) =>
                          _buildStudentCard(students[index]),
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
              children: const [
                CircularProgressIndicator(color: primaryBlue),
                SizedBox(height: 24),
                Text(
                  "Bulk Importing...",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                SizedBox(height: 8),
                Text(
                  "Processing your document and updating the student registry.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline_rounded,
            size: 64,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            "No students registered yet",
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentCard(Student student) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: primaryBlue.withOpacity(0.1),
          child: const Icon(Icons.person, color: primaryBlue, size: 20),
        ),
        title: Text(
          student.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text(
          "${student.department} • Year ${student.year}",
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
        trailing: IconButton(
          icon: const Icon(
            Icons.delete_outline_rounded,
            color: errorRed,
            size: 22,
          ),
          onPressed: () => _confirmDelete(student),
        ),
      ),
    );
  }

  void _confirmDelete(Student student) {
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
            child: const Text('Remove', style: TextStyle(color: errorRed)),
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
      initialValue: value,
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
