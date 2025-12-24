// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:latepass/admin/admin_page.dart';
import 'package:latepass/firebase_options.dart';
import 'package:latepass/login/login_page.dart';
import 'package:latepass/student/student_page.dart';
import 'package:latepass/superadmin/admin_model.dart';
import 'package:latepass/superadmin/superadmin_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:latepass/shared/theme_notifier.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with platform-specific options
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeNotifier(ThemeMode.light),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // Custom App Colors (Matching the Portal Design)
  static const Color primaryBlue = Color(0xFF2563EB);

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeNotifier>(
      builder: (context, themeNotifier, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'LatePass Portal',

          // Modern Material 3 Theme Configuration
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: primaryBlue,
              primary: primaryBlue,
              brightness: Brightness.light,
            ),
            scaffoldBackgroundColor: const Color(0xFFF8FAFC),
            appBarTheme: const AppBarTheme(
              centerTitle: true,
              elevation: 0,
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: primaryBlue,
              primary: primaryBlue,
              brightness: Brightness.dark,
            ),
            scaffoldBackgroundColor: const Color(0xFF0F172A),
            appBarTheme: const AppBarTheme(
              centerTitle: true,
              elevation: 0,
              backgroundColor: Color(0xFF1E293B),
              foregroundColor: Colors.white,
            ),
          ),
          themeMode: themeNotifier.themeMode,

          home: const AuthWrapper(),
          routes: {
            '/login': (context) => const LoginPage(admins: []),
            '/admin': (context) => const AdminPage(),
            '/student': (context) => const StudentPage(),
            '/superadmin': (context) =>
                SuperAdminPage(admins: const [], onAddAdmin: (_) {}),
          },
        );
      },
    );
  }
}


class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  _AuthWrapperState createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  List<Admin> admins = [];

  @override
  void initState() {
    super.initState();
  }

  /// Determines the initial screen based on authentication state and role
  Future<Widget> _getInitialPage() async {
    try {
      // 1. Load Admins first for authorization checks
      final adminsSnapshot = await FirebaseFirestore.instance
          .collection('admins')
          .get();

      admins = adminsSnapshot.docs
          .map((doc) => Admin.fromFirestore(doc))
          .toList();

      // 2. Check saved user role from persistent storage
      final prefs = await SharedPreferences.getInstance();
      final userRole = prefs.getString('user_role');

      if (userRole == null) {
        return LoginPage(admins: admins);
      }

      // 3. Routing based on role
      switch (userRole) {
        case 'superadmin':
          return SuperAdminPage(
            admins: admins,
            onAddAdmin: (admin) => setState(() => admins.add(admin)),
          );
        case 'admin':
          final adminData = prefs.getString('admin_data');
          if (adminData != null) {
            final admin = Admin.fromJson(jsonDecode(adminData));
            return AdminPage(admin: admin);
          }
          return LoginPage(admins: admins);
        case 'student':
          return const StudentPage();
        default:
          return LoginPage(admins: admins);
      }
    } catch (e) {
      debugPrint("Error in AuthWrapper: $e");
      return LoginPage(admins: admins);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _getInitialPage(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: MyApp.primaryBlue),
            ),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        }
        return snapshot.data ?? LoginPage(admins: admins);
      },
    );
  }
}
