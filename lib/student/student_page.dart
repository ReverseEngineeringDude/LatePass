// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:latepass/shared/app_drawer.dart';
import 'package:latepass/student/view_attendance_page.dart';

class StudentPage extends StatefulWidget {
  const StudentPage({super.key});

  @override
  State<StudentPage> createState() => _StudentPageState();
}

class _StudentPageState extends State<StudentPage>
    with TickerProviderStateMixin {
  final TextEditingController _idController = TextEditingController();
  String? _activeStudentId;
  bool _isInitialLoading = true;

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
      duration: const Duration(seconds: 30),
    )..repeat(reverse: true);

    _entryController.forward();
    _loadPersistedSession();
  }

  @override
  void dispose() {
    _idController.dispose();
    _entryController.dispose();
    _backgroundController.dispose();
    super.dispose();
  }

  /// RULE 3 & PERSISTENCE: Load the saved Student ID from Firestore on startup
  Future<void> _loadPersistedSession() async {
    try {
      // Ensure user is authenticated before any Firestore operation
      UserCredential userCredential = await FirebaseAuth.instance
          .signInAnonymously();
      final User? user = userCredential.user;

      if (user != null) {
        // App ID logic as per environment rules
        const String appId = 'latepass-app';

        // RULE 1: Use private path for user settings
        final doc = await FirebaseFirestore.instance
            .collection('artifacts')
            .doc(appId)
            .collection('users')
            .doc(user.uid)
            .collection('preferences')
            .doc('session')
            .get();

        if (doc.exists && mounted) {
          setState(() {
            _activeStudentId = doc.data()?['studentId'];
          });
        }
      }
    } catch (e) {
      debugPrint("Session Restore Error: $e");
    } finally {
      if (mounted) {
        setState(() => _isInitialLoading = false);
      }
    }
  }

  /// PERSISTENCE: Save the ID to Firestore when the user syncs
  Future<void> _syncDashboard() async {
    final id = _idController.text.trim();
    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your Admission ID'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        const String appId = 'latepass-app';

        await FirebaseFirestore.instance
            .collection('artifacts')
            .doc(appId)
            .collection('users')
            .doc(user.uid)
            .collection('preferences')
            .doc('session')
            .set({'studentId': id, 'lastActive': FieldValue.serverTimestamp()});
      }

      if (mounted) {
        setState(() => _activeStudentId = id);
        FocusScope.of(context).unfocus();
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to save session')));
    }
  }

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

    if (_isInitialLoading) {
      return Scaffold(
        backgroundColor: isDark
            ? const Color(0xFF0B0E14)
            : const Color(0xFFF1F5F9),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0B0E14)
          : const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "Student Portal",
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : theme.colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              Icons.notifications_none_rounded,
              color: isDark ? Colors.white70 : theme.colorScheme.primary,
            ),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: const AppDrawer(),
      body: Stack(
        children: [
          _buildAnimatedBackground(theme, isDark),
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _animate(delay: 0.1, child: _buildHeader(theme, isDark)),
                if (_activeStudentId == null)
                  _animate(delay: 0.2, child: _buildIdEntryGate(theme, isDark)),
                if (_activeStudentId != null) ...[
                  _animate(
                    delay: 0.2,
                    child: _buildSectionLabel(
                      theme,
                      isDark,
                      "ACADEMIC OVERVIEW",
                    ),
                  ),
                  _animate(
                    delay: 0.25,
                    child: _buildStatsSummary(theme, isDark),
                  ),
                  _animate(
                    delay: 0.3,
                    child: _buildSectionLabel(theme, isDark, "ACTIVE TOOLS"),
                  ),
                  _animate(
                    delay: 0.35,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildActionCard(
                        context,
                        title: "Attendance History",
                        subtitle:
                            "Track your logs, verify markings, and check status.",
                        icon: Icons.history_rounded,
                        color: Colors.blueAccent,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ViewAttendancePage(),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  _animate(
                    delay: 0.38,
                    child: Center(
                      child: TextButton(
                        onPressed: () async {
                          // Clear session logic
                          setState(() => _activeStudentId = null);
                          final User? user = FirebaseAuth.instance.currentUser;
                          if (user != null) {
                            await FirebaseFirestore.instance
                                .collection('artifacts')
                                .doc('latepass-app')
                                .collection('users')
                                .doc(user.uid)
                                .collection('preferences')
                                .doc('session')
                                .delete();
                          }
                        },
                        child: Text(
                          "Switch Account",
                          style: TextStyle(
                            color: theme.colorScheme.primary.withOpacity(0.6),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                _animate(delay: 0.4, child: _buildQuickTipCard(theme, isDark)),
                const SizedBox(height: 40),
              ],
            ),
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
              top: -150 + (50 * val),
              right: -100 - (20 * val),
              child: _BlurredCircle(
                color: theme.colorScheme.primary.withOpacity(
                  isDark ? 0.12 : 0.06,
                ),
                size: 450,
              ),
            ),
            Positioned(
              bottom: 50 - (60 * val),
              left: -150 + (50 * val),
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

  Widget _buildIdEntryGate(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: _GlassCard(
        isDark: isDark,
        borderRadius: 32,
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              Text(
                "Verify Identity",
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Enter your Student ID to unlock your personalized dashboard.",
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _idController,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  hintText: "Admission Number",
                  hintStyle: TextStyle(
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                  prefixIcon: const Icon(Icons.badge_outlined),
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.black.withOpacity(0.03),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: _syncDashboard,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text(
                    "Unlock Dashboard",
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, bool isDark) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: _GlassCard(
        isDark: isDark,
        borderRadius: 32,
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.greenAccent.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(
                      Icons.verified_user_rounded,
                      size: 14,
                      color: Colors.greenAccent,
                    ),
                    SizedBox(width: 6),
                    Text(
                      "SECURE ACCESS",
                      style: TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                "Welcome back,",
                style: theme.textTheme.titleMedium?.copyWith(
                  color: isDark ? Colors.white54 : theme.disabledColor,
                  fontWeight: FontWeight.w400,
                ),
              ),
              if (_activeStudentId == null)
                Text(
                  "Student Portal",
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black,
                    letterSpacing: -0.8,
                  ),
                ),
              if (_activeStudentId != null)
                FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('students')
                      .doc(_activeStudentId)
                      .get(),
                  builder: (context, snapshot) {
                    final name = (snapshot.hasData && snapshot.data!.exists)
                        ? snapshot.data!['name']
                        : "Student";
                    return Text(
                      name,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : Colors.black,
                        letterSpacing: -0.8,
                      ),
                    );
                  },
                ),
              const SizedBox(height: 8),
              Text(
                "Personalized attendance dashboard.",
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark ? Colors.white38 : theme.disabledColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(ThemeData theme, bool isDark, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Text(
        text,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.primary,
          letterSpacing: 2.0,
          fontWeight: FontWeight.w900,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildStatsSummary(ThemeData theme, bool isDark) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('attendance').snapshots(),
      builder: (context, snapshot) {
        int totalLogs = 0;
        String attendanceRate = "0%";

        if (snapshot.hasData) {
          final docs = snapshot.data!.docs.where(
            (doc) => doc['studentId'] == _activeStudentId,
          );
          totalLogs = docs.length;

          const int estimatedTotalSessions = 45;
          double rate = (totalLogs / estimatedTotalSessions) * 100;
          attendanceRate = "${rate.clamp(0, 100).toInt()}%";
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: _buildStatChip(
                  theme,
                  isDark,
                  label: "Overall Rate",
                  value: attendanceRate,
                  icon: Icons.trending_up_rounded,
                  color: Colors.blueAccent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatChip(
                  theme,
                  isDark,
                  label: "Total Logs",
                  value: totalLogs.toString(),
                  icon: Icons.event_note_rounded,
                  color: Colors.purpleAccent,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatChip(
    ThemeData theme,
    bool isDark, {
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return _GlassCard(
      isDark: isDark,
      borderRadius: 24,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 12),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
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
        ),
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return _GlassCard(
      isDark: isDark,
      borderRadius: 32,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(32),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
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
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? Colors.white38 : theme.disabledColor,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: isDark
                    ? Colors.white10
                    : theme.disabledColor.withOpacity(0.3),
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickTipCard(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary.withOpacity(0.85),
              theme.colorScheme.primary,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.tips_and_updates_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    "Quick Tip",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: -0.3,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    "Keep your ID ready for scanning at the registry point.",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
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

class _GlassCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final bool isDark;

  const _GlassCard({
    required this.child,
    required this.borderRadius,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.04)
                : Colors.white.withOpacity(0.5),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.white.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: child,
        ),
      ),
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
