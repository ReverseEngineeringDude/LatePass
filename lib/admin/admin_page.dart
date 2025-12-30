// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'dart:convert';
import 'dart:ui';
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

class _AdminPageState extends State<AdminPage> with TickerProviderStateMixin {
  late AnimationController _entryController;
  late AnimationController _backgroundController;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat(reverse: true);

    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    _backgroundController.dispose();
    super.dispose();
  }

  // --- Logic (Unchanged from your version) ---

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
          _showStatusSnackBar(
            'Attendance already marked for today',
            Colors.orange,
          );
          return false;
        }

        final student = Student.fromFirestore(studentDoc);
        final adminId = FirebaseAuth.instance.currentUser?.uid ?? 'system';

        await FirebaseFirestore.instance.collection('attendance').add({
          'studentId': student.id,
          'studentDepartment': student.department,
          'timestamp': FieldValue.serverTimestamp(),
          'markedBy': adminId,
        });

        if (!mounted) return false;

        _showStatusSnackBar('${student.name} marked as present', Colors.green);
        return true;
      } else {
        throw Exception('Student not found');
      }
    } catch (e) {
      if (!mounted) return false;
      _showStatusSnackBar('Student ID not found in database', Colors.redAccent);
      return false;
    }
  }

  void _showStatusSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        margin: const EdgeInsets.all(20),
      ),
    );
  }

  void _navigateTo(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => page));
  }

  // --- Animation Helper ---

  Widget _animate({
    required Widget child,
    required double delay,
    Offset slideOffset = const Offset(0, 30),
  }) {
    return AnimatedBuilder(
      animation: _entryController,
      builder: (context, child) {
        final curve = CurvedAnimation(
          parent: _entryController,
          curve: Interval(
            delay,
            (delay + 0.5).clamp(0.0, 1.0),
            curve: Curves.easeOutQuart,
          ),
        );
        return Opacity(
          opacity: curve.value,
          child: Transform.translate(
            offset: slideOffset * (1 - curve.value),
            child: child,
          ),
        );
      },
      child: child,
    );
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
        "icon": Icons.keyboard_alt_rounded,
        "color": Colors.amberAccent,
        "page": const ManualEnterPage(),
      },
      {
        "title": "Export Logs",
        "icon": Icons.ios_share_rounded,
        "color": Colors.orange,
        "page": const ExportDataPage(),
      },
      {
        "title": "Report Incident",
        "icon": Icons.report_gmailerrorred_rounded,
        "color": Colors.redAccent,
        "page": ReportStudentPage(
          isSuperAdmin: false,
          adminDepartment: widget.admin?.department,
        ),
      },
      {
        "title": "View Reports",
        "icon": Icons.bar_chart_rounded,
        "color": Colors.indigoAccent,
        "page": ShowReportsPage(
          isFaculty: widget.admin?.isFaculty ?? false,
          department: widget.admin?.department ?? "",
          isSuperAdmin: false,
        ),
      },
      {
        "title": "Registry",
        "icon": Icons.group_add_rounded,
        "color": Colors.pink,
        "page": AddRemoveStudentsPage(
          isSuperAdmin: false,
          initialDepartment: widget.admin?.department,
        ),
      },
      {
        "title": "Today's Logs",
        "icon": Icons.event_note_rounded,
        "color": Colors.cyan,
        "page": const TodaysAttendancePage(),
      },
    ];

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F1115)
          : const Color(0xFFF8FAFC),
      drawer: const AppDrawer(),
      body: Stack(
        children: [
          _buildAnimatedBackground(theme, isDark),
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildModernAppBar(theme, isDark),
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    _animate(
                      delay: 0.1,
                      slideOffset: const Offset(0, -20),
                      child: _buildHeader(theme, isDark),
                    ),
                    _animate(
                      delay: 0.3,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(28, 30, 24, 15),
                        child: Row(
                          children: [
                            Text(
                              "MANAGEMENT TOOLS",
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.primary,
                                letterSpacing: 2.0,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: menuItems.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 18,
                            mainAxisSpacing: 18,
                            childAspectRatio: 1.05,
                          ),
                      itemBuilder: (context, index) {
                        final item = menuItems[index];
                        return _animate(
                          delay: 0.3 + (index * 0.05),
                          child: _buildMenuCard(
                            theme,
                            isDark,
                            title: item["title"],
                            icon: item["icon"],
                            color: item["color"],
                            onTap: () => _navigateTo(item["page"]),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 50),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedBackground(ThemeData theme, bool isDark) {
    return AnimatedBuilder(
      animation: _backgroundController,
      builder: (context, child) {
        final val = _backgroundController.value;
        return Stack(
          children: [
            Positioned(
              top: -100 + (30 * val),
              right: -50 - (20 * val),
              child: _BlurredCircle(
                color: theme.colorScheme.primary.withOpacity(
                  isDark ? 0.15 : 0.08,
                ),
                size: 350,
              ),
            ),
            Positioned(
              bottom: 100 - (40 * val),
              left: -100 + (30 * val),
              child: _BlurredCircle(
                color: Colors.purple.withOpacity(isDark ? 0.12 : 0.05),
                size: 300,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildModernAppBar(ThemeData theme, bool isDark) {
    return SliverAppBar(
      expandedHeight: 0,
      floating: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      leading: Builder(
        builder: (context) => IconButton(
          icon: Icon(Icons.menu_rounded, color: theme.colorScheme.onSurface),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ),
      title: Text(
        "CORE PANEL",
        style: TextStyle(
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
          fontSize: 14,
          color: theme.colorScheme.onSurface.withOpacity(0.6),
        ),
      ),
      actions: [
        _buildNotificationBadge(theme, isDark),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildNotificationBadge(ThemeData theme, bool isDark) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('reports').snapshots(),
      builder: (context, snapshot) {
        int reportCount = 0;
        if (snapshot.hasData) {
          final String adminDept = (widget.admin?.department ?? '')
              .trim()
              .toLowerCase();
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
          padding: const EdgeInsets.only(right: 12),
          child: Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: Icon(
                  Icons.notifications_none_rounded,
                  color: theme.colorScheme.onSurface,
                ),
                onPressed: () => _navigateTo(
                  ShowReportsPage(
                    isFaculty: widget.admin?.isFaculty ?? false,
                    department: widget.admin?.department ?? "",
                    isSuperAdmin: false,
                  ),
                ),
              ),
              if (reportCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '$reportCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(ThemeData theme, bool isDark) {
    final now = DateTime.now();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
        borderRadius: BorderRadius.circular(35),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.transparent,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  widget.admin?.isFaculty == true ? "FACULTY" : "STAFF",
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              Text(
                "${now.day} ${_getMonth(now.month)}",
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withOpacity(0.4),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 25),
          Text(
            "Welcome back,",
            style: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.4),
              fontSize: 16,
            ),
          ),
          Text(
            widget.admin?.name ?? 'Administrator',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: theme.colorScheme.onSurface,
              letterSpacing: -1.0,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            widget.admin?.department ?? 'Authorized Personnel',
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 35),
          _buildQuickStats(theme, isDark),
        ],
      ),
    );
  }

  Widget _buildQuickStats(ThemeData theme, bool isDark) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));

    return Row(
      children: [
        Expanded(
          child: _buildStatChip(
            theme,
            isDark,
            label: "Logged",
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
                final bool matchesDate =
                    ts != null &&
                    ts.toDate().isAfter(
                      start.subtract(const Duration(seconds: 1)),
                    ) &&
                    ts.toDate().isBefore(end);
                final bool matchesDept =
                    adminDept.isEmpty || studentDept == adminDept;
                return matchesDate && matchesDept;
              }).length;
            },
            icon: Icons.check_circle_rounded,
            color: Colors.blueAccent,
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: _buildStatChip(
            theme,
            isDark,
            label: "Reports",
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
            icon: Icons.warning_rounded,
            color: Colors.orange,
          ),
        ),
      ],
    );
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          StreamBuilder<QuerySnapshot>(
            stream: stream,
            builder: (context, snapshot) {
              final count = snapshot.hasData ? filter(snapshot.data!.docs) : 0;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    count.toString(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.4),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
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
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.transparent,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(30),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(height: 15),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
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
}

class _BlurredCircle extends StatelessWidget {
  final Color color;
  final double size;
  const _BlurredCircle({required this.color, required this.size});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color, blurRadius: 100, spreadRadius: 50)],
      ),
    );
  }
}
