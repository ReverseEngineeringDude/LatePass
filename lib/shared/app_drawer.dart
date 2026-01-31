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
  late AnimationController _speechBubbleController;

  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color accentPurple = Color(0xFF7C3AED);

  final BiometricAuthService _biometricAuthService = BiometricAuthService();

  @override
  void initState() {
    super.initState();
    _fetchUserData();

    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _listController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 25),
    )..repeat(reverse: true);
    
    _speechBubbleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _headerController.forward();
    _listController.forward();
    
    // Delay speech bubble slightly so it pops up after user sees avatar
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) _speechBubbleController.forward();
    });
  }

  @override
  void dispose() {
    _headerController.dispose();
    _listController.dispose();
    _backgroundController.dispose();
    _speechBubbleController.dispose();
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
      backgroundColor: Colors.transparent,
      elevation: 0,
      width: MediaQuery.of(context).size.width * 0.85,
      child: Stack(
        children: [
          _buildGlassBackdrop(isDark),
          _buildAnimatedBlobs(),
          Column(
            children: [
              _buildAnimatedCenteredHeader(theme, isDark),
              const SizedBox(height: 10),
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
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
                            icon: Icons.fingerprint_rounded,
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
                  ],
                ),
              ),
              _buildBottomActionZone(isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGlassBackdrop(bool isDark) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topRight: Radius.circular(45),
        bottomRight: Radius.circular(45),
      ),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF0F1115).withOpacity(0.88)
                : Colors.white.withOpacity(0.92),
            border: Border(
              right: BorderSide(
                color: isDark
                    ? Colors.white.withOpacity(0.08)
                    : Colors.black.withOpacity(0.05),
                width: 1.5,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedBlobs() {
    return AnimatedBuilder(
      animation: _backgroundController,
      builder: (context, child) {
        final val = _backgroundController.value;
        return Stack(
          children: [
            Positioned(
              top: 50 + (120 * val),
              right: -70,
              child: _Blob(color: primaryBlue.withOpacity(0.08), size: 280),
            ),
            Positioned(
              bottom: 150 - (100 * val),
              left: -40,
              child: _Blob(color: accentPurple.withOpacity(0.06), size: 240),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAnimatedCenteredHeader(ThemeData theme, bool isDark) {
    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, -0.15), end: Offset.zero)
          .animate(
            CurvedAnimation(
              parent: _headerController,
              curve: Curves.easeOutQuart,
            ),
          ),
      child: FadeTransition(
        opacity: _headerController,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 65, 20, 35),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [primaryBlue, accentPurple],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              bottomRight: Radius.circular(55),
            ),
            boxShadow: [
              BoxShadow(
                color: primaryBlue.withOpacity(0.2),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildCenteredProfileAvatar(),
              const SizedBox(height: 20),
              _isLoading
                  ? const SizedBox(
                      height: 50,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                    )
                  : _buildCenteredUserInfo(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCenteredProfileAvatar() {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        // Outer Glow/Border
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
            boxShadow: [
               BoxShadow(
                color: Colors.white.withOpacity(0.1),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
        ),
        
        // 3D Avatar Image
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.1),
            border: Border.all(color: Colors.white.withOpacity(0.4), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/avatar_3d.jpg',
              fit: BoxFit.cover,
            ),
          ),
        ),

        // Animated Speech Bubble "Hi"
        Positioned(
          top: -15,
          right: -25,
          child: ScaleTransition(
            scale: CurvedAnimation(
              parent: _speechBubbleController,
              curve: Curves.elasticOut,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(15),
                  topRight: Radius.circular(15),
                  bottomRight: Radius.circular(15),
                  bottomLeft: Radius.circular(4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(2, 4),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Hi! 👋",
                    style: TextStyle(
                      color: Color(0xFF2563EB), // Primary Blue
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCenteredUserInfo() {
    return Column(
      children: [
        Text(
          _userName,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Text(
            _userRole.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ),
        if (_userDepartment.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            _userDepartment,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  Widget _buildAnimatedItem({required int index, required Widget child}) {
    final start = (index * 0.08).clamp(0.0, 1.0);
    return AnimatedBuilder(
      animation: _listController,
      builder: (context, child) {
        final curve = CurvedAnimation(
          parent: _listController,
          curve: Interval(
            start,
            (start + 0.5).clamp(0.0, 1.0),
            curve: Curves.easeOutBack,
          ),
        );
        return Opacity(
          // Clamp the value to [0.0, 1.0] to prevent the overshoot crash caused by Curves.easeOutBack
          opacity: curve.value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(-50 * (1 - curve.value), 0),
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
    bool isActive = false,
    required bool isDark,
  }) {
    final baseColor = isActive
        ? primaryBlue
        : (isDark
              ? Colors.white.withOpacity(0.8)
              : Colors.black.withOpacity(0.7));

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isActive
            ? primaryBlue.withOpacity(isDark ? 0.15 : 0.1)
            : (isDark
                  ? Colors.white.withOpacity(0.03)
                  : Colors.black.withOpacity(0.03)),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isActive
              ? primaryBlue.withOpacity(0.3)
              : (isDark ? Colors.white.withOpacity(0.06) : Colors.transparent),
        ),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
        leading: Icon(icon, color: baseColor, size: 24),
        title: Text(
          label,
          style: TextStyle(
            color: baseColor,
            fontWeight: isActive ? FontWeight.w900 : FontWeight.w700,
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
    required bool isDark,
  }) {
    final baseColor = isDark
        ? Colors.white.withOpacity(0.8)
        : Colors.black.withOpacity(0.7);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.03)
            : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.06) : Colors.transparent,
        ),
      ),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
        secondary: Icon(icon, color: baseColor, size: 24),
        title: Text(
          label,
          style: TextStyle(
            color: baseColor,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
        value: value,
        onChanged: onChanged,
        activeColor: primaryBlue,
      ),
    );
  }

  Widget _buildBottomActionZone(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 35),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.02)
            : Colors.black.withOpacity(0.02),
        borderRadius: const BorderRadius.only(topRight: Radius.circular(35)),
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.05),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.shield_rounded,
                size: 16,
                color: primaryBlue.withOpacity(0.6),
              ),
              const SizedBox(width: 8),
              Text(
                'LatePass Portal v1.0.0',
                style: TextStyle(
                  color: isDark ? Colors.white24 : Colors.black26,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildLogoutButton(isDark),
        ],
      ),
    );
  }

  Widget _buildLogoutButton(bool isDark) {
    return Container(
      width: double.infinity,
      height: 58,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [
            Colors.redAccent.withOpacity(0.8),
            Colors.red.withOpacity(0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: () => _showLogoutDialog(context),
        icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 22),
        label: const Text(
          'Log Out',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 16,
            letterSpacing: 0.5,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: AlertDialog(
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF1A1C21).withOpacity(0.85)
                : Colors.white.withOpacity(0.95),
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
              'Are you sure you want to end your current session?',
              style: TextStyle(height: 1.5, fontWeight: FontWeight.w500),
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
        boxShadow: [BoxShadow(color: color, blurRadius: 50, spreadRadius: 30)],
      ),
    );
  }
}
