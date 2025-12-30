// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'dart:convert';
import 'dart:ui' as ui;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:latepass/shared/biometric_auth_service.dart';
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
  late AnimationController _backgroundController;

  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color accentPurple = Color(0xFF7C3AED);

  final BiometricAuthService _biometricAuthService = BiometricAuthService();

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

    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat(reverse: true);

    _headerController.forward();
    _listController.forward();
  }

  @override
  void dispose() {
    _headerController.dispose();
    _listController.dispose();
    _backgroundController.dispose();
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
      backgroundColor: Colors.transparent, // Required for glassmorphism
      elevation: 0,
      width: MediaQuery.of(context).size.width * 0.85,
      child: Stack(
        children: [
          // Background Glass effect
          _buildGlassBackdrop(isDark),

          // Animated Blobs behind the drawer content
          _buildAnimatedBlobs(isDark),

          Column(
            children: [
              _buildAnimatedHeader(theme, isDark),
              Expanded(
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
                        isDark: isDark,
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
                            isDark: isDark,
                            onTap: () => themeNotifier.toggleTheme(),
                          );
                        },
                      ),
                    ),
                    _buildAnimatedItem(
                      index: 2,
                      child: Consumer<ThemeNotifier>(
                        builder: (context, themeNotifier, child) {
                          return _buildSwitchDrawerItem(
                            icon: Icons.fingerprint,
                            label: 'Biometric Lock',
                            value: themeNotifier.isBiometricAuthEnabled,
                            isDark: isDark,
                            onChanged: (value) async {
                              final isAuthenticated =
                                  await _biometricAuthService.authenticate();
                              if (isAuthenticated) {
                                themeNotifier.toggleBiometricAuth();
                              }
                            },
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 20,
                        horizontal: 10,
                      ),
                      child: Divider(
                        thickness: 1,
                        color: isDark
                            ? Colors.white10
                            : Colors.black.withOpacity(0.05),
                      ),
                    ),
                    _buildAnimatedItem(
                      index: 3,
                      child: _buildDrawerItem(
                        icon: Icons.logout_rounded,
                        label: 'Logout',
                        color: Colors.redAccent,
                        isDark: isDark,
                        onTap: () => _showLogoutDialog(context),
                      ),
                    ),
                  ],
                ),
              ),
              _buildFooter(isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGlassBackdrop(bool isDark) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topRight: Radius.circular(40),
        bottomRight: Radius.circular(40),
      ),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF0F1115).withOpacity(0.8)
                : Colors.white.withOpacity(0.85),
            border: Border(
              right: BorderSide(
                color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedBlobs(bool isDark) {
    return AnimatedBuilder(
      animation: _backgroundController,
      builder: (context, child) {
        final val = _backgroundController.value;
        return Stack(
          children: [
            Positioned(
              top: 100 + (50 * val),
              right: -50,
              child: _Blob(color: primaryBlue.withOpacity(0.1), size: 200),
            ),
            Positioned(
              bottom: 100 - (50 * val),
              left: -30,
              child: _Blob(color: accentPurple.withOpacity(0.08), size: 180),
            ),
          ],
        );
      },
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
    return AnimatedBuilder(
      animation: _listController,
      builder: (context, child) {
        final curve = CurvedAnimation(
          parent: _listController,
          curve: Interval(
            start,
            (start + 0.6).clamp(0.0, 1.0),
            curve: Curves.easeOutQuart,
          ),
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
    required bool isDark,
  }) {
    final theme = Theme.of(context);
    final baseColor =
        color ??
        (isActive
            ? primaryBlue
            : (isDark ? Colors.white70 : theme.colorScheme.onSurface));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isActive
            ? primaryBlue.withOpacity(isDark ? 0.15 : 0.1)
            : (isDark
                  ? Colors.white.withOpacity(0.03)
                  : Colors.black.withOpacity(0.02)),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive ? primaryBlue.withOpacity(0.2) : Colors.transparent,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        leading: Icon(icon, color: baseColor, size: 24),
        title: Text(
          label,
          style: TextStyle(
            color: baseColor,
            fontWeight: isActive ? FontWeight.w900 : FontWeight.w600,
            fontSize: 15,
          ),
        ),
        trailing: isActive
            ? const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 12,
                color: primaryBlue,
              )
            : null,
      ),
    );
  }

  Widget _buildSwitchDrawerItem({
    required IconData icon,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
    Color? color,
    required bool isDark,
  }) {
    final theme = Theme.of(context);
    final baseColor =
        color ?? (isDark ? Colors.white70 : theme.colorScheme.onSurface);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.03)
            : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(20),
      ),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        secondary: Icon(icon, color: baseColor, size: 24),
        title: Text(
          label,
          style: TextStyle(
            color: baseColor,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        value: value,
        onChanged: onChanged,
        activeColor: primaryBlue,
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
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              Text(
                'Version 1.0.0 Stable',
                style: TextStyle(
                  color: isDark ? Colors.white24 : Colors.grey.shade500,
                  fontSize: 11,
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
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AlertDialog(
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF1A1C21).withOpacity(0.9)
                : Colors.white.withOpacity(0.9),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
              side: BorderSide(color: Colors.white10),
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

class _Blob extends StatelessWidget {
  final Color color;
  final double size;
  const _Blob({required this.color, required this.size});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color, blurRadius: 40, spreadRadius: 20)],
      ),
    );
  }
}
