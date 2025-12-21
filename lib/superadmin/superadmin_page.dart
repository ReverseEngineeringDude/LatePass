import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:latepass/admin/add_remove_students_page.dart';
import 'package:latepass/admin/export_data_page.dart';
import 'package:latepass/admin/id_scan_page.dart';
import 'package:latepass/admin/manual_enter_page.dart';
import 'package:latepass/admin/report_student_page.dart';
import 'package:latepass/admin/show_reports_page.dart';
import 'package:latepass/admin/student_model.dart';
import 'package:latepass/admin/todays_attendance_page.dart';
import 'package:latepass/superadmin/add_admins_page.dart';
import 'package:latepass/superadmin/admin_model.dart';

class SuperAdminPage extends StatefulWidget {
  @override
  _SuperAdminPageState createState() => _SuperAdminPageState();
}

class _SuperAdminPageState extends State<SuperAdminPage> {
  final List<String> options = [
    "Id Scan",
    "Manual Enter",
    "Export Data",
    "Report Student",
    "Show Reports (Department-wise)",
    "Add / Remove Students",
    "Today's Attendance",
    "Add Admins",
  ];

  final List<Student> presentStudents = [];
  final List<Admin> admins = [];

  void _addAdmin(Admin admin) {
    setState(() {
      admins.add(admin);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Admin ${admin.name} created')),
    );
  }

  Future<void> _handleScan(String value) async {
    final String response =
        await DefaultAssetBundle.of(context).loadString('assets/students.json');
    final data = json.decode(response) as List;
    final students = data.map((json) => Student.fromJson(json)).toList();

    try {
      final student = students.firstWhere(
        (student) => student.id == value,
      );

      if (!presentStudents.any((s) => s.id == student.id)) {
        setState(() {
          presentStudents.add(student);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${student.name} marked as present')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${student.name} is already marked as present')),
        );
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) =>
              TodaysAttendancePage(presentStudents: presentStudents),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Student not found')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      Container(), // Placeholder for Id Scan
      ManualEnterPage(presentStudents: presentStudents),
      ExportDataPage(),
      ReportStudentPage(),
      ShowReportsPage(isFaculty: false, department: "", isSuperAdmin: true),
      AddRemoveStudentsPage(),
      TodaysAttendancePage(presentStudents: presentStudents),
      AddAdminsPage(onAddAdmin: _addAdmin),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text("SuperAdmin Dashboard"),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: Text('Logout'),
                    content: Text('Are you sure you want to log out?'),
                    actions: [
                      TextButton(
                        child: Text('No'),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                      TextButton(
                        child: Text('Yes'),
                        onPressed: () {
                          Navigator.of(context).pop();
                          Navigator.pushReplacementNamed(context, '/login');
                        },
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: options.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(options[index]),
            onTap: () {
              if (options[index] == "Id Scan") {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ScannerPage(
                      onScan: _handleScan,
                    ),
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => pages[index]),
                );
              }
            },
          );
        },
      ),
    );
  }
}
