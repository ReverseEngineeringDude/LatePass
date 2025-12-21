import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latepass/admin/student_model.dart';

class TodaysAttendancePage extends StatefulWidget {
  final List<Student> presentStudents;

  TodaysAttendancePage({required this.presentStudents});

  @override
  _TodaysAttendancePageState createState() => _TodaysAttendancePageState();
}

class _TodaysAttendancePageState extends State<TodaysAttendancePage> {
  void _removeStudent(Student student) {
    setState(() {
      widget.presentStudents.remove(student);
    });
  }

  void _replaceStudent(Student oldStudent) async {
    final String response = await rootBundle.loadString('assets/students.json');
    final data = await json.decode(response) as List;
    final allStudents = data.map((json) => Student.fromJson(json)).toList();
    List<Student> filteredStudents = allStudents;
    final TextEditingController searchController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Replace Student'),
          content: Container(
            width: double.maxFinite,
            child: StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: 'Search by name or ID',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) {
                        setState(() {
                          filteredStudents = allStudents
                              .where((student) =>
                                  student.name
                                      .toLowerCase()
                                      .contains(value.toLowerCase()) ||
                                  student.id
                                      .toLowerCase()
                                      .contains(value.toLowerCase()))
                              .toList();
                        });
                      },
                    ),
                    Expanded(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: filteredStudents.length,
                        itemBuilder: (context, index) {
                          final newStudent = filteredStudents[index];
                          final isPresent = widget.presentStudents
                              .any((s) => s.id == newStudent.id);
                          return ListTile(
                            title: Text(newStudent.name),
                            subtitle: Text(newStudent.id),
                            onTap: isPresent
                                ? null
                                : () {
                                    this.setState(() {
                                      final oldStudentIndex =
                                          widget.presentStudents.indexOf(oldStudent);
                                      widget.presentStudents[oldStudentIndex] =
                                          newStudent;
                                    });
                                    Navigator.of(context).pop();
                                  },
                            tileColor: isPresent
                                ? Colors.grey.withOpacity(0.5)
                                : null,
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showActionsDialog(Student student) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Actions for ${student.name}'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _replaceStudent(student);
              },
              child: Text('Replace'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _removeStudent(student);
              },
              child: Text('Remove'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Today's Attendance"),
      ),
      body: ListView.builder(
        itemCount: widget.presentStudents.length,
        itemBuilder: (context, index) {
          final student = widget.presentStudents[index];
          return GestureDetector(
            onLongPress: () => _showActionsDialog(student),
            child: ListTile(
              title: Text(student.name),
              subtitle: Text(student.id),
            ),
          );
        },
      ),
    );
  }
}
