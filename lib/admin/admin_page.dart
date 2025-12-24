// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously, deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:latepass/admin/add_remove_students_page.dart';
import 'package:latepass/admin/export_data_page.dart';
import 'package:latepass/admin/id_scan_page.dart';
import 'package:latepass/admin/manual_enter_page.dart';
import 'package:latepass/admin/report_student_page.dart';
import 'package:latepass/admin/show_reports_page.dart';
import 'package:latepass/admin/student_model.dart';
import 'package:latepass/admin/todays_attendance_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:latepass/shared/app_drawer.dart';
import 'package:latepass/superadmin/admin_model.dart';

class AdminPage extends StatefulWidget {
  final Admin? admin;

  const AdminPage({super.key, this.admin});

  @override
  _AdminPageState createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  Future<bool> _handleScan(String value) async {
    try {
      final studentDoc = await FirebaseFirestore.instance
          .collection('students')
          .doc(value)
          .get();

      if (studentDoc.exists) {
        final now = DateTime.now();
        final startOfDay = DateTime(now.year, now.month, now.day);
        final endOfDay = startOfDay.add(const Duration(days: 1));

        final attendanceQuery = await FirebaseFirestore.instance
            .collection('attendance')
            .where('studentId', isEqualTo: value)
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
          return false;
        }

        final student = Student.fromFirestore(studentDoc);
        final adminId = FirebaseAuth.instance.currentUser!.uid;

        await FirebaseFirestore.instance.collection('attendance').add({
          'studentId': student.id,
          'timestamp': FieldValue.serverTimestamp(),
          'markedBy': adminId,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${student.name} marked as present'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return true;
      } else {
        throw Exception('Student not found');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Student not found'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }
  }

  void _navigateToPage(BuildContext context, int index, List<Map<String, dynamic>> menuItems) {
    final List<Widget> pages = [
      Container(), // Placeholder for Id Scan
      ManualEnterPage(),
      ExportDataPage(),
      ReportStudentPage(),
      ShowReportsPage(
        isFaculty: widget.admin?.isFaculty ?? false,
        department: widget.admin?.department ?? "Computer Science",
        isSuperAdmin: false,
      ),
      AddRemoveStudentsPage(),
      const TodaysAttendancePage(),
    ];

    if (menuItems[index]["title"] == "Id Scan") {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ScannerPage(onScan: _handleScan),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => pages[index]),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final List<Map<String, dynamic>> menuItems = [
      {
        "title": "Id Scan",
        "icon": Icons.qr_code_scanner_rounded,
        "color": theme.colorScheme.primary,
      },
      {
        "title": "Manual Enter",
        "icon": Icons.keyboard_rounded,
        "color": Colors.green,
      },
      {
        "title": "Export Data",
        "icon": Icons.ios_share_rounded,
        "color": Colors.orange,
      },
      {
        "title": "Report Student",
        "icon": Icons.report_problem_rounded,
        "color": Colors.red,
      },
      {
        "title": "Show Reports",
        "icon": Icons.analytics_rounded,
        "color": Colors.purple,
      },
      {
        "title": "Add / Remove Students",
        "icon": Icons.people_alt_rounded,
        "color": Colors.pink,
      },
      {
        "title": "Today's Attendance",
        "icon": Icons.today_rounded,
        "color": Colors.cyan,
      },
    ];

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          "Admin Dashboard",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      drawer: AppDrawer(),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(32),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Department: ${widget.admin?.department ?? 'General'}",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.textTheme.bodySmall?.color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Hello, ${widget.admin?.name ?? 'Admin'}",
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Select a tool below to manage student attendance and reporting.",
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(height: 1.4),
                  ),
                ],
              ),
            ),

            const Padding(
              padding: EdgeInsets.fromLTRB(24, 32, 24, 16),
              child: Text(
                "Management Tools",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // Grid Menu
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: menuItems.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.1,
                ),
                itemBuilder: (context, index) {
                  final item = menuItems[index];
                  return _buildMenuCard(
                    title: item["title"],
                    icon: item["icon"],
                    color: item["color"],
                    onTap: () => _navigateToPage(context, index, menuItems),
                  );
                },
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
