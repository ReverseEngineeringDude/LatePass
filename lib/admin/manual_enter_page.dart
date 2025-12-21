// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously, deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:latepass/admin/student_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:latepass/admin/todays_attendance_page.dart';

class ManualEnterPage extends StatefulWidget {
  const ManualEnterPage({super.key});

  @override
  _ManualEnterPageState createState() => _ManualEnterPageState();
}

class _ManualEnterPageState extends State<ManualEnterPage> {
  final TextEditingController _controller = TextEditingController();
  Student? _student;
  bool _isSearching = false;
  bool _isMarking = false;

  // Theme Colors consistent with the portal design
  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color backgroundGrey = Color(0xFFF8FAFC);

  Future<void> _findStudent() async {
    final id = _controller.text.trim();
    if (id.isEmpty) return;

    setState(() {
      _isSearching = true;
      _student = null;
    });

    try {
      final studentDoc = await FirebaseFirestore.instance
          .collection('students')
          .doc(id)
          .get();

      if (studentDoc.exists) {
        setState(() {
          _student = Student.fromFirestore(studentDoc);
        });
      } else {
        setState(() {
          _student = Student(
            id: '',
            name: 'Not Found',
            department: '',
            year: 0,
          );
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error searching for student')),
      );
    } finally {
      setState(() => _isSearching = false);
      FocusScope.of(context).unfocus();
    }
  }

  void _addStudentToAttendance() async {
    if (_student != null && _student!.id != '') {
      setState(() => _isMarking = true);
      try {
        final now = DateTime.now();
        final startOfDay = DateTime(now.year, now.month, now.day);
        final endOfDay = startOfDay.add(const Duration(days: 1));

        final attendanceQuery = await FirebaseFirestore.instance
            .collection('attendance')
            .where('studentId', isEqualTo: _student!.id)
            .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
            .where('timestamp', isLessThan: endOfDay)
            .get();

        if (attendanceQuery.docs.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Attendance already marked for today'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }

        final adminId = FirebaseAuth.instance.currentUser!.uid;

        await FirebaseFirestore.instance.collection('attendance').add({
          'studentId': _student!.id,
          'timestamp': FieldValue.serverTimestamp(),
          'markedBy': adminId,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_student!.name} marked as present'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const TodaysAttendancePage()),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to mark attendance')),
        );
      } finally {
        setState(() => _isMarking = false);
      }
    }
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
          'Manual Entry',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // Search Header Section
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
                  "Manual ID Entry",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        onSubmitted: (_) => _findStudent(),
                        decoration: InputDecoration(
                          hintText: 'Enter Student ID',
                          prefixIcon: const Icon(
                            Icons.badge_outlined,
                            color: primaryBlue,
                          ),
                          filled: true,
                          fillColor: backgroundGrey,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 16,
                          ),
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
                    ),
                    const SizedBox(width: 12),
                    Container(
                      height: 54,
                      width: 54,
                      decoration: BoxDecoration(
                        color: primaryBlue,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: IconButton(
                        onPressed: _isSearching ? null : _findStudent,
                        icon: _isSearching
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.search_rounded,
                                color: Colors.white,
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Search Result View
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  if (_student == null && !_isSearching)
                    _buildStateHint(
                      Icons.manage_search_rounded,
                      "Search for a student to mark attendance",
                    ),

                  if (_student != null && _student!.id != '')
                    _buildStudentResultCard(),

                  if (_student != null && _student!.id == '')
                    _buildStateHint(
                      Icons.error_outline_rounded,
                      "Student not found in database",
                      isError: true,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStateHint(IconData icon, String text, {bool isError = false}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 60),
          Icon(
            icon,
            size: 80,
            color: isError ? Colors.red.withOpacity(0.2) : Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentResultCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header of the card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: primaryBlue.withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: primaryBlue,
                  child: Text(
                    _student!.name[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _student!.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        "ID: ${_student!.id}",
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Details Body
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                _buildDetailRow(
                  Icons.business_rounded,
                  "Department",
                  _student!.department,
                ),
                const Divider(height: 32),
                _buildDetailRow(
                  Icons.school_outlined,
                  "Current Year",
                  "Year ${_student!.year}",
                ),
                const SizedBox(height: 32),

                // Action Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isMarking ? null : _addStudentToAttendance,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isMarking
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Mark as Present',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
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

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade400),
        const SizedBox(width: 12),
        Text(
          "$label:",
          style: const TextStyle(
            color: Colors.black54,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
