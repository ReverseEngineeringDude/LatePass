// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'dart:convert';
import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:latepass/superadmin/admin_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:latepass/shared/theme_notifier.dart';
import 'package:provider/provider.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});
  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> with TickerProviderStateMixin {
  User? _user;
  Admin? _admin;
  String _userRole = 'Student';
  String _userDepartment = '';
  String _userName = 'Guest User';
  bool _isLoading = true;

  late AnimationController _listController;
  late AnimationController _headerController;

  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color accentPurple = Color(0xFF7C3AED);

  @override
  void initState() {
    super.initState();
    _fetchUserData();

    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _listController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _headerController.forward();
    _listController.forward();
  }

  @override
  void dispose() {
    _headerController.dispose();
    _listController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserData() async {
    _user = FirebaseAuth.instance.currentUser;
    final prefs = await SharedPreferences.getInstance();

    try {
      final userRole = prefs.getString('user_role');
      switch (userRole) {
        case 'superadmin':
          _userRole = 'Superadmin';
          _userName = _user?.email ?? 'Superadmin';
          break;
        case 'admin':
          final adminData = prefs.getString('admin_data');
          if (adminData != null) {
            _admin = Admin.fromJson(jsonDecode(adminData));
            _userRole = _admin!.isFaculty ? 'Faculty Admin' : 'Admin';
            _userDepartment = _admin!.department;
            _userName = _admin!.name;
          }
          break;
        case 'student':
        default:
          _userRole = 'Student';
          _userName = 'Student';
          break;
      }
    } catch (e) {
      debugPrint("Error fetching user data: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await FirebaseAuth.instance.signOut();
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Drawer(
      backgroundColor: isDark ? const Color(0xFF0F1115) : Colors.white,
      elevation: 0,
      width: MediaQuery.of(context).size.width * 0.85,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
      ),
      child: Column(
        children: [
          _buildAnimatedHeader(theme, isDark),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.02)
                    : Colors.grey.shade50,
              ),
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 20,
                ),
                children: [
                  _buildAnimatedItem(
                    index: 0,
                    child: _buildDrawerItem(
                      icon: Icons.dashboard_rounded,
                      label: 'Dashboard',
                      onTap: () => Navigator.pop(context),
                      isActive: true,
                    ),
                  ),
                  _buildAnimatedItem(
                    index: 1,
                    child: Consumer<ThemeNotifier>(
                      builder: (context, themeNotifier, child) {
                        return _buildDrawerItem(
                          icon: themeNotifier.themeMode == ThemeMode.dark
                              ? Icons.light_mode_rounded
                              : Icons.dark_mode_rounded,
                          label: 'Appearance',
                          onTap: () => themeNotifier.toggleTheme(),
                        );
                      },
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20, horizontal: 10),
                    child: Divider(
                      thickness: 1,
                      color: Color.fromRGBO(0, 0, 0, 0.1),
                    ),
                  ),
                  _buildAnimatedItem(
                    index: 2,
                    child: _buildDrawerItem(
                      icon: Icons.logout_rounded,
                      label: 'Logout',
                      color: Colors.redAccent,
                      onTap: () => _showLogoutDialog(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildFooter(isDark),
        ],
      ),
    );
  }

  Widget _buildAnimatedHeader(ThemeData theme, bool isDark) {
    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, -0.2), end: Offset.zero)
          .animate(
            CurvedAnimation(
              parent: _headerController,
              curve: Curves.easeOutCubic,
            ),
          ),
      child: FadeTransition(
        opacity: _headerController,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(30, 70, 30, 40),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [primaryBlue, accentPurple],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.only(bottomRight: Radius.circular(50)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProfileAvatar(isDark),
              const SizedBox(height: 25),
              _isLoading ? _buildHeaderLoader() : _buildUserInfo(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileAvatar(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: CircleAvatar(
        radius: 38,
        backgroundColor: Colors.white.withOpacity(0.15),
        child: const Icon(Icons.person_rounded, color: Colors.white, size: 40),
      ),
    );
  }

  Widget _buildUserInfo(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _userName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Text(
                _userRole.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            if (_userDepartment.isNotEmpty) ...[
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "• $_userDepartment",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildHeaderLoader() {
    return const SizedBox(
      height: 40,
      width: 40,
      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
    );
  }

  Widget _buildAnimatedItem({required int index, required Widget child}) {
    final start = (index * 0.1).clamp(0.0, 1.0);
    final end = (start + 0.6).clamp(0.0, 1.0);

    return AnimatedBuilder(
      animation: _listController,
      builder: (context, child) {
        final curve = CurvedAnimation(
          parent: _listController,
          curve: Interval(start, end, curve: Curves.easeOutQuart),
        );
        return Opacity(
          opacity: curve.value,
          child: Transform.translate(
            offset: Offset(-30 * (1 - curve.value), 0),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
    bool isActive = false,
  }) {
    final theme = Theme.of(context);
    final baseColor =
        color ?? (isActive ? primaryBlue : theme.colorScheme.onSurface);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: isActive ? primaryBlue.withOpacity(0.1) : Colors.transparent,
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        leading: Icon(icon, color: baseColor, size: 26),
        title: Text(
          label,
          style: TextStyle(
            color: baseColor,
            fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
            fontSize: 16,
          ),
        ),
        trailing: isActive
            ? const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: primaryBlue,
              )
            : null,
      ),
    );
  }

  Widget _buildFooter(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(30),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              size: 18,
              color: primaryBlue,
            ),
          ),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'LatePass System',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Text(
                'Version 1.0.0 Stable',
                style: TextStyle(
                  color: isDark ? Colors.white38 : Colors.grey.shade500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: AlertDialog(
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF1A1C21)
                : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            title: const Row(
              children: [
                Icon(Icons.logout_rounded, color: Colors.redAccent),
                SizedBox(width: 12),
                Text(
                  'Confirm Logout',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
            content: const Text(
              'Are you sure you want to end your current administrative session?',
              style: TextStyle(height: 1.5),
            ),
            actionsPadding: const EdgeInsets.all(20),
            actions: [
              TextButton(
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 0,
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  _logout(context);
                },
                child: const Text(
                  'Logout',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
