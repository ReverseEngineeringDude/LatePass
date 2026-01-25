// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously, deprecated_member_use

import 'dart:convert';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:latepass/admin/admin_page.dart';
import 'package:latepass/superadmin/admin_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends StatefulWidget {
  final List<Admin> admins;

  const LoginPage({super.key, required this.admins});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _obscureText = true;
  bool _isLoading = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  late AnimationController _entryController;
  late AnimationController _backgroundController;

  final List<String> _superAdminEmails = ['praveenmtdarker@gmail.com'];

  @override
  void initState() {
    super.initState();
    // Animation for sequential entrance
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Animation for floating background effect
    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);

    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    _backgroundController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // --- Auth Logic (Unchanged) ---

  void _showAuthError(dynamic e, String defaultPrefix) {
    String message = '$defaultPrefix failed';
    final errorStr = e.toString().toLowerCase();

    if (errorStr.contains('socketexception') ||
        errorStr.contains('network') ||
        errorStr.contains('unavailable') ||
        errorStr.contains('failed host lookup')) {
      message = "Connection issue. Please check your internet and try again.";
    } else if (e is FirebaseAuthException) {
      message = e.message ?? "Authentication failed";
    } else {
      message = "$defaultPrefix: ${e.toString()}";
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        elevation: 10,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      ),
    );
  }

  bool _checkIsSuperAdmin(String email) {
    final normalizedEmail = email.trim().toLowerCase();
    return _superAdminEmails.any(
          (e) => e.trim().toLowerCase() == normalizedEmail,
        ) ||
        normalizedEmail.contains('superadmin');
  }

  void _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }
      final String signedInEmail = googleUser.email.trim().toLowerCase();
      if (!_checkIsSuperAdmin(signedInEmail)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Access Denied: SuperAdmin only area'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        );
        await _googleSignIn.signOut();
        setState(() => _isLoading = false);
        return;
      }
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await _auth.signInWithCredential(credential);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_role', 'superadmin');
      await prefs.setString('email', signedInEmail);
      Navigator.pushReplacementNamed(context, '/superadmin');
    } catch (e) {
      _showAuthError(e, 'Google Sign-In');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _signInAnonymously() async {
    setState(() => _isLoading = true);
    try {
      await _auth.signInAnonymously();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_role', 'student');
      Navigator.pushReplacementNamed(context, '/student');
    } catch (e) {
      _showAuthError(e, 'Guest Login');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _signInWithEmailAndPassword() async {
    final String email = emailController.text.trim().toLowerCase();
    final String password = passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      bool isSuperAdmin = _checkIsSuperAdmin(email);
      Admin? currentAdmin;
      if (!isSuperAdmin) {
        final adminQuery = await FirebaseFirestore.instance
            .collection('admins')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();
        if (adminQuery.docs.isEmpty) {
          throw 'Authorization Failed: This email is not registered as an admin.';
        }
        final adminData = adminQuery.docs.first;
        currentAdmin = Admin.fromFirestore(adminData);
        if (currentAdmin.password != password) {
          throw 'Access Denied: Incorrect password for this admin account.';
        }
      }
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      final prefs = await SharedPreferences.getInstance();
      if (isSuperAdmin) {
        await prefs.setString('user_role', 'superadmin');
        Navigator.pushReplacementNamed(context, '/superadmin');
      } else if (currentAdmin != null) {
        await prefs.setString('user_role', 'admin');
        await prefs.setString('admin_data', jsonEncode(currentAdmin.toJson()));
        if (currentAdmin.isFaculty) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => AdminPage(admin: currentAdmin!),
            ),
          );
        } else {
          Navigator.pushReplacementNamed(context, '/admin');
        }
      }
    } catch (e) {
      if (e is String) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e),
            backgroundColor: Colors.orangeAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        _showAuthError(e, 'Login');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- Animation Helpers ---

  Widget _animate({
    required Widget child,
    required double delay,
    required double slideOffset,
  }) {
    final start = delay;
    final end = (delay + 0.6).clamp(0.0, 1.0);

    return AnimatedBuilder(
      animation: _entryController,
      builder: (context, child) {
        final curve = CurvedAnimation(
          parent: _entryController,
          curve: Interval(start, end, curve: Curves.easeOutCubic),
        );
        return Opacity(
          opacity: curve.value,
          child: Transform.translate(
            offset: Offset(0, slideOffset * (1 - curve.value)),
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
          ? const Color(0xFF0F1115)
          : const Color(0xFFF8FAFC),
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          _buildFloatingMeshBackground(theme, isDark),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),
                    _animate(
                      delay: 0.0,
                      slideOffset: -30,
                      child: _buildBrandHeader(theme),
                    ),
                    const SizedBox(height: 40),
                    _animate(
                      delay: 0.2,
                      slideOffset: 40,
                      child: _buildGlassCard(theme, isDark),
                    ),
                    const SizedBox(height: 30),
                    _animate(
                      delay: 0.4,
                      slideOffset: 20,
                      child: _buildFooterActions(theme, isDark),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
          if (_isLoading) _buildGlobalLoadingOverlay(theme),
        ],
      ),
    );
  }

  Widget _buildFloatingMeshBackground(ThemeData theme, bool isDark) {
    return AnimatedBuilder(
      animation: _backgroundController,
      builder: (context, child) {
        final val = _backgroundController.value;
        return RepaintBoundary(
          child: Stack(
            children: [
              Positioned(
                top: -150 + (20 * val),
                right: -100 + (30 * val),
                child: _BlurredCircle(
                  color: theme.colorScheme.primary.withOpacity(
                    isDark ? 0.3 : 0.2,
                  ),
                  size: 400,
                ),
              ),
              Positioned(
                bottom: -100 - (40 * val),
                left: -80 + (20 * val),
                child: _BlurredCircle(
                  color: theme.colorScheme.secondary.withOpacity(
                    isDark ? 0.25 : 0.15,
                  ),
                  size: 350,
                ),
              ),
              Positioned(
                top: 200 - (30 * val),
                left: -150 + (40 * val),
                child: _BlurredCircle(
                  color: theme.colorScheme.tertiary.withOpacity(
                    isDark ? 0.15 : 0.1,
                  ),
                  size: 300,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBrandHeader(ThemeData theme) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withOpacity(0.3),
                blurRadius: 25,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Image.asset('assets/logo_no_bg.png', width: 100, height: 100),
        ),
        const SizedBox(height: 28),
        Text(
          "LatePass",
          style: theme.textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -1.5,
            color: theme.colorScheme.onSurface,
            fontSize: 40,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "Institutional Security Gateway",
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.5),
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildGlassCard(ThemeData theme, bool isDark) {
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(40),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.03)
                  : Colors.white.withOpacity(0.7),
              borderRadius: BorderRadius.circular(40),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.08)
                    : Colors.white.withOpacity(0.4),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildModernField(
                  controller: emailController,
                  label: "ADMIN EMAIL",
                  hint: "red@latepass.com",
                  icon: Icons.email_outlined,
                  theme: theme,
                ),
                const SizedBox(height: 24),
                _buildModernField(
                  controller: passwordController,
                  label: "ACCESS KEY",
                  hint: "••••••••",
                  icon: Icons.key_outlined,
                  isPassword: true,
                  theme: theme,
                ),
                const SizedBox(height: 40),
                _buildPrimaryButton(theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPrimaryButton(ThemeData theme) {
    return Container(
      width: double.infinity,
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withBlue(220),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _signInWithEmailAndPassword,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
        child: const Text(
          'Login as Admin',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildFooterActions(ThemeData theme, bool isDark) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Divider(
                color: theme.colorScheme.onSurface.withOpacity(0.1),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                "OR",
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface.withOpacity(0.4),
                ),
              ),
            ),
            Expanded(
              child: Divider(
                color: theme.colorScheme.onSurface.withOpacity(0.1),
              ),
            ),
          ],
        ),
        const SizedBox(height: 30),
        SizedBox(
          width: double.infinity,
          height: 60,
          child: OutlinedButton.icon(
            onPressed: _isLoading ? null : _signInWithGoogle,
            icon: Image.asset('assets/google_logo.webp', height: 24),
            label: const Text(
              'Sign In SuperAdmin with Google',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: theme.colorScheme.onSurface.withOpacity(0.1),
                width: 1.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              foregroundColor: theme.colorScheme.onSurface,
              backgroundColor: isDark
                  ? Colors.white.withOpacity(0.03)
                  : Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: _isLoading ? null : _signInAnonymously,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
                fontSize: 15,
              ),
              children: [
                const TextSpan(text: "Not an administrator? "),
                TextSpan(
                  text: "Enter as Guest",
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModernField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required ThemeData theme,
    bool isPassword = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: theme.colorScheme.primary.withOpacity(0.8),
            ),
          ),
        ),
        TextField(
          controller: controller,
          obscureText: isPassword ? _obscureText : false,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: theme.colorScheme.primary, size: 22),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      _obscureText
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      color: theme.colorScheme.onSurface.withOpacity(0.3),
                    ),
                    onPressed: () =>
                        setState(() => _obscureText = !_obscureText),
                  )
                : null,
            hintText: hint,
            hintStyle: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.2),
            ),
            filled: true,
            fillColor: theme.brightness == Brightness.dark
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.03),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 20,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(
                color: theme.colorScheme.primary,
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGlobalLoadingOverlay(ThemeData theme) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: _entryController, curve: Curves.easeIn),
      child: Container(
        color: Colors.black.withOpacity(0.4),
        child: Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      color: theme.colorScheme.primary,
                      strokeWidth: 4,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "Authenticating...",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
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
        boxShadow: [BoxShadow(color: color, blurRadius: 100, spreadRadius: 60)],
      ),
    );
  }
}
