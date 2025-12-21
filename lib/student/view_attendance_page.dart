// ignore_for_file: library_private_types_in_public_api

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ViewAttendancePage extends StatefulWidget {
  const ViewAttendancePage({super.key});

  @override
  _ViewAttendancePageState createState() => _ViewAttendancePageState();
}

class _ViewAttendancePageState extends State<ViewAttendancePage> {
  final TextEditingController _studentIdController = TextEditingController();
  String? _studentId;

  // Theme Colors consistent with the rest of the app
  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color accentPurple = Color(0xFF7C3AED);
  static const Color backgroundGrey = Color(0xFFF8FAFC);

  void _viewAttendance() {
    if (_studentIdController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your admission number')),
      );
      return;
    }
    setState(() {
      _studentId = _studentIdController.text.trim();
    });
    // Unfocus keyboard
    FocusScope.of(context).unfocus();
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
          'Attendance Records',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // Search/Input Header
          Container(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
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
                  "Check Your History",
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
                        controller: _studentIdController,
                        decoration: InputDecoration(
                          hintText: 'Enter Admission Number',
                          prefixIcon: const Icon(
                            Icons.numbers_rounded,
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
                        onPressed: _viewAttendance,
                        icon: const Icon(
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

          // Attendance List
          Expanded(
            child: _studentId == null
                ? _buildInitialState()
                : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('attendance')
                        .where('studentId', isEqualTo: _studentId)
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return _buildErrorState(
                          'An error occurred. Please try again.',
                        );
                      }
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(color: primaryBlue),
                        );
                      }
                      final attendanceDocs = snapshot.data!.docs;
                      if (attendanceDocs.isEmpty) {
                        return _buildEmptyState();
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.all(24),
                        itemCount: attendanceDocs.length,
                        itemBuilder: (context, index) {
                          final attendance = attendanceDocs[index];
                          final timestamp =
                              attendance['timestamp'] as Timestamp?;
                          final dateTime =
                              timestamp?.toDate() ?? DateTime.now();

                          return _buildAttendanceCard(attendance, dateTime);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_search_rounded,
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            "Enter your ID to see your records",
            style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_toggle_off_rounded,
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          const Text(
            "No attendance records found.",
            style: TextStyle(
              color: Colors.black54,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Make sure your ID is correct.",
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.redAccent),
        ),
      ),
    );
  }

  Widget _buildAttendanceCard(DocumentSnapshot doc, DateTime dateTime) {
    // Manual formatting to remove dependency on 'intl' package
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    String dayName = weekdays[dateTime.weekday - 1];
    String monthName = months[dateTime.month - 1];
    String day = dateTime.day.toString();
    String year = dateTime.year.toString();

    int hour24 = dateTime.hour;
    int hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    String minute = dateTime.minute.toString().padLeft(2, '0');
    String period = hour24 >= 12 ? 'PM' : 'AM';

    String formattedDate = "$dayName, $monthName $day, $year";
    String formattedTime = "$hour12:$minute $period";

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.access_time_filled_rounded,
                color: Colors.orange,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Late Entry Marked',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "$formattedDate • $formattedTime",
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('admins')
                        .doc(doc['markedBy'])
                        .get(),
                    builder: (context, adminSnapshot) {
                      String adminName = "Super Admin";
                      if (adminSnapshot.hasData && adminSnapshot.data!.exists) {
                        adminName =
                            adminSnapshot.data!['name'] ?? "Super Admin";
                      }
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: backgroundGrey,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "Marked by: $adminName",
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.black54,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
