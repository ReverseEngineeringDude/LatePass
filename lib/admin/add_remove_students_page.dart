import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latepass/admin/student_model.dart';

class AddRemoveStudentsPage extends StatefulWidget {
  @override
  _AddRemoveStudentsPageState createState() => _AddRemoveStudentsPageState();
}

class _AddRemoveStudentsPageState extends State<AddRemoveStudentsPage> {
  List<Student> _students = [];
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    final String response = await rootBundle.loadString('assets/students.json');
    final data = await json.decode(response) as List;
    setState(() {
      _students = data.map((json) => Student.fromJson(json)).toList();
    });
  }

  void _addStudent() {
    final TextEditingController idController = TextEditingController();
    final TextEditingController nameController = TextEditingController();
    String? selectedDepartment;
    int? selectedYear;

    final List<String> departments = _students
        .map((s) => s.department)
        .toSet()
        .toList();
    final List<int> years = [1, 2, 3];

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add Student'),
          content: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: idController,
                  decoration: InputDecoration(labelText: 'ID'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter an ID';
                    }
                    if (_students.any((student) => student.id == value)) {
                      return 'ID already exists';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: nameController,
                  decoration: InputDecoration(labelText: 'Name'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a name';
                    }
                    return null;
                  },
                ),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(labelText: 'Department'),
                  items: departments
                      .map(
                        (dept) =>
                            DropdownMenuItem(value: dept, child: Text(dept)),
                      )
                      .toList(),
                  onChanged: (value) {
                    selectedDepartment = value;
                  },
                  validator: (value) {
                    if (value == null) {
                      return 'Please select a department';
                    }
                    return null;
                  },
                ),
                DropdownButtonFormField<int>(
                  decoration: InputDecoration(labelText: 'Year'),
                  items: years
                      .map(
                        (year) => DropdownMenuItem(
                          value: year,
                          child: Text(year.toString()),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    selectedYear = value;
                  },
                  validator: (value) {
                    if (value == null) {
                      return 'Please select a year';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  setState(() {
                    _students.add(
                      Student(
                        id: idController.text,
                        name: nameController.text,
                        department: selectedDepartment!,
                        year: selectedYear!,
                      ),
                    );
                  });
                  Navigator.of(context).pop();
                }
              },
              child: Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _removeStudent(Student student) {
    setState(() {
      _students.remove(student);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add/Remove Students'),
        actions: [IconButton(icon: Icon(Icons.add), onPressed: _addStudent)],
      ),
      body: ListView.builder(
        itemCount: _students.length,
        itemBuilder: (context, index) {
          final student = _students[index];
          return ListTile(
            title: Text(student.name),
            subtitle: Text(student.department),
            trailing: IconButton(
              icon: Icon(Icons.delete),
              onPressed: () => _removeStudent(student),
            ),
          );
        },
      ),
    );
  }
}
