import 'package:flutter/material.dart';

class ShowReportsPage extends StatefulWidget {

  final bool isFaculty;

  final String department;

  final bool isSuperAdmin;



  ShowReportsPage({

    required this.isFaculty,

    required this.department,

    this.isSuperAdmin = false,

  });



  @override

  _ShowReportsPageState createState() => _ShowReportsPageState();

}



class _ShowReportsPageState extends State<ShowReportsPage> {

  // This would be populated from a service or database

  final List<Map<String, dynamic>> _allReports = [

    {

      'student': {'id': '18771', 'name': 'Arjun Menon', 'department': 'Computer Science', 'year': 2},

      'reason': 'Late coming'

    },

    {

      'student': {'id': '18772', 'name': 'Sneha Nair', 'department': 'Electronics', 'year': 3},

      'reason': 'Misbehavior'

    },

    {

      'student': {'id': '18775', 'name': 'Mohammed Ashraf', 'department': 'Computer Science', 'year': 3},

      'reason': 'Dress code violation'

    },

  ];



  List<Map<String, dynamic>> _filteredReports = [];



  @override

  void initState() {

    super.initState();

    if (widget.isSuperAdmin) {

      _filteredReports = _allReports;

    } else if (widget.isFaculty) {

      _filteredReports = _allReports

          .where((report) => report['student']['department'] == widget.department)

          .toList();

    }

  }



  @override

  Widget build(BuildContext context) {

    if (!widget.isSuperAdmin && !widget.isFaculty) {

      return Scaffold(

        appBar: AppBar(

          title: Text('Show Reports'),

        ),

        body: Center(

          child: Text('No permission to view this'),

        ),

      );

    }



    return Scaffold(

      appBar: AppBar(

        title: Text('Show Reports'),

        actions: [

          if (widget.isSuperAdmin || !widget.isFaculty)

            IconButton(

              icon: Icon(Icons.edit),

              onPressed: () {

                // TODO: Implement edit functionality

              },

            ),

        ],

      ),

      body: _filteredReports.isEmpty

          ? Center(child: Text('No reports for ${widget.department} department.'))

          : ListView.builder(

              itemCount: _filteredReports.length,

              itemBuilder: (context, index) {

                final report = _filteredReports[index];

                final student = report['student'];

                final reason = report['reason'];

                return Card(

                  margin: EdgeInsets.all(8.0),

                  child: ListTile(

                    title: Text(student['name']),

                    subtitle: Column(

                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [

                        Text('ID: ${student['id']}'),

                        Text('Department: ${student['department']}'),

                        Text('Year: ${student['year']}'),

                        Text('Reason: $reason'),

                      ],

                    ),

                  ),

                );

              },

            ),

    );

  }

}
