import 'package:flutter/material.dart';
import 'package:latepass/admin/admin_page.dart';
import 'package:latepass/login/login_page.dart';
import 'package:latepass/student/student_page.dart';
import 'package:latepass/superadmin/admin_model.dart';
import 'package:latepass/superadmin/superadmin_page.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final List<Admin> admins = [];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Admin Dashboard',
      theme: ThemeData(primarySwatch: Colors.blue),
      initialRoute: '/login',
      routes: {
        '/login': (context) => LoginPage(admins: admins),
        '/admin': (context) => AdminPage(),
        '/student': (context) => StudentPage(),
        '/superadmin': (context) => SuperAdminPage(),
      },
    );
  }
}
