import 'package:flutter/material.dart';
import 'package:latepass/shared/app_drawer.dart';
import 'package:latepass/student/view_attendance_page.dart';

class StudentPage extends StatelessWidget {
  const StudentPage({super.key});

  // Theme Colors consistent with the rest of the app
  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color accentPurple = Color(0xFF7C3AED);
  static const Color backgroundGrey = Color(0xFFF8FAFC);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundGrey,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text(
          "Student Portal",
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: AppDrawer(),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Header Section
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
                    "Welcome back,",
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                  ),
                  const Text(
                    "Student Dashboard",
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Manage your attendance and track your late passes in one place.",
                    style: TextStyle(color: Colors.black54, height: 1.4),
                  ),
                ],
              ),
            ),

            const Padding(
              padding: EdgeInsets.fromLTRB(24, 32, 24, 16),
              child: Text(
                "Your Tools",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),

            // Feature Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: _buildActionCard(
                context,
                title: "Check Attendance",
                subtitle: "View your historical attendance records and status.",
                icon: Icons.calendar_month_rounded,
                color: primaryBlue,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ViewAttendancePage(),
                    ),
                  );
                },
              ),
            ),

            // Decorative Placeholder for future features
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accentPurple.withOpacity(0.8), accentPurple],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      color: Colors.white,
                      size: 32,
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
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            "Ensure your ID is ready for scanning at the gate.",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(24),
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
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black45,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.black26,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
