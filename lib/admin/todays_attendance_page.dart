// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously, deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:latepass/admin/edit_attendance_page.dart';

class TodaysAttendancePage extends StatefulWidget {
  const TodaysAttendancePage({super.key});

  @override
  _TodaysAttendancePageState createState() => _TodaysAttendancePageState();
}

class _TodaysAttendancePageState extends State<TodaysAttendancePage> {
  // Theme Colors consistent with the portal design
  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color backgroundGrey = Color(0xFFF8FAFC);

  void _deleteAttendanceRecord(String recordId) {
    FirebaseFirestore.instance.collection('attendance').doc(recordId).delete();
  }

  void _showDeleteConfirmationDialog(String recordId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: const Text('Are you sure you want to delete this attendance record?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Delete'),
              onPressed: () {
                _deleteAttendanceRecord(recordId);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return Scaffold(
      backgroundColor: backgroundGrey,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text(
          "Today's Attendance",
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: Column(
        children: [
          // Header Section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24.0),
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
                Text(
                  "Attendance Logs",
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  "Daily Registry",
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('attendance')
                      .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
                      .where('timestamp', isLessThan: endOfDay)
                      .snapshots(),
                  builder: (context, snapshot) {
                    final count = snapshot.hasData
                        ? snapshot.data!.docs.length
                        : 0;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: primaryBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "$count Students Logged Today",
                        style: const TextStyle(
                          color: primaryBlue,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // Attendance List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('attendance')
                  .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
                  .where('timestamp', isLessThan: endOfDay)
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Text(
                        'An error occurred: ${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: primaryBlue),
                  );
                }

                final attendanceDocs = snapshot.data!.docs;

                if (attendanceDocs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.history_toggle_off_rounded,
                          size: 64,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No attendance records for today.',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: attendanceDocs.length,
                  itemBuilder: (context, index) {
                    final attendance = attendanceDocs[index];
                    return _buildAttendanceRecordCard(attendance);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceRecordCard(
    QueryDocumentSnapshot attendance,
  ) {
    final timestamp = attendance['timestamp'] as Timestamp?;
    final dateTime = timestamp?.toDate() ?? DateTime.now();
    final studentId = attendance['studentId'];
    final markedBy = attendance['markedBy'];
    // Manual time formatting
    int hour24 = dateTime.hour;
    int hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    String minute = dateTime.minute.toString().padLeft(2, '0');
    String period = hour24 >= 12 ? 'PM' : 'AM';
    String formattedTime = "$hour12:$minute $period";

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('students')
            .doc(studentId)
            .get(),
        builder: (context, studentSnapshot) {
          if (!studentSnapshot.hasData) {
            return const Padding(
              padding: EdgeInsets.all(20.0),
              child: Center(child: LinearProgressIndicator(minHeight: 2)),
            );
          }

          final studentData = studentSnapshot.data!;
          final studentName = studentData.exists
              ? (studentData['name'] ?? 'Unknown')
              : 'Unknown';
          final dept = studentData.exists
              ? (studentData['department'] ?? 'N/A')
              : 'N/A';

          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('admins')
                .doc(markedBy)
                .get(),
            builder: (context, adminSnapshot) {
              final adminName =
                  (adminSnapshot.hasData && adminSnapshot.data!.exists)
                  ? (adminSnapshot.data!['name'] ?? 'Admin')
                  : 'System';

              return Padding(
                padding: const EdgeInsets.fromLTRB(16,16,0,16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: primaryBlue.withOpacity(0.1),
                      child: Text(
                        studentName.isNotEmpty ? studentName[0].toUpperCase() : 'U',
                        style: const TextStyle(
                          color: primaryBlue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            studentName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            dept,
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: backgroundGrey,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              "Marked by: $adminName",
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Icon(
                          Icons.access_time_rounded,
                          size: 16,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formattedTime,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: primaryBlue,
                          ),
                        ),
                      ],
                    ),
                     PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                           Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EditAttendancePage(attendance: attendance),
                            ),
                          );
                        } else if (value == 'delete') {
                           _showDeleteConfirmationDialog(attendance.id);
                        }
                      },
                      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                        const PopupMenuItem<String>(
                          value: 'edit',
                          child: Text('Edit'),
                        ),
                        const PopupMenuItem<String>(
                          value: 'delete',
                          child: Text('Delete'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
