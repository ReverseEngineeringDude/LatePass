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
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  // Handles the scanning logic for QR/ID codes
  Future<bool> _handleScan(String value) async {
    try {
      final studentDoc = await FirebaseFirestore.instance
          .collection('students')
          .doc(value)
          .get();

      if (!mounted) return false;

      if (studentDoc.exists) {
        final now = DateTime.now();
        final startOfDay = DateTime(now.year, now.month, now.day);
        final endOfDay = startOfDay.add(const Duration(days: 1));

        // Check if student has already been marked today (Filtering in memory for reliability)
        final attendanceQuery = await FirebaseFirestore.instance
            .collection('attendance')
            .get();

        if (!mounted) return false;

        final isAlreadyMarked = attendanceQuery.docs.any((doc) {
          final data = doc.data();
          final ts = (data['timestamp'] as Timestamp?)?.toDate();
          return data['studentId'] == value &&
              ts != null &&
              ts.isAfter(startOfDay.subtract(const Duration(seconds: 1))) &&
              ts.isBefore(endOfDay);
        });

        if (isAlreadyMarked) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Attendance already marked for today'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return false;
        }

        final student = Student.fromFirestore(studentDoc);
        final adminId = FirebaseAuth.instance.currentUser?.uid ?? 'system';

        // Add to attendance log including department metadata for high-perf filtering
        await FirebaseFirestore.instance.collection('attendance').add({
          'studentId': student.id,
          'studentDepartment': student.department,
          'timestamp': FieldValue.serverTimestamp(),
          'markedBy': adminId,
        });

        if (!mounted) return false;

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
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Student ID not found in database'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }
  }

  void _navigateTo(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => page));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final List<Map<String, dynamic>> menuItems = [
      {
        "title": "ID Scan",
        "icon": Icons.qr_code_scanner_rounded,
        "color": theme.colorScheme.primary,
        "page": ScannerPage(onScan: _handleScan),
      },
      {
        "title": "Manual Enter",
        "icon": Icons.keyboard_alt_outlined,
        "color": Colors.greenAccent,
        "page": const ManualEnterPage(),
      },
      {
        "title": "Export Logs",
        "icon": Icons.ios_share_rounded,
        "color": Colors.orangeAccent,
        "page": const ExportDataPage(),
      },
      {
        "title": "Report Incident",
        "icon": Icons.report_problem_rounded,
        "color": Colors.redAccent,
        "page": ReportStudentPage(
          isSuperAdmin: false,
          adminDepartment: widget.admin?.department,
        ),
      },
      {
        "title": "View Reports",
        "icon": Icons.analytics_rounded,
        "color": Colors.purpleAccent,
        "page": ShowReportsPage(
          isFaculty: widget.admin?.isFaculty ?? false,
          department: widget.admin?.department ?? "",
          isSuperAdmin: false,
        ),
      },
      {
        "title": "Manage Registry",
        "icon": Icons.people_alt_rounded,
        "color": Colors.pinkAccent,
        "page": AddRemoveStudentsPage(
          isSuperAdmin: false,
          initialDepartment: widget.admin?.department,
        ),
      },
      {
        "title": "Today's Logs",
        "icon": Icons.today_rounded,
        "color": Colors.cyanAccent,
        "page": const TodaysAttendancePage(),
      },
    ];

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "Dashboard",
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : theme.colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('reports')
                .snapshots(),
            builder: (context, snapshot) {
              int reportCount = 0;
              if (snapshot.hasData) {
                final String adminDept = (widget.admin?.department ?? '')
                    .trim()
                    .toLowerCase();

                // Filter reports to match the admin's department.
                reportCount = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final String studentDept = (data['studentDepartment'] ?? '')
                      .toString()
                      .trim()
                      .toLowerCase();
                  return adminDept.isEmpty || studentDept == adminDept;
                }).length;
              }

              return Padding(
                padding: const EdgeInsets.only(right: 8.0, top: 8.0),
                child: IconButton(
                  icon: Badge(
                    label: Text(reportCount.toString()),
                    isLabelVisible: reportCount > 0,
                    backgroundColor: Colors.red,
                    child: Icon(
                      Icons.notifications_none_rounded,
                      color: isDark
                          ? Colors.white70
                          : theme.colorScheme.primary,
                    ),
                  ),
                  onPressed: () {
                    _navigateTo(
                      ShowReportsPage(
                        isFaculty: widget.admin?.isFaculty ?? false,
                        department: widget.admin?.department ?? "",
                        isSuperAdmin: false,
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: Stack(
        children: [
          if (isDark) ...[
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      theme.colorScheme.primary.withOpacity(0.08),
                      theme.colorScheme.primary.withOpacity(0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -50,
              left: -50,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.purple.withOpacity(0.05),
                      Colors.purple.withOpacity(0),
                    ],
                  ),
                ),
              ),
            ),
          ],

          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                _buildHeader(theme, isDark),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                  child: Row(
                    children: [
                      Text(
                        "MANAGEMENT TOOLS",
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: isDark
                              ? Colors.white38
                              : theme.colorScheme.primary,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
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
                      theme,
                      isDark,
                      title: item["title"],
                      icon: item["icon"],
                      color: item["color"],
                      onTap: () => _navigateTo(item["page"]),
                    );
                  },
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, bool isDark) {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(40)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.blueAccent.withOpacity(0.15)
                            : theme.colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: isDark
                            ? Border.all(
                                color: Colors.blueAccent.withOpacity(0.2),
                              )
                            : null,
                      ),
                      child: Text(
                        widget.admin?.isFaculty == true ? "FACULTY" : "STAFF",
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: isDark
                              ? Colors.blueAccent
                              : theme.colorScheme.primary,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    Text(
                      "${now.day} ${_getMonth(now.month)}",
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: isDark ? Colors.white38 : theme.disabledColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  "Welcome back,",
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: isDark ? Colors.white54 : theme.disabledColor,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                Text(
                  widget.admin?.name ?? 'Administrator',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.admin?.department ?? 'Authorized Personnel',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark ? Colors.white38 : theme.disabledColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          _buildQuickStats(theme, isDark, startOfDay, endOfDay),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildQuickStats(
    ThemeData theme,
    bool isDark,
    DateTime start,
    DateTime end,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          _buildStatChip(
            theme,
            isDark,
            label: "Logged Today",
            stream: FirebaseFirestore.instance
                .collection('attendance')
                .snapshots(),
            filter: (docs) {
              final String adminDept = (widget.admin?.department ?? '')
                  .trim()
                  .toLowerCase();
              return docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final ts = data['timestamp'] as Timestamp?;
                final String studentDept = (data['studentDepartment'] ?? '')
                    .toString()
                    .trim()
                    .toLowerCase();

                // Inclusive start of day check
                final bool matchesDate =
                    ts != null &&
                    ts.toDate().isAfter(
                      start.subtract(const Duration(seconds: 1)),
                    ) &&
                    ts.toDate().isBefore(end);

                // Match department or show all for superadmins/unassigned
                final bool matchesDept =
                    adminDept.isEmpty || studentDept == adminDept;

                return matchesDate && matchesDept;
              }).length;
            },
            icon: Icons.check_circle_rounded,
            color: Colors.blueAccent,
          ),
          const SizedBox(width: 12),
          _buildStatChip(
            theme,
            isDark,
            label: "Incident Reports",
            stream: FirebaseFirestore.instance
                .collection('reports')
                .snapshots(),
            filter: (docs) {
              final String adminDept = (widget.admin?.department ?? '')
                  .trim()
                  .toLowerCase();
              return docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final String studentDept = (data['studentDepartment'] ?? '')
                    .toString()
                    .trim()
                    .toLowerCase();
                return adminDept.isEmpty || studentDept == adminDept;
              }).length;
            },
            icon: Icons.warning_amber_rounded,
            color: Colors.orangeAccent,
          ),
        ],
      ),
    );
  }

  String _getMonth(int m) {
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
    return months[m - 1];
  }

  Widget _buildStatChip(
    ThemeData theme,
    bool isDark, {
    required String label,
    required Stream<QuerySnapshot> stream,
    required int Function(List<QueryDocumentSnapshot>) filter,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? color.withOpacity(0.08) : color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(isDark ? 0.2 : 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(width: 12),
          StreamBuilder<QuerySnapshot>(
            stream: stream,
            builder: (context, snapshot) {
              final count = snapshot.hasData ? filter(snapshot.data!.docs) : 0;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    count.toString(),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white38 : theme.disabledColor,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard(
    ThemeData theme,
    bool isDark, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(32),
          splashColor: color.withOpacity(0.1),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color.withOpacity(0.2), color.withOpacity(0.05)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 34),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: isDark
                        ? Colors.white.withOpacity(0.9)
                        : Colors.black87,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
