import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latepass/admin/student_model.dart';

class ReportStudentPage extends StatefulWidget {
  @override
  _ReportStudentPageState createState() => _ReportStudentPageState();
}

class _ReportStudentPageState extends State<ReportStudentPage> {

  List<Student> _students = [];

  List<Student> _filteredStudents = [];

  List<Map<String, dynamic>> _reports = [];

  final TextEditingController _searchController = TextEditingController();



  @override

  void initState() {

    super.initState();

    _loadStudents();

    _searchController.addListener(() {

      _filterStudents();

    });

  }



  @override

  void dispose() {

    _searchController.dispose();

    super.dispose();

  }



  Future<void> _loadStudents() async {

    final String response = await rootBundle.loadString('assets/students.json');

    final data = await json.decode(response) as List;

    setState(() {

      _students = data.map((json) => Student.fromJson(json)).toList();

      _filteredStudents = _students;

    });

  }



  void _filterStudents() {

    final query = _searchController.text.toLowerCase();

    setState(() {

      _filteredStudents = _students.where((student) {

        return student.name.toLowerCase().contains(query) ||

            student.id.toLowerCase().contains(query);

      }).toList();

    });

  }



  void _reportStudent(Student student) {

    final TextEditingController reasonController = TextEditingController();



    showDialog(

      context: context,

      builder: (context) {

        return AlertDialog(

          title: Text('Report ${student.name}'),

          content: TextField(

            controller: reasonController,

            decoration: InputDecoration(labelText: 'Reason'),

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

                setState(() {

                  _reports.add({

                    'student': student,

                    'reason': reasonController.text,

                  });

                });

                Navigator.of(context).pop();

                ScaffoldMessenger.of(context).showSnackBar(

                  SnackBar(content: Text('${student.name} reported')),

                );

              },

              child: Text('Report'),

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

        title: Text('Report Student'),

        bottom: PreferredSize(

          preferredSize: Size.fromHeight(kToolbarHeight),

          child: Padding(

            padding: const EdgeInsets.all(8.0),

            child: TextField(

              controller: _searchController,

              decoration: InputDecoration(

                hintText: 'Search by name or ID',

                prefixIcon: Icon(Icons.search),

                border: OutlineInputBorder(

                  borderRadius: BorderRadius.circular(8.0),

                ),

              ),

            ),

          ),

        ),

      ),

      body: ListView.builder(

        itemCount: _filteredStudents.length,

        itemBuilder: (context, index) {

          final student = _filteredStudents[index];

          return ListTile(

            title: Text(student.name),

            subtitle: Text(student.department),

            trailing: IconButton(

              icon: Icon(Icons.report),

              onPressed: () => _reportStudent(student),

            ),

          );

        },

      ),

    );

  }

}
