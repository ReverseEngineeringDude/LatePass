// ignore_for_file: use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class EditAttendancePage extends StatefulWidget {
  final QueryDocumentSnapshot attendance;

  const EditAttendancePage({super.key, required this.attendance});

  @override
  _EditAttendancePageState createState() => _EditAttendancePageState();
}

class _EditAttendancePageState extends State<EditAttendancePage> {
  late DateTime _selectedDateTime;
  final TextEditingController _dateController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final timestamp = widget.attendance['timestamp'] as Timestamp;
    _selectedDateTime = timestamp.toDate();
    _dateController.text =
        "${_selectedDateTime.toLocal()}".split(' ')[0];
  }

  Future<void> _selectDate(BuildContext context) async {
    final theme = Theme.of(context);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: theme.colorScheme.primary, // Header background color
              onPrimary: theme.colorScheme.onPrimary, // Header text color
              onSurface: theme.colorScheme.onSurface, // Body text color
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.primary, // Button text color
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      _selectTime(context, picked);
    }
  }

  Future<void> _selectTime(BuildContext context, DateTime date) async {
    final theme = Theme.of(context);
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: theme.colorScheme.primary, // Header background color
              onPrimary: theme.colorScheme.onPrimary, // Header text color
              onSurface: theme.colorScheme.onSurface, // Body text color
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.primary, // Button text color
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDateTime =
            DateTime(date.year, date.month, date.day, picked.hour, picked.minute);
        _dateController.text =
            "${_selectedDateTime.toLocal()}".split(' ')[0];
      });
    }
  }

  void _updateAttendance() {
    FirebaseFirestore.instance
        .collection('attendance')
        .doc(widget.attendance.id)
        .update({'timestamp': Timestamp.fromDate(_selectedDateTime)}).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attendance updated successfully')),
      );
      Navigator.pop(context);
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update attendance: $error')),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Edit Attendance'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: <Widget>[
            TextFormField(
              decoration: InputDecoration(
                labelText: 'Student ID',
                border: const OutlineInputBorder(),
                labelStyle: theme.textTheme.bodyMedium,
              ),
              initialValue: widget.attendance['studentId'],
              readOnly: true,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 16.0),
            TextFormField(
              controller: _dateController,
              decoration: InputDecoration(
                labelText: 'Date',
                border: const OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_today, color: theme.iconTheme.color),
                labelStyle: theme.textTheme.bodyMedium,
              ),
              readOnly: true,
              onTap: () => _selectDate(context),
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 16.0),
             TextFormField(
              decoration: InputDecoration(
                labelText: 'Time',
                border: const OutlineInputBorder(),
                suffixIcon: Icon(Icons.access_time, color: theme.iconTheme.color),
                labelStyle: theme.textTheme.bodyMedium,
              ),
              readOnly: true,
              onTap: () => _selectTime(context, _selectedDateTime),
              controller: TextEditingController(
                text: TimeOfDay.fromDateTime(_selectedDateTime).format(context),
              ),
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 32.0),
            ElevatedButton(
              onPressed: _updateAttendance,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
              ),
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}
