import 'package:cloud_firestore/cloud_firestore.dart';

class Student {
  final String id;
  final String name;
  final String department;
  final int year;

  Student({required this.id, required this.name, required this.department, required this.year});

  factory Student.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Student(
      id: doc.id,
      name: data['name'] ?? '',
      department: data['department'] ?? '',
      year: data['year'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'department': department,
      'year': year,
    };
  }
}
