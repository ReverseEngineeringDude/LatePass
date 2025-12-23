// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously, deprecated_member_use

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:latepass/admin/admin_page.dart';
import 'package:latepass/superadmin/admin_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends StatefulWidget {
  // We keep this for backward compatibility, but we will query Firestore directly for fresh data
  final List<Admin> admins;

  const LoginPage({super.key, required this.admins});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _obscureText = true;
  bool _isLoading = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  final List<String> _superAdminEmails = ['praveenmtdarker@gmail.com'];

  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color accentPurple = Color(0xFF7C3AED);
  static const Color backgroundGrey = Color(0xFFF8FAFC);

  void _showAuthError(dynamic e, String defaultPrefix) {
    String message = '$defaultPrefix failed';
    final errorStr = e.toString().toLowerCase();

    if (errorStr.contains('socketexception') ||
        errorStr.contains('network') ||
        errorStr.contains('unavailable') ||
        errorStr.contains('failed host lookup')) {
      message =
          "No internet connection. Please check your network and try again.";
    } else if (e is FirebaseAuthException) {
      message = e.message ?? "Authentication failed";
    } else {
      message = "$defaultPrefix error occurred.";
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
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
            content: Text('Access Denied: $signedInEmail is not a SuperAdmin'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
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
      _showAuthError(e, 'Anonymous Login');
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

      // 1. FRESH AUTHORIZATION CHECK (Query Firestore directly instead of using widget.admins)
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

        // Verify password match in Firestore as requested
        if (currentAdmin.password != password) {
          throw 'Access Denied: Incorrect password for this admin account.';
        }
      }

      // 2. Firebase Authentication (Secure sign-in)
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundGrey,
      body: Stack(
        children: [
          _buildBackgroundDecor(),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 40),
                          const Icon(
                            Icons.lock_person_rounded,
                            size: 80,
                            color: primaryBlue,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "LatePass Portal",
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                  letterSpacing: -0.5,
                                ),
                          ),
                          const SizedBox(height: 48),
                          _buildLoginCard(),
                          const SizedBox(height: 32),
                          _buildDivider(),
                          const SizedBox(height: 32),
                          _buildGoogleButton(),
                          const SizedBox(height: 16),
                          _buildGuestButton(),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundDecor() {
    return Stack(
      children: [
        Positioned(
          top: -100,
          right: -100,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: primaryBlue.withOpacity(0.1),
            ),
          ),
        ),
        Positioned(
          bottom: -50,
          left: -50,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accentPurple.withOpacity(0.1),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildTextField(
            controller: emailController,
            label: "Admin Email",
            icon: Icons.alternate_email_rounded,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: passwordController,
            label: "Admin Password",
            icon: Icons.lock_outline_rounded,
            isPassword: true,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _signInWithEmailAndPassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Sign in as Admin',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoogleButton() {
    return OutlinedButton.icon(
      onPressed: _isLoading ? null : _signInWithGoogle,
      icon: Image.network(
        'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1200px-Google_%22G%22_logo.svg.png',
        height: 20,
        errorBuilder: (context, error, stackTrace) => const Icon(
          Icons.account_circle_rounded,
          size: 20,
          color: Colors.grey,
        ),
      ),
      label: const Text('SuperAdmin Google Access'),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        side: BorderSide(color: Colors.grey.shade300),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildGuestButton() {
    return TextButton(
      onPressed: _isLoading ? null : _signInAnonymously,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      child: RichText(
        textAlign: TextAlign.center,
        text: const TextSpan(
          style: TextStyle(color: Colors.black54, fontSize: 15),
          children: [
            TextSpan(text: "Are you a student? "),
            TextSpan(
              text: "Continue as Guest",
              style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.grey.shade300)),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            "OR CONNECT WITH",
            style: TextStyle(
              color: Colors.grey,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Expanded(child: Divider(color: Colors.grey.shade300)),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: isPassword ? _obscureText : false,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Colors.grey.shade400, size: 20),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      _obscureText
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      color: Colors.grey.shade400,
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => _obscureText = !_obscureText),
                  )
                : null,
            hintText: isPassword ? "••••••••" : "Enter your email",
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: primaryBlue, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
