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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // Custom App Colors (Matching the Portal Design)
  static const Color primaryBlue = Color(0xFF2563EB);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'LatePass Portal',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryBlue,
          primary: primaryBlue,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.white,
        ),
      ),
      home: const AuthWrapper(),
      routes: {
        '/login': (context) =>
            const LoginPage(admins: []), // Admins will be loaded in AuthWrapper
        '/admin': (context) => const AdminPage(),
        '/student': (context) => const StudentPage(),
        '/superadmin': (context) => SuperAdminPage(
            admins: const [],
            onAddAdmin: (_) {}), // Admins will be loaded in AuthWrapper
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

  Future<Widget> _getInitialPage() async {
    // 1. Load Admins first, as they might be needed on login page or others
    final adminsSnapshot =
        await FirebaseFirestore.instance.collection('admins').get();
    admins =
        adminsSnapshot.docs.map((doc) => Admin.fromFirestore(doc)).toList();

    // 2. Check saved user role
    final prefs = await SharedPreferences.getInstance();
    final userRole = prefs.getString('user_role');

    if (userRole == null) {
      return LoginPage(admins: admins);
    }

    switch (userRole) {
      case 'superadmin':
        return SuperAdminPage(
            admins: admins, onAddAdmin: (admin) => setState(() => admins.add(admin)));
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
  }

  void _addAdmin(Admin admin) {
    setState(() {
      admins.add(admin);
    });
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
            body: Center(
              child: Text('Error: ${snapshot.error}'),
            ),
          );
        }
        // When future completes, return the determined page
        return snapshot.data ?? LoginPage(admins: admins);
      },
    );
  }
}
