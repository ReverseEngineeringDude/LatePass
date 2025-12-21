import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latepass/admin/student_model.dart';
import 'package:latepass/admin/todays_attendance_page.dart';

class ManualEnterPage extends StatefulWidget {
  final List<Student> presentStudents;

  ManualEnterPage({required this.presentStudents});

  @override
  _ManualEnterPageState createState() => _ManualEnterPageState();
}

class _ManualEnterPageState extends State<ManualEnterPage> {
  final TextEditingController _controller = TextEditingController();
  Student? _student;

  Future<void> _findStudent() async {
    final String response = await rootBundle.loadString('assets/students.json');
    final data = await json.decode(response) as List;
    final students = data.map((json) => Student.fromJson(json)).toList();
    final student = students.firstWhere(
      (student) => student.id == _controller.text,
      orElse: () => Student(id: '', name: 'Not Found', department: '', year: 0),
    );
    setState(() {
      _student = student;
    });
  }

  void _addStudentToAttendance() {
    if (_student != null && _student!.id != '') {
      if (!widget.presentStudents.any((s) => s.id == _student!.id)) {
        setState(() {
          widget.presentStudents.add(_student!);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_student!.name} marked as present')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_student!.name} is already marked as present')),
        );
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => TodaysAttendancePage(presentStudents: widget.presentStudents),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manual Enter'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: 'Enter Student ID',
              ),
            ),
            ElevatedButton(
              onPressed: _findStudent,
              child: Text('Find Student'),
            ),
            if (_student != null && _student!.id != '')
              Card(
                margin: EdgeInsets.all(16.0),
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Name: ${_student!.name}'),
                      Text('ID: ${_student!.id}'),
                      Text('Department: ${_student!.department}'),
                      Text('Year: ${_student!.year}'),
                      ElevatedButton(
                        onPressed: _addStudentToAttendance,
                        child: Text('Add to Attendance'),
                      ),
                    ],
                  ),
                ),
              ),
            if (_student != null && _student!.id == '')
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Student not found.'),
              ),
          ],
        ),
      ),
    );
  }
}