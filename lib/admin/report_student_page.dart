// ignore_for_file: library_private_types_in_public_api

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:latepass/admin/student_model.dart';

class ReportStudentPage extends StatefulWidget {
  const ReportStudentPage({super.key});

  @override
  _ReportStudentPageState createState() => _ReportStudentPageState();
}

class _ReportStudentPageState extends State<ReportStudentPage> {
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _searchQuery = "";

  // Theme Colors
  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color backgroundGrey = Color(0xFFF8FAFC);
  static const Color errorRed = Color(0xFFEF4444);

  void _reportStudent(Student student) {
    final TextEditingController reasonController = TextEditingController();
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              const Icon(Icons.report_gmailerrorred_rounded, color: errorRed),
              const SizedBox(width: 12),
              const Text(
                'Report Student',
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
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: reasonController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Reason for reporting',
                    hintText: 'Describe the incident...',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  validator: (value) => (value == null || value.isEmpty)
                      ? 'Please provide a reason'
                      : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  _firestore.collection('reports').add({
                    'studentId': student.id,
                    'studentName': student.name,
                    'studentDepartment': student.department,
                    'studentYear': student.year,
                    'reason': reasonController.text.trim(),
                    'timestamp': FieldValue.serverTimestamp(),
                  });
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${student.name} has been reported'),
                      backgroundColor: errorRed,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: errorRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Submit Report'),
            ),
          ],
        );
      },
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
          'Report Incident',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: Column(
        children: [
          // Header & Search Bar
          Container(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Student Directory",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: InputDecoration(
                    hintText: 'Search by name or ID',
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: primaryBlue,
                    ),
                    filled: true,
                    fillColor: backgroundGrey,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: primaryBlue,
                        width: 1.5,
                      ),
                    ),
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
                if (snapshot.hasError) {
                  return const Center(child: Text('Error fetching students'));
                }
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: primaryBlue),
                  );
                }

                final students = snapshot.data!.docs
                    .map((doc) => Student.fromFirestore(doc))
                    .where(
                      (student) =>
                          student.name.toLowerCase().contains(
                            _searchQuery.toLowerCase(),
                          ) ||
                          student.id.toLowerCase().contains(
                            _searchQuery.toLowerCase(),
                          ),
                    )
                    .toList();

                if (students.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 64,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "No students found matching your search",
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: students.length,
                  itemBuilder: (context, index) {
                    final student = students[index];
                    return _buildStudentCard(student);
                  },
                );
              },
            ),
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
          backgroundColor: Colors.grey.shade100,
          child: const Icon(Icons.person_outline_rounded, color: primaryBlue),
        ),
        title: Text(
          student.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              "${student.department} • Year ${student.year}",
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            Text(
              "ID: ${student.id}",
              style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
            ),
          ],
        ),
        trailing: Container(
          decoration: BoxDecoration(
            color: errorRed.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(
              Icons.report_problem_rounded,
              color: errorRed,
              size: 22,
            ),
            onPressed: () => _reportStudent(student),
            tooltip: "Report Student",
          ),
        ),
      ),
    );
  }
}
