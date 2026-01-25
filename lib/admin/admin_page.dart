// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:latepass/admin/late_comers_leaderboard_page.dart';
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

  // Cache student data to allow looking up missing info in old logs
  late Future<QuerySnapshot> _studentsFuture;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat(reverse: true);

    _entryController.forward();

    // Fetch students once on init for analytics lookup
    _studentsFuture = FirebaseFirestore.instance.collection('students').get();
  }

  @override
  void dispose() {
    _entryController.dispose();
    _backgroundController.dispose();
    super.dispose();
  }

  // --- Core Business Logic ---

  Future<bool> _handleScan(String value) async {
    try {
      final studentDoc = await FirebaseFirestore.instance
          .collection('students')
          .doc(value)
          .get();

      if (!mounted) {
        return false;
      }

      if (studentDoc.exists) {
        final now = DateTime.now();
        final startOfDay = DateTime(now.year, now.month, now.day);
        final endOfDay = startOfDay.add(const Duration(days: 1));

        final attendanceQuery = await FirebaseFirestore.instance
            .collection('attendance')
            .get();

        if (!mounted) {
          return false;
        }

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
            'Attendance already recorded today',
            Colors.orange,
          );
          return false;
        }

        final student = Student.fromFirestore(studentDoc);
        final adminId = FirebaseAuth.instance.currentUser?.uid ?? 'system';

        await FirebaseFirestore.instance.collection('attendance').add({
          'studentId': student.id,
          'studentDepartment': student.department,
          'studentYear': student.year,
          'timestamp': FieldValue.serverTimestamp(),
          'markedBy': adminId,
        });

        _showStatusSnackBar('${student.name} marked present', Colors.green);
        return true;
      } else {
        throw Exception('Not found');
      }
    } catch (e) {
      _showStatusSnackBar('Student ID not recognized', Colors.redAccent);
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

  Widget _animate({required Widget child, required double delay}) {
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
            offset: Offset(0, 30 * (1 - curve.value)),
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

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0B0E14)
          : const Color(0xFFF1F5F9),
      drawer: const AppDrawer(),
      body: Stack(
        children: [
          _buildAnimatedBackground(theme, isDark),
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildSliverAppBar(theme, isDark),
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _animate(
                      delay: 0.1,
                      child: _buildHeroSection(theme, isDark),
                    ),
                    _animate(
                      delay: 0.2,
                      child: _buildSectionTitle("SYSTEM PERFORMANCE", theme),
                    ),
                    _animate(
                      delay: 0.25,
                      child: _buildInsightsPanel(theme, isDark),
                    ),
                    _animate(
                      delay: 0.3,
                      child: _buildSectionTitle("ADMINISTRATIVE TOOLS", theme),
                    ),
                    _buildToolsGrid(theme, isDark),
                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(ThemeData theme, bool isDark) {
    return SliverAppBar(
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
        "LATENCY CONTROL",
        style: TextStyle(
          fontWeight: FontWeight.w900,
          letterSpacing: 2.5,
          fontSize: 10,
          color: theme.colorScheme.onSurface.withOpacity(0.5),
        ),
      ),
      actions: [
        _buildNotificationAction(theme, isDark),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildNotificationAction(ThemeData theme, bool isDark) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('reports').snapshots(),
      builder: (context, snapshot) {
        int count = 0;
        if (snapshot.hasData) {
          final String adminDept = (widget.admin?.department ?? '')
              .trim()
              .toLowerCase();
          count = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final String studentDept = (data['studentDepartment'] ?? '')
                .toString()
                .trim()
                .toLowerCase();
            return adminDept.isEmpty || studentDept == adminDept;
          }).length;
        }

        return Stack(
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
            if (count > 0)
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
                    '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildHeroSection(ThemeData theme, bool isDark) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.transparent,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _buildAvatar(theme),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Current Admin",
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.4),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      widget.admin?.name ?? 'Administrator',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              _buildSecurityStatus(),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: _buildInfoChip(
                  Icons.business_rounded,
                  widget.admin?.department ?? "Operations",
                  theme,
                ),
              ),
              const SizedBox(width: 8),
              _buildInfoChip(
                Icons.verified_user_rounded,
                widget.admin?.isFaculty == true ? "Faculty" : "Staff",
                theme,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(ThemeData theme) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.1),
        shape: BoxShape.circle,
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2)),
      ),
      child: Center(
        child: Text(
          (widget.admin?.name != null && widget.admin!.name.isNotEmpty)
              ? widget.admin!.name[0].toUpperCase()
              : "A",
          style: TextStyle(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
      ),
    );
  }

  Widget _buildSecurityStatus() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.greenAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.lock_rounded, size: 12, color: Colors.greenAccent),
          SizedBox(width: 4),
          Text(
            "SECURE",
            style: TextStyle(
              color: Colors.greenAccent,
              fontSize: 8,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withOpacity(0.03),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightsPanel(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          _buildTrendGraph(theme, isDark),
          const SizedBox(height: 16),
          _buildMetricCard(
            "Peak Intensity",
            _buildTimeAnalysis(),
            theme,
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildTrendGraph(ThemeData theme, bool isDark) {
    return Container(
      height: 240,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
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
              const Text(
                "Weekly Engagement",
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  "DYNAMIC",
                  style: TextStyle(
                    color: Colors.blueAccent,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          // Use StreamBuilder for students to ensure live updates
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('students')
                .snapshots(),
            builder: (context, studentSnapshot) {
              if (!studentSnapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                );
              }

              // Create lookup map for missing metadata
              final Map<String, Map<String, dynamic>> studentMap = {
                for (var doc in studentSnapshot.data!.docs)
                  doc.id: doc.data() as Map<String, dynamic>,
              };

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('attendance')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    );
                  }

                  final docs = snapshot.data!.docs;
                  final now = DateTime.now();
                  final String adminDept = (widget.admin?.department ?? '')
                      .trim()
                      .toLowerCase();

                  List<int> counts = List.filled(7, 0);
                  // Generate dynamic labels for the last 7 days
                  final weekDayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                  List<String> labels = List.filled(7, '');

                  for (int i = 0; i < 7; i++) {
                    final day = now.subtract(Duration(days: i));
                    labels[6 - i] = weekDayLabels[day.weekday - 1];

                    counts[6 - i] = docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final ts = data['timestamp'] as Timestamp?;

                      if (ts == null) {
                        return false;
                      }

                      // Resolve Department with Fallback
                      String studentDept = (data['studentDepartment'] ?? '')
                          .toString()
                          .trim()
                          .toLowerCase();
                      if (studentDept.isEmpty) {
                        final studentData =
                            studentMap[(data['studentId'] ?? '').toString()];
                        if (studentData != null) {
                          studentDept = (studentData['department'] ?? '')
                              .toString()
                              .trim()
                              .toLowerCase();
                        }
                      }

                      final date = ts.toDate();
                      return date.day == day.day &&
                          date.month == day.month &&
                          date.year == day.year &&
                          (adminDept.isEmpty || studentDept == adminDept);
                    }).length;
                  }

                  int max = counts.reduce((a, b) => a > b ? a : b);
                  if (max == 0) {
                    max = 1;
                  }

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(7, (index) {
                      final double h = (counts[index] / max) * 110;
                      return Column(
                        children: [
                          Text(
                            "${counts[index]}",
                            style: TextStyle(
                              fontSize: 8,
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.easeOutBack,
                            width: 18,
                            height: h.clamp(8, 110).toDouble(),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  theme.colorScheme.primary,
                                  theme.colorScheme.primary.withOpacity(0.2),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            labels[index],
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.3,
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
    String title,
    Widget content,
    ThemeData theme,
    bool isDark,
  ) {
    return Container(
      height: 190,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 11,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(child: content),
        ],
      ),
    );
  }

  Widget _buildTimeAnalysis() {
    return FutureBuilder<QuerySnapshot>(
      future: _studentsFuture,
      builder: (context, studentSnapshot) {
        if (!studentSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }

        final Map<String, Map<String, dynamic>> studentMap = {
          for (var doc in studentSnapshot.data!.docs)
            doc.id: doc.data() as Map<String, dynamic>,
        };

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('attendance')
              .snapshots(),
          builder: (context, snapshot) {
            int morning = 0, noon = 0, late = 0;
            if (snapshot.hasData) {
              final String adminDept = (widget.admin?.department ?? '')
                  .trim()
                  .toLowerCase();

              for (var doc in snapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                final ts = data['timestamp'] as Timestamp?;

                if (ts != null) {
                  // Resolve Department with Fallback
                  String studentDept = (data['studentDepartment'] ?? '')
                      .toString()
                      .trim()
                      .toLowerCase();
                  if (studentDept.isEmpty) {
                    final studentData =
                        studentMap[(data['studentId'] ?? '').toString()];
                    if (studentData != null) {
                      studentDept = (studentData['department'] ?? '')
                          .toString()
                          .trim()
                          .toLowerCase();
                    }
                  }

                  if (adminDept.isEmpty || studentDept == adminDept) {
                    int h = ts.toDate().hour;
                    if (h < 12) {
                      morning++;
                    } else if (h < 17) {
                      noon++;
                    } else {
                      late++;
                    }
                  }
                }
              }
            }
            int total = morning + noon + late;
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLinearAnalysisBar(
                  "AM",
                  morning,
                  total,
                  Colors.blueAccent,
                ),
                const SizedBox(height: 10),
                _buildLinearAnalysisBar(
                  "DAY",
                  noon,
                  total,
                  Colors.orangeAccent,
                ),
                const SizedBox(height: 10),
                _buildLinearAnalysisBar("PM", late, total, Colors.purpleAccent),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildLinearAnalysisBar(
    String label,
    int val,
    int total,
    Color color,
  ) {
    double factor = total == 0 ? 0.05 : (val / total).clamp(0.05, 1.0);
    return Row(
      children: [
        SizedBox(
          width: 28,
          child: Text(
            label,
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: Container(
            height: 4,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: factor,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          "$val",
          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }

  Widget _buildToolsGrid(ThemeData theme, bool isDark) {
    final List<Map<String, dynamic>> items = [
      {
        "title": "ID Scan",
        "icon": Icons.qr_code_scanner_rounded,
        "color": theme.colorScheme.primary,
        "page": ScannerPage(onScan: _handleScan),
      },
      {
        "title": "Manual",
        "icon": Icons.keyboard_alt_rounded,
        "color": Colors.amberAccent,
        "page": const ManualEnterPage(),
      },
      {
        "title": "Export",
        "icon": Icons.ios_share_rounded,
        "color": Colors.orange,
        "page": const ExportDataPage(),
      },
      {
        "title": "Today",
        "icon": Icons.today_rounded,
        "color": Colors.teal,
        "page": const TodaysAttendancePage(),
      },
      {
        "title": "Report",
        "icon": Icons.report_gmailerrorred_rounded,
        "color": Colors.redAccent,
        "page": ReportStudentPage(
          isSuperAdmin: false,
          adminDepartment: widget.admin?.department,
        ),
      },
      {
        "title": "Manage Students",
        "icon": Icons.group_add_rounded,
        "color": Colors.pink,
        "page": AddRemoveStudentsPage(
          isSuperAdmin: false,
          initialDepartment: widget.admin?.department,
        ),
      },
      {
        "title": "Leaderboard",
        "icon": Icons.leaderboard_rounded,
        "color": Colors.deepPurpleAccent,
        "page": const LateComersLeaderboardPage(),
      },
      {
        "title": "Actions Log",
        "icon": Icons.inventory_2_rounded,
        "color": Colors.indigoAccent,
        "page": ShowReportsPage(
          isFaculty: widget.admin?.isFaculty ?? false,
          department: widget.admin?.department ?? "",
          isSuperAdmin: false,
        ),
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.15,
      ),
      itemBuilder: (context, index) => _animate(
        delay: 0.4 + (index * 0.05),
        child: _buildMenuCard(
          theme,
          isDark,
          title: items[index]["title"],
          icon: items[index]["icon"],
          color: items[index]["color"],
          onTap: () => _navigateTo(items[index]["page"]),
        ),
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
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String text, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(left: 28, top: 32, bottom: 12),
      child: Text(
        text,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.primary,
          letterSpacing: 2.5,
          fontWeight: FontWeight.w900,
          fontSize: 9,
        ),
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
              top: -150 + (40 * val),
              right: -100 - (20 * val),
              child: _BlurredCircle(
                color: theme.colorScheme.primary.withOpacity(
                  isDark ? 0.1 : 0.05,
                ),
                size: 450,
              ),
            ),
            Positioned(
              bottom: 50 - (50 * val),
              left: -150 + (40 * val),
              child: _BlurredCircle(
                color: Colors.purple.withOpacity(isDark ? 0.08 : 0.04),
                size: 400,
              ),
            ),
          ],
        );
      },
    );
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
        boxShadow: [BoxShadow(color: color, blurRadius: 140, spreadRadius: 70)],
      ),
    );
  }
}
